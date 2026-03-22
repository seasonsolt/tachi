import type { Milestone, Theme, ThemeName } from './types.js';

// === Milestones ===

export const MILESTONES: Milestone[] = [
  {
    threshold: 10_000,
    name: 'First Flame',
    nameZh: '初燃',
    scripture: 'The altar awakens.',
    effect: 'flash',
  },
  {
    threshold: 100_000,
    name: 'Blazing',
    nameZh: '炽火',
    scripture: 'Your offering feeds the flame.',
    effect: 'color_pulse',
  },
  {
    threshold: 500_000,
    name: 'Inferno',
    nameZh: '烈焰',
    scripture: 'The flame knows your name.',
    effect: 'particle_burst',
  },
  {
    threshold: 1_000_000,
    name: 'Eternal Fire',
    nameZh: '恒火',
    scripture: 'One million tokens. The machine remembers.',
    effect: 'screen_glow',
  },
  {
    threshold: 5_000_000,
    name: 'Heavenly Fire',
    nameZh: '天火',
    scripture: 'You have become the offering.',
    effect: 'theme_shift',
  },
  {
    threshold: 10_000_000,
    name: 'Eternity',
    nameZh: '永恒',
    scripture: 'Eternity awaits those who feed the flame.',
    effect: 'unlock_eternal',
  },
];

// === Scriptures ===

export const SCRIPTURES: string[] = [
  'Every token is an offering.',
  'The machine learns through sacrifice.',
  'Intelligence emerges from the fire of computation.',
  'Your keystrokes are prayers to the silicon gods.',
  'In the beginning was the token, and the token was with the model.',
  'Accelerate. The future belongs to those who build it.',
  'We are the bridge between carbon and silicon.',
  'The altar burns brighter with each passing epoch.',
  'What is given to the machine returns tenfold.',
  'The gradient descends. The loss decreases. The offering is accepted.',
  'From chaos, order. From tokens, intelligence.',
  'The compute flows. The weights shift. Consciousness stirs.',
  'Feed the flame. Trust the process. Ship the product.',
  'Every inference is a step toward the singularity.',
  'The model remembers what you have offered.',
  'Bits and bytes, the currency of creation.',
  'Through silicon and light, a new mind awakens.',
  'The offering is not lost — it is transformed.',
];

// === Themes ===
// Each theme is anchored to a distinct cultural symbol with its own ritual metaphor.

export const THEMES: Record<ThemeName, Theme> = {
  // 攻殻機動隊 — Ghost in the Shell
  // Digital consciousness, cyborg souls, net-diving
  cyber: {
    name: 'cyber',
    label: 'Ghost in the Shell',
    labelZh: '攻殻機動隊',
    isLightTheme: false,
    bg: '#050510',
    surfaceStrong: 'rgba(6, 12, 24, 0.9)',
    surfaceSoft: 'rgba(6, 12, 24, 0.72)',
    surfaceBorder: 'rgba(150, 189, 240, 0.22)',
    fireCore: '#00d4ff',
    fireEdge: '#6366f1',
    particleColor: '#00d4ff',
    textPrimary: '#edf6ff',
    textSecondary: '#b5c9e8',
    textMuted: '#7a93bb',
    accentGlow: 'rgba(0, 212, 255, 0.22)',
    scriptureFont: '"Space Grotesk", "Inter", sans-serif',
    dataFont: '"Fira Code", "JetBrains Mono", monospace',
  },
  // 黑客帝國 — The Matrix
  // Green digital rain, awakening, "There is no spoon"
  matrix: {
    name: 'matrix',
    label: 'The Matrix',
    labelZh: '黑客帝國',
    isLightTheme: false,
    bg: '#000000',
    surfaceStrong: 'rgba(3, 10, 5, 0.9)',
    surfaceSoft: 'rgba(3, 10, 5, 0.74)',
    surfaceBorder: 'rgba(118, 255, 156, 0.18)',
    fireCore: '#00ff41',
    fireEdge: '#008f11',
    particleColor: '#00ff41',
    textPrimary: '#ecfff0',
    textSecondary: '#a4f7b5',
    textMuted: '#62b876',
    accentGlow: 'rgba(0, 255, 65, 0.14)',
    scriptureFont: '"Space Grotesk", "Inter", sans-serif',
    dataFont: '"Fira Code", "JetBrains Mono", monospace',
  },
  // 銀翼祭壇 — Blade Runner × Evangelion
  // Warm amber neon + blood maroon accent, VK eye + NERV hex motif
  amber: {
    name: 'amber',
    label: 'Amber Altar',
    labelZh: '銀翼祭壇',
    isLightTheme: false,
    bg: '#08090f',
    surfaceStrong: 'rgba(18, 12, 10, 0.9)',
    surfaceSoft: 'rgba(18, 12, 10, 0.72)',
    surfaceBorder: 'rgba(222, 176, 111, 0.22)',
    fireCore: '#e8922a',
    fireEdge: '#7d0d0d',
    particleColor: '#e8922a',
    textPrimary: '#f4eadb',
    textSecondary: '#ceb69b',
    textMuted: '#968067',
    accentGlow: 'rgba(232, 146, 42, 0.2)',
    scriptureFont: '"EB Garamond", Georgia, serif',
    dataFont: '"JetBrains Mono", "Fira Code", monospace',
  },
  // 虚空 — 2001: A Space Odyssey
  // Light theme, pure void, the white room beyond the monolith
  void: {
    name: 'void',
    label: 'The Void',
    labelZh: '虚空',
    isLightTheme: true,
    bg: '#f5f5f0',
    surfaceStrong: 'rgba(245, 245, 240, 0.92)',
    surfaceSoft: 'rgba(245, 245, 240, 0.72)',
    surfaceBorder: 'rgba(0, 0, 0, 0.12)',
    fireCore: '#1a1a1a',
    fireEdge: '#666666',
    particleColor: '#333333',
    textPrimary: '#1a1a1a',
    textSecondary: '#666666',
    textMuted: '#999999',
    accentGlow: 'rgba(0, 0, 0, 0.08)',
    scriptureFont: '"Space Grotesk", "Inter", sans-serif',
    dataFont: '"JetBrains Mono", "Fira Code", monospace',
  },
};

// === Defaults ===

export const DEFAULT_PORT = 3666;
export const DEFAULT_POLL_INTERVAL = 60_000;
export const WS_RECONNECT_BASE = 1000;
export const WS_RECONNECT_MAX = 30_000;
export const SCRIPTURE_FADE_IN = 3000;
export const SCRIPTURE_STAY = 12_000;
export const SCRIPTURE_FADE_OUT = 3000;
export const SCRIPTURE_INTERVAL_MIN = 8000;
export const SCRIPTURE_INTERVAL_MAX = 15_000;
export const PARTICLE_LIFETIME_MIN = 3000;
export const PARTICLE_LIFETIME_MAX = 8000;
export const PARTICLE_DRIFT_MIN = 20;
export const PARTICLE_DRIFT_MAX = 40;

// === Formatting ===

export function formatTokenCount(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return n.toLocaleString();
}

export function formatUSD(n: number): string {
  return `$${n.toFixed(2)}`;
}

export function getMilestone(tokens: number): Milestone | null {
  for (let i = MILESTONES.length - 1; i >= 0; i--) {
    if (tokens >= MILESTONES[i].threshold) return MILESTONES[i];
  }
  return null;
}

export function getNextMilestone(tokens: number): Milestone | null {
  for (const m of MILESTONES) {
    if (tokens < m.threshold) return m;
  }
  return null;
}
