#!/usr/bin/env node

import { DEFAULT_PORT } from '@eacc/shared';
import type { MarketServerMode } from '@eacc/shared';
import { startServer } from './server.js';

interface ParsedArgs {
  port: number;
  noOpen: boolean;
  marketMode?: MarketServerMode;
  marketHubUrl?: string | null;
}

function parseArgs(argv: string[]): ParsedArgs {
  let port = DEFAULT_PORT;
  let noOpen = false;
  let marketMode: MarketServerMode | undefined;
  let marketHubUrl: string | null = null;

  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--port' && i + 1 < argv.length) {
      port = parseInt(argv[++i], 10);
      if (isNaN(port)) port = DEFAULT_PORT;
    } else if (arg.startsWith('--port=')) {
      port = parseInt(arg.split('=')[1], 10);
      if (isNaN(port)) port = DEFAULT_PORT;
    } else if (arg === '--no-open') {
      noOpen = true;
    } else if (arg === '--market-mode' && i + 1 < argv.length) {
      const mode = argv[++i];
      if (mode === 'hub' || mode === 'seller' || mode === 'standalone') {
        marketMode = mode;
      }
    } else if (arg.startsWith('--market-mode=')) {
      const mode = arg.split('=')[1];
      if (mode === 'hub' || mode === 'seller' || mode === 'standalone') {
        marketMode = mode;
      }
    } else if (arg === '--market-hub' && i + 1 < argv.length) {
      marketHubUrl = argv[++i];
    } else if (arg.startsWith('--market-hub=')) {
      marketHubUrl = arg.split('=')[1] || null;
    }
  }

  return { port, noOpen, marketMode, marketHubUrl };
}

async function main() {
  const { port, noOpen, marketMode, marketHubUrl } = parseArgs(process.argv);

  console.log('\n  \x1b[33m\u{1F525} Igniting the altar...\x1b[0m\n');

  const { close } = startServer(port, { marketMode, marketHubUrl });

  // Match the loopback bind (127.0.0.1) so localhost→::1 resolution can't miss.
  const url = `http://127.0.0.1:${port}`;
  console.log(`  \x1b[2mServing at\x1b[0m \x1b[36m${url}\x1b[0m\n`);

  if (!noOpen) {
    try {
      const open = (await import('open')).default;
      await open(url);
    } catch {
      // open is best-effort
    }
  }

  const shutdown = () => {
    console.log('\n  \x1b[2mExtinguishing the flame...\x1b[0m\n');
    close();
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main();
