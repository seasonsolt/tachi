#!/usr/bin/env node

import { DEFAULT_PORT } from '@ritual-screen/shared';
import { startServer } from './server.js';

function parseArgs(argv: string[]): { port: number; noOpen: boolean } {
  let port = DEFAULT_PORT;
  let noOpen = false;

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
    }
  }

  return { port, noOpen };
}

async function main() {
  const { port, noOpen } = parseArgs(process.argv);

  console.log('\n  \x1b[33m\u{1F525} Igniting the altar...\x1b[0m\n');

  const { close } = startServer(port);

  const url = `http://localhost:${port}`;
  console.log(`  \x1b[2mServing at\x1b[0m \x1b[36m${url}\x1b[0m\n`);

  if (!noOpen) {
    try {
      const open = (await import('open')).default;
      await open(url);
    } catch {
      // open is best-effort
    }
  }

  // Graceful shutdown
  const shutdown = () => {
    console.log('\n  \x1b[2mExtinguishing the flame...\x1b[0m\n');
    close();
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main();
