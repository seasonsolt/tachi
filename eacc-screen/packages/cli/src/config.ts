import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import type { EACCConfig } from '@eacc/shared';
import { DEFAULT_PORT, DEFAULT_POLL_INTERVAL } from '@eacc/shared';

const CONFIG_DIR = join(homedir(), '.eacc');
const CONFIG_PATH = join(CONFIG_DIR, 'config.json');
const LEGACY_CONFIG_DIR = join(homedir(), '.ritual-screen');
const LEGACY_CONFIG_PATH = join(LEGACY_CONFIG_DIR, 'config.json');

const DEFAULT_CONFIG: EACCConfig = {
  pollIntervalMs: DEFAULT_POLL_INTERVAL,
  port: DEFAULT_PORT,
};

export function loadConfig(): EACCConfig {
  // Try new path first, fall back to legacy ~/.ritual-screen/
  let path = CONFIG_PATH;
  if (!existsSync(path) && existsSync(LEGACY_CONFIG_PATH)) {
    path = LEGACY_CONFIG_PATH;
  }
  if (!existsSync(path)) return { ...DEFAULT_CONFIG };
  try {
    const raw = readFileSync(path, 'utf-8');
    const parsed = JSON.parse(raw) as Partial<EACCConfig>;
    return { ...DEFAULT_CONFIG, ...parsed };
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}

export function saveConfig(config: EACCConfig): void {
  mkdirSync(CONFIG_DIR, { recursive: true });
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2) + '\n', 'utf-8');
}

export function hasAnthropicKey(config: EACCConfig): boolean {
  return !!config.anthropicAdminKey;
}

export function hasOpenAIKey(config: EACCConfig): boolean {
  return !!config.openaiKey;
}
