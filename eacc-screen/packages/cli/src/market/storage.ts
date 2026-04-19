import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export const EACC_DIR = join(homedir(), '.eacc');
export const MARKET_VAULT_PATH = join(EACC_DIR, 'market-vault.json');
export const MARKET_HUB_PATH = join(EACC_DIR, 'market-hub.json');

export function ensureEaccDir(): void {
  mkdirSync(EACC_DIR, { recursive: true });
}

export function readJsonFile<T>(path: string): T | null {
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, 'utf-8')) as T;
  } catch {
    return null;
  }
}

export function writeJsonFile(path: string, value: unknown): void {
  ensureEaccDir();
  writeFileSync(path, JSON.stringify(value, null, 2) + '\n', 'utf-8');
}
