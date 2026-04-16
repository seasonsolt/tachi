import { Hono } from 'hono';
import { serve } from '@hono/node-server';
import { WebSocketServer, WebSocket } from 'ws';
import { existsSync, readFileSync, writeFileSync, mkdirSync, watchFile, unwatchFile } from 'node:fs';
import { join, dirname, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import type { TokenData, SourceData, WSMessage, WSClientMessage, EACCConfig, SessionInfo, ThemeName } from '@eacc/shared';
import { getMilestone } from '@eacc/shared';
import { loadConfig, saveConfig } from './config.js';
import { startClaudeCodeCollector } from './collectors/claude-code.js';
import { startAnthropicCollector } from './collectors/anthropic-api.js';
import { startOpenAICollector } from './collectors/openai-api.js';
import { startSessionCollector } from './collectors/claude-sessions.js';
import {
  buildOpsReport,
  createContentRouteMap,
  hashEmail,
  isLabPath,
  isRitualPath,
  loadRevenueLedger,
  loadRouteManifest,
  readAnalyticsEvents,
  resolveContentRoute,
  writeAnalyticsEvent,
} from './content-site.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

function emptySource(): SourceData {
  return {
    connected: false,
    totalTokens: 0,
    todayTokens: 0,
    monthTokens: 0,
    costUSD: 0,
    todayCostUSD: 0,
    monthCostUSD: 0,
    inputTokens: 0,
    outputTokens: 0,
    lastUpdated: 0,
  };
}

function buildTokenData(sources: {
  claudeCode: SourceData;
  anthropicApi: SourceData;
  openaiApi: SourceData;
}): TokenData {
  const all = [sources.claudeCode, sources.anthropicApi, sources.openaiApi];
  return {
    totalTokens: all.reduce((s, d) => s + d.totalTokens, 0),
    totalCostUSD: all.reduce((s, d) => s + d.costUSD, 0),
    todayTokens: all.reduce((s, d) => s + d.todayTokens, 0),
    todayCostUSD: all.reduce((s, d) => s + d.todayCostUSD, 0),
    monthTokens: all.reduce((s, d) => s + d.monthTokens, 0),
    monthCostUSD: all.reduce((s, d) => s + d.monthCostUSD, 0),
    tokensPerSecond: 0,
    sources,
    lastUpdated: Date.now(),
  };
}

// Theme file for cross-process sync with macOS app
const THEME_DIR = join(homedir(), '.eacc');
const THEME_FILE = join(THEME_DIR, 'theme.json');
const LEGACY_THEME_FILE = join(homedir(), '.ritual-screen', 'theme.json');
const CONTENT_ANALYTICS_FILE = join(THEME_DIR, 'site-analytics.ndjson');

function readThemeFile(): ThemeName | null {
  try {
    // Try new path first, fall back to legacy ~/.ritual-screen/
    const path = existsSync(THEME_FILE) ? THEME_FILE
      : existsSync(LEGACY_THEME_FILE) ? LEGACY_THEME_FILE
      : null;
    if (!path) return null;
    const json = JSON.parse(readFileSync(path, 'utf-8'));
    const raw = json.theme as string | undefined;
    if (!raw) return null;
    // Migrate removed themes
    if (raw === 'bladerunner' || raw === 'blood') return 'amber';
    if (raw === 'singularity') return 'void';
    return raw as ThemeName;
  } catch {
    return null;
  }
}

function writeThemeFile(theme: ThemeName): void {
  try {
    mkdirSync(THEME_DIR, { recursive: true });
    writeFileSync(THEME_FILE, JSON.stringify({ theme }) + '\n');
  } catch {
    // Ignore write errors
  }
}

export function startServer(port: number): { close: () => void } {
  let config = loadConfig();
  config.port = port;

  // Source state
  const sources = {
    claudeCode: emptySource(),
    anthropicApi: emptySource(),
    openaiApi: emptySource(),
  };

  let currentSessions: SessionInfo[] = [];
  let currentTheme: ThemeName = readThemeFile() || 'cyber';

  let previousTotalTokens = 0;
  let lastMilestoneThreshold = 0;

  // WebSocket server
  const wss = new WebSocketServer({ noServer: true });

  function broadcast(msg: WSMessage): void {
    const payload = JSON.stringify(msg);
    for (const client of wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(payload);
      }
    }
  }

  function broadcastUpdate(): void {
    const data = buildTokenData(sources);

    // Check for milestone
    const milestone = getMilestone(data.totalTokens);
    if (milestone && milestone.threshold > lastMilestoneThreshold && data.totalTokens > previousTotalTokens) {
      lastMilestoneThreshold = milestone.threshold;
      broadcast({ type: 'milestone', milestone });
    }

    previousTotalTokens = data.totalTokens;
    broadcast({ type: 'token_update', data });
  }

  // Start collectors
  const stopClaude = startClaudeCodeCollector((data) => {
    sources.claudeCode = data;
    broadcastUpdate();
  });

  const stopAnthropic = startAnthropicCollector(
    () => config.anthropicAdminKey,
    config.pollIntervalMs,
    (data) => {
      sources.anthropicApi = data;
      broadcastUpdate();
    },
    (message) => {
      broadcast({ type: 'error', source: 'anthropicApi', message });
    },
  );

  const stopOpenAI = startOpenAICollector(
    () => config.openaiKey,
    config.pollIntervalMs,
    (data) => {
      sources.openaiApi = data;
      broadcastUpdate();
    },
    (message) => {
      broadcast({ type: 'error', source: 'openaiApi', message });
    },
  );

  const stopSessions = startSessionCollector((sessions) => {
    currentSessions = sessions;
    broadcast({ type: 'session_update', sessions });
  });

  // Watch theme file for cross-process sync (macOS app writes this)
  watchFile(THEME_FILE, { interval: 1000 }, () => {
    const theme = readThemeFile();
    if (theme && theme !== currentTheme) {
      currentTheme = theme;
      broadcast({ type: 'theme_change', theme });
    }
  });

  // Hono app
  const app = new Hono();

  // CORS middleware — allow e-acc.ai and any origin to connect
  app.use('*', async (c, next) => {
    await next();
    c.header('Access-Control-Allow-Origin', c.req.header('Origin') || '*');
    c.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    c.header('Access-Control-Allow-Headers', 'Content-Type');
  });

  app.options('*', (c) => {
    return c.body(null, 204);
  });

  // API endpoints
  app.get('/api/status', (c) => {
    return c.json(buildTokenData(sources));
  });

  app.get('/api/config', (c) => {
    return c.json({
      hasAnthropicKey: !!config.anthropicAdminKey,
      hasOpenAIKey: !!config.openaiKey,
      port: config.port,
      pollIntervalMs: config.pollIntervalMs,
    });
  });

  const siteDistPath = join(__dirname, '..', '..', 'site', 'dist');
  const ritualDistPath = join(__dirname, '..', '..', 'client', 'dist');
  const bundledRitualPath = join(__dirname, '..', 'client');
  const siteStaticRoot = existsSync(siteDistPath) ? siteDistPath : join(__dirname, '..', 'site');
  const ritualStaticRoot = existsSync(ritualDistPath) ? ritualDistPath : bundledRitualPath;
  const routeManifest = loadRouteManifest(siteStaticRoot);
  const routeMap = createContentRouteMap(routeManifest);
  const revenueLedger = loadRevenueLedger(siteStaticRoot);

  const MIME_TYPES: Record<string, string> = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.txt': 'text/plain',
    '.xml': 'application/xml',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
  };

  function serveStaticFile(root: string, requestPath: string): Response | null {
    const relativePath = requestPath === '/' ? 'index.html' : requestPath.replace(/^\/+/, '');
    const filePath = join(root, relativePath);

    if (existsSync(filePath)) {
      const ext = extname(filePath);
      const contentType = MIME_TYPES[ext] || 'application/octet-stream';
      const content = readFileSync(filePath);
      return new Response(content, {
        status: 200,
        headers: { 'Content-Type': contentType },
      });
    }

    return null;
  }

  app.get('/api/ops/report', (c) => {
    const report = buildOpsReport(routeManifest, revenueLedger, readAnalyticsEvents(CONTENT_ANALYTICS_FILE));
    return c.json(report);
  });

  app.get('/out', (c) => {
    const route = c.req.query('route');
    if (!route) return c.text('Missing route', 400);

    const contentRoute = resolveContentRoute(routeMap, route);
    if (!contentRoute?.cta?.href) return c.text('Unknown outbound CTA', 404);

    writeAnalyticsEvent(CONTENT_ANALYTICS_FILE, {
      type: 'outbound_cta',
      timestamp: new Date().toISOString(),
      route: contentRoute.path,
      cluster: contentRoute.cluster,
      kind: contentRoute.kind,
      href: contentRoute.cta.href,
      ctaType: contentRoute.cta.type,
      userAgent: c.req.header('user-agent'),
    });

    return c.redirect(contentRoute.cta.href, 302);
  });

  app.post('/newsletter', async (c) => {
    const form = await c.req.formData();
    const route = typeof form.get('route') === 'string' ? String(form.get('route')) : '';
    const email = typeof form.get('email') === 'string' ? String(form.get('email')) : '';
    if (!route || !email) return c.text('Missing route or email', 400);

    const contentRoute = resolveContentRoute(routeMap, route);
    if (!contentRoute) return c.text('Unknown content route', 404);

    writeAnalyticsEvent(CONTENT_ANALYTICS_FILE, {
      type: 'newsletter_capture',
      timestamp: new Date().toISOString(),
      route: contentRoute.path,
      cluster: contentRoute.cluster,
      kind: contentRoute.kind,
      emailHash: hashEmail(email),
      userAgent: c.req.header('user-agent'),
    });

    return c.html(`<!DOCTYPE html>
<html lang="en" style="color-scheme: dark">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Subscription captured</title>
    <style>
      body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #060912; color: #eef5ff; font-family: Inter, system-ui, sans-serif; }
      article { width: min(560px, calc(100vw - 32px)); padding: 32px; border: 1px solid rgba(123, 172, 255, 0.22); background: rgba(8, 16, 30, 0.96); }
      a { color: #00d4ff; }
    </style>
  </head>
  <body>
    <article>
      <p style="text-transform: uppercase; letter-spacing: 0.18em; color: #00d4ff;">newsletter capture</p>
      <h1>You're on the weekly operating memo.</h1>
      <p>We logged this subscription against <strong>${contentRoute.title}</strong> so the content layer can attribute what actually earns trust.</p>
      <p><a href="${contentRoute.path}">Return to the page</a> or <a href="/api/ops/report">inspect the ops report</a>.</p>
    </article>
  </body>
</html>`);
  });

  app.get('/lab', (c) => c.redirect('/ritual', 302));
  app.get('/lab/*', (c) => c.redirect('/ritual', 302));

  app.get('/ritual', (c) => {
    const response = serveStaticFile(ritualStaticRoot, '/index.html');
    if (response) return response;
    return c.text('Ritual shell not found', 404);
  });

  app.get('/ritual/*', (c) => {
    const ritualPath = c.req.path.replace(/^\/ritual/, '') || '/index.html';
    const fileResponse = serveStaticFile(ritualStaticRoot, ritualPath);
    if (fileResponse) return fileResponse;

    const indexPath = join(ritualStaticRoot, 'index.html');
    if (existsSync(indexPath)) {
      const content = readFileSync(indexPath, 'utf-8');
      return c.html(content);
    }

    return c.text('Not found', 404);
  });

  app.get('/*', (c) => {
    const contentRoute = resolveContentRoute(routeMap, c.req.path);
    if (contentRoute) {
      const response = serveStaticFile(siteStaticRoot, contentRoute.artifact);
      if (response) {
        writeAnalyticsEvent(CONTENT_ANALYTICS_FILE, {
          type: 'pageview',
          timestamp: new Date().toISOString(),
          route: contentRoute.path,
          cluster: contentRoute.cluster,
          kind: contentRoute.kind,
          userAgent: c.req.header('user-agent'),
        });
        return response;
      }
    }

    if (isRitualPath(c.req.path)) {
      return c.redirect('/ritual', 302);
    }

    if (isLabPath(c.req.path)) {
      return c.redirect('/ritual', 302);
    }

    const fileResponse = serveStaticFile(siteStaticRoot, c.req.path);
    if (fileResponse) return fileResponse;

    return c.text('Not found', 404);
  });

  // Start HTTP server
  const server = serve({ fetch: app.fetch, port }, () => {
    // Server started
  });

  // Handle WebSocket upgrade
  (server as import('node:http').Server).on('upgrade', (request, socket, head) => {
    if (request.url === '/ws') {
      wss.handleUpgrade(request, socket, head, (ws) => {
        wss.emit('connection', ws, request);
      });
    } else {
      socket.destroy();
    }
  });

  // Handle WebSocket connections
  wss.on('connection', (ws) => {
    // Send current state immediately
    const connectedSources: string[] = [];
    if (sources.claudeCode.connected) connectedSources.push('claudeCode');
    if (sources.anthropicApi.connected) connectedSources.push('anthropicApi');
    if (sources.openaiApi.connected) connectedSources.push('openaiApi');

    ws.send(JSON.stringify({ type: 'connected', sources: connectedSources } satisfies WSMessage));
    ws.send(JSON.stringify({ type: 'token_update', data: buildTokenData(sources) } satisfies WSMessage));
    ws.send(JSON.stringify({ type: 'session_update', sessions: currentSessions } satisfies WSMessage));
    ws.send(JSON.stringify({ type: 'theme_change', theme: currentTheme } satisfies WSMessage));

    ws.on('message', (raw) => {
      try {
        const msg = JSON.parse(String(raw)) as WSClientMessage;
        if (msg.type === 'configure') {
          config = { ...config, ...msg.config };
          saveConfig(config);
          broadcastUpdate();
        } else if (msg.type === 'theme_change') {
          if (msg.theme !== currentTheme) {
            currentTheme = msg.theme;
            writeThemeFile(msg.theme);
            broadcast({ type: 'theme_change', theme: msg.theme });
          }
        }
        // ping is just a keepalive, no response needed
      } catch {
        // Ignore malformed messages
      }
    });
  });

  return {
    close() {
      stopClaude();
      stopAnthropic();
      stopOpenAI();
      stopSessions();
      unwatchFile(THEME_FILE);
      wss.close();
      (server as import('node:http').Server).close();
    },
  };
}
