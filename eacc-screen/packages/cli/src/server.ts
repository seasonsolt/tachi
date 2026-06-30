import { Hono } from 'hono';
import { serve } from '@hono/node-server';
import { WebSocketServer, WebSocket } from 'ws';
import { existsSync, readFileSync, writeFileSync, mkdirSync, watchFile, unwatchFile } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { join, dirname, extname, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import type {
  TokenData,
  SourceData,
  WSMessage,
  WSClientMessage,
  EACCConfig,
  SessionInfo,
  ThemeName,
  MarketBuyerRequest,
  MarketSellerSummary,
  MarketServerMode,
  MarketState,
} from '@eacc/shared';
import { getMilestone } from '@eacc/shared';
import { loadConfig, saveConfig } from './config.js';
import { startClaudeCodeCollector } from './collectors/claude-code.js';
import { startAnthropicCollector } from './collectors/anthropic-api.js';
import { startOpenAICollector } from './collectors/openai-api.js';
import { startSessionCollector } from './collectors/claude-sessions.js';
import { SellerAgentBridge } from './market/agent.js';
import { MarketHub } from './market/hub.js';
import { MARKET_AGENT_PATH } from './market/protocol.js';
import { readSellerVault, createSellerVault, decryptVault, writeSellerVault } from './market/vault.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

interface StartServerOptions {
  marketMode?: MarketServerMode;
  marketHubUrl?: string | null;
}

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

const THEME_DIR = join(homedir(), '.eacc');
const THEME_FILE = join(THEME_DIR, 'theme.json');
const LEGACY_THEME_FILE = join(homedir(), '.ritual-screen', 'theme.json');

function readThemeFile(): ThemeName | null {
  try {
    const path = existsSync(THEME_FILE) ? THEME_FILE
      : existsSync(LEGACY_THEME_FILE) ? LEGACY_THEME_FILE
      : null;
    if (!path) return null;
    const json = JSON.parse(readFileSync(path, 'utf-8')) as { theme?: string };
    const raw = json.theme;
    if (!raw) return null;
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
    // Ignore write errors.
  }
}

function resolveServerMode(config: EACCConfig, options?: StartServerOptions): MarketServerMode {
  return options?.marketMode ?? config.market?.mode ?? 'standalone';
}

function buildSellerFallback(config: EACCConfig): MarketSellerSummary | null {
  const seller = config.market?.seller;
  if (!seller) return null;
  return {
    sellerId: seller.sellerId,
    listingId: seller.listingId,
    sellerAlias: seller.sellerAlias,
    endpoint: seller.endpoint,
    endpointHost: seller.endpointHost,
    model: seller.model,
    publicNote: seller.publicNote,
    hubUrl: config.market?.hubUrl ?? null,
    status: seller.enabled ? 'locked' : 'disabled',
    enabled: seller.enabled,
    hasLocalVault: !!readSellerVault(),
    hasUnlockedSecret: false,
    capabilityTokenPreview: seller.capabilityTokenPreview,
    lastError: null,
  };
}

function sanitizeConfigurePatch(config: EACCConfig, patch: Partial<EACCConfig>): EACCConfig {
  const next: EACCConfig = { ...config };
  if (typeof patch.anthropicAdminKey === 'string') next.anthropicAdminKey = patch.anthropicAdminKey;
  if (typeof patch.openaiKey === 'string') next.openaiKey = patch.openaiKey;
  if (typeof patch.pollIntervalMs === 'number') next.pollIntervalMs = patch.pollIntervalMs;
  if (typeof patch.port === 'number') next.port = patch.port;
  return next;
}

export function startServer(port: number, options?: StartServerOptions): { close: () => void } {
  let config = loadConfig();
  config.port = port;
  config.market = {
    mode: resolveServerMode(config, options),
    hubUrl: options?.marketHubUrl ?? config.market?.hubUrl,
    seller: config.market?.seller,
  };

  const sources = {
    claudeCode: emptySource(),
    anthropicApi: emptySource(),
    openaiApi: emptySource(),
  };

  let currentSessions: SessionInfo[] = [];
  let currentTheme: ThemeName = readThemeFile() || 'cyber';
  let previousTotalTokens = 0;
  let lastMilestoneThreshold = 0;

  const browserWss = new WebSocketServer({ noServer: true });
  const marketAgentWss = new WebSocketServer({ noServer: true });

  const marketHub = config.market.mode === 'hub'
    ? new MarketHub({
      onStateChange: () => broadcastMarketState(),
      operatorControlsAvailable: !!process.env.EACC_MARKET_OPERATOR_SECRET,
    })
    : null;

  const sellerAgentBridge = config.market.mode === 'seller'
    ? new SellerAgentBridge({
      getConfig: () => config,
      onStateChange: () => broadcastMarketState(),
    })
    : null;

  function buildMarketState(): MarketState {
    if (marketHub) return marketHub.getState();
    return {
      serverMode: config.market?.mode ?? 'standalone',
      hubUrl: config.market?.hubUrl ?? null,
      seller: sellerAgentBridge?.getSummary() ?? buildSellerFallback(config),
      listings: [],
      blacklist: [],
      operatorControlsAvailable: false,
    };
  }

  function broadcast(msg: WSMessage): void {
    const payload = JSON.stringify(msg);
    for (const client of browserWss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(payload);
      }
    }
  }

  function broadcastMarketState(): void {
    broadcast({ type: 'market_state', market: buildMarketState() });
  }

  let flushPending = false;
  function broadcastUpdate(): void {
    if (flushPending) return;
    flushPending = true;
    queueMicrotask(() => {
      flushPending = false;
      const data = buildTokenData(sources);
      const milestone = getMilestone(data.totalTokens);
      if (milestone && milestone.threshold > lastMilestoneThreshold && data.totalTokens > previousTotalTokens) {
        lastMilestoneThreshold = milestone.threshold;
        broadcast({ type: 'milestone', milestone });
      }
      previousTotalTokens = data.totalTokens;
      broadcast({ type: 'token_update', data });
    });
  }

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

  if (sellerAgentBridge) {
    sellerAgentBridge.refresh();
  }

  watchFile(THEME_FILE, { interval: 1000 }, () => {
    const theme = readThemeFile();
    if (theme && theme !== currentTheme) {
      currentTheme = theme;
      broadcast({ type: 'theme_change', theme });
    }
  });

  const app = new Hono();

  app.use('*', async (c, next) => {
    await next();
    c.header('Access-Control-Allow-Origin', c.req.header('Origin') || '*');
    c.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    c.header('Access-Control-Allow-Headers', 'Content-Type, x-market-operator-secret');
  });

  app.options('*', (c) => c.body(null, 204));

  app.get('/api/status', (c) => c.json(buildTokenData(sources)));

  app.get('/api/config', (c) => {
    return c.json({
      hasAnthropicKey: !!config.anthropicAdminKey,
      hasOpenAIKey: !!config.openaiKey,
      port: config.port,
      pollIntervalMs: config.pollIntervalMs,
      marketMode: config.market?.mode ?? 'standalone',
      marketHubUrl: config.market?.hubUrl ?? null,
      hasMarketSeller: !!config.market?.seller,
    });
  });

  app.get('/api/market/state', (c) => c.json(buildMarketState()));

  app.post('/api/market/local-vault', async (c) => {
    if (config.market?.mode !== 'seller') {
      return c.json({ error: 'Local vault is only available in seller mode' }, 400);
    }
    try {
      const body = await c.req.json() as {
        sellerAlias?: string;
        endpoint?: string;
        model?: string;
        publicNote?: string;
        apiKey?: string;
        passphrase?: string;
        hubUrl?: string;
      };
      if (!body.sellerAlias || !body.endpoint || !body.model || !body.apiKey || !body.passphrase) {
        return c.json({ error: 'Missing seller vault fields' }, 400);
      }
      const { vault, localConfig } = createSellerVault({
        sellerAlias: body.sellerAlias,
        endpoint: body.endpoint,
        model: body.model,
        publicNote: body.publicNote,
        apiKey: body.apiKey,
        passphrase: body.passphrase,
        existing: config.market?.seller ?? null,
      });
      writeSellerVault(vault);
      config = {
        ...config,
        market: {
          mode: 'seller',
          hubUrl: body.hubUrl?.trim() || config.market?.hubUrl,
          seller: localConfig,
        },
      };
      saveConfig(config);
      sellerAgentBridge?.setUnlockedSecrets(null);
      broadcastMarketState();
      return c.json({ ok: true, seller: buildMarketState().seller });
    } catch (error) {
      return c.json({ error: error instanceof Error ? error.message : 'Failed to save seller vault' }, 400);
    }
  });

  app.post('/api/market/unlock', async (c) => {
    if (!sellerAgentBridge || config.market?.mode !== 'seller') {
      return c.json({ error: 'Unlock is only available in seller mode' }, 400);
    }
    try {
      const body = await c.req.json() as { passphrase?: string };
      if (!body.passphrase) {
        return c.json({ error: 'Missing passphrase' }, 400);
      }
      const vault = readSellerVault();
      if (!vault) {
        return c.json({ error: 'No local market vault found' }, 404);
      }
      const secrets = decryptVault(vault, body.passphrase);
      sellerAgentBridge.setUnlockedSecrets(secrets);
      return c.json({ ok: true, seller: buildMarketState().seller });
    } catch (error) {
      return c.json({ error: error instanceof Error ? error.message : 'Failed to unlock seller vault' }, 400);
    }
  });

  app.post('/api/market/lock', (c) => {
    if (!sellerAgentBridge || config.market?.mode !== 'seller') {
      return c.json({ error: 'Lock is only available in seller mode' }, 400);
    }
    sellerAgentBridge.setUnlockedSecrets(null);
    return c.json({ ok: true, seller: buildMarketState().seller });
  });

  app.post('/api/market/request', async (c) => {
    if (!marketHub) {
      return c.json({ error: 'Buyer requests are only available on the market hub' }, 400);
    }
    const request = await c.req.json() as MarketBuyerRequest;
    if (!request.listingId || !request.prompt?.trim()) {
      return c.json({ error: 'Missing listing or prompt' }, 400);
    }
    const response = await marketHub.requestBuyerInvocation(request);
    broadcastMarketState();
    return c.json(response);
  });

  app.post('/api/market/admin/disable', async (c) => {
    if (!marketHub) {
      return c.json({ error: 'Operator controls are only available on the market hub' }, 400);
    }
    const operatorSecret = process.env.EACC_MARKET_OPERATOR_SECRET;
    const body = await c.req.json() as { listingId?: string; disabled?: boolean; operatorSecret?: string };
    const provided = c.req.header('x-market-operator-secret') ?? body.operatorSecret;
    if (!operatorSecret || provided !== operatorSecret) {
      return c.json({ error: 'Operator secret mismatch' }, 403);
    }
    if (!body.listingId || typeof body.disabled !== 'boolean') {
      return c.json({ error: 'Missing listingId or disabled flag' }, 400);
    }
    const updated = marketHub.setListingDisabled(body.listingId, body.disabled);
    if (!updated) {
      return c.json({ error: 'Listing not found' }, 404);
    }
    broadcastMarketState();
    return c.json({ ok: true, market: buildMarketState() });
  });

  const clientDistPath = join(__dirname, '..', '..', 'client', 'dist');
  const bundledDistPath = join(__dirname, '..', 'client');
  const staticRoot = existsSync(clientDistPath) ? clientDistPath : bundledDistPath;

  const MIME_TYPES: Record<string, string> = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
  };

  app.get('/*', async (c) => {
    const urlPath = c.req.path === '/' ? '/index.html' : c.req.path;
    const filePath = join(staticRoot, urlPath);

    if (filePath.startsWith(staticRoot + sep)) {
      try {
        const ext = extname(filePath);
        const contentType = MIME_TYPES[ext] || 'application/octet-stream';
        const content = await readFile(filePath);
        const headers: Record<string, string> = { 'Content-Type': contentType };
        if (urlPath.startsWith('/assets/')) {
          headers['Cache-Control'] = 'public, max-age=31536000, immutable';
        } else {
          headers['Cache-Control'] = 'no-cache';
        }
        return c.body(content, 200, headers);
      } catch {
        // fall through to index.html for SPA routes
      }
    }

    try {
      const indexContent = await readFile(join(staticRoot, 'index.html'), 'utf-8');
      return c.html(indexContent);
    } catch {
      return c.text('Not found', 404);
    }
  });

  const server = serve({ fetch: app.fetch, port }, () => {
    // Server started.
  });

  (server as import('node:http').Server).on('upgrade', (request, socket, head) => {
    const pathname = new URL(request.url || '/', 'http://localhost').pathname;
    if (pathname === '/ws') {
      browserWss.handleUpgrade(request, socket, head, (ws) => {
        browserWss.emit('connection', ws, request);
      });
    } else if (pathname === MARKET_AGENT_PATH && marketHub) {
      marketAgentWss.handleUpgrade(request, socket, head, (ws) => {
        marketAgentWss.emit('connection', ws, request);
      });
    } else {
      socket.destroy();
    }
  });

  marketAgentWss.on('connection', (ws) => {
    if (!marketHub) {
      ws.close();
      return;
    }
    marketHub.handleAgentConnection(ws);
  });

  browserWss.on('connection', (ws) => {
    const connectedSources: string[] = [];
    if (sources.claudeCode.connected) connectedSources.push('claudeCode');
    if (sources.anthropicApi.connected) connectedSources.push('anthropicApi');
    if (sources.openaiApi.connected) connectedSources.push('openaiApi');

    ws.send(JSON.stringify({ type: 'connected', sources: connectedSources } satisfies WSMessage));
    ws.send(JSON.stringify({ type: 'token_update', data: buildTokenData(sources) } satisfies WSMessage));
    ws.send(JSON.stringify({ type: 'session_update', sessions: currentSessions } satisfies WSMessage));
    ws.send(JSON.stringify({ type: 'theme_change', theme: currentTheme } satisfies WSMessage));
    ws.send(JSON.stringify({ type: 'market_state', market: buildMarketState() } satisfies WSMessage));

    ws.on('message', (raw) => {
      try {
        const msg = JSON.parse(String(raw)) as WSClientMessage;
        if (msg.type === 'configure') {
          config = sanitizeConfigurePatch(config, msg.config);
          saveConfig(config);
          broadcastUpdate();
        } else if (msg.type === 'theme_change') {
          if (msg.theme !== currentTheme) {
            currentTheme = msg.theme;
            writeThemeFile(msg.theme);
            broadcast({ type: 'theme_change', theme: msg.theme });
          }
        }
      } catch {
        // Ignore malformed browser websocket messages.
      }
    });
  });

  return {
    close() {
      stopClaude();
      stopAnthropic();
      stopOpenAI();
      stopSessions();
      sellerAgentBridge?.close();
      unwatchFile(THEME_FILE);
      browserWss.close();
      marketAgentWss.close();
      (server as import('node:http').Server).close();
    },
  };
}
