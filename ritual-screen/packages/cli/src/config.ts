import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import type { RitualConfig } from '@ritual-screen/shared';
import { DEFAULT_PORT, DEFAULT_POLL_INTERVAL } from '@ritual-screen/shared';

const CONFIG_DIR = join(homedir(), '.ritual-screen');
const CONFIG_PATH = join(CONFIG_DIR, 'config.json');

const DEFAULT_CONFIG: RitualConfig = {
  pollIntervalMs: DEFAULT_POLL_INTERVAL,
  port: DEFAULT_PORT,
};

export function loadConfig(): RitualConfig {
  if (!existsSync(CONFIG_PATH)) return { ...DEFAULT_CONFIG };
  try {
    const raw = readFileSync(CONFIG_PATH, 'utf-8');
    const parsed = JSON.parse(raw) as Partial<RitualConfig>;
    return { ...DEFAULT_CONFIG, ...parsed };
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}

export function saveConfig(config: RitualConfig): void {
  mkdirSync(CONFIG_DIR, { recursive: true });
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2) + '\n', 'utf-8');
}

export function hasAnthropicKey(config: RitualConfig): boolean {
  return !!config.anthropicAdminKey;
}

export function hasOpenAIKey(config: RitualConfig): boolean {
  return !!config.openaiKey;
}
