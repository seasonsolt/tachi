import type { Milestone, Theme } from './types.js';

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

export const THEMES: Record<string, Theme> = {
  ancient: {
    name: 'ancient',
    label: 'Ancient Altar',
    bg: '#0a0806',
    fireCore: '#d4a017',
    fireEdge: '#8b5e14',
    particleColor: '#d4a017',
    textPrimary: '#e8d5b0',
    textSecondary: '#a89070',
    textMuted: '#6b5a45',
    accentGlow: 'rgba(212, 160, 23, 0.3)',
    scriptureFont: '"EB Garamond", Georgia, serif',
    dataFont: '"JetBrains Mono", "Fira Code", monospace',
  },
  cyber: {
    name: 'cyber',
    label: 'Cyber Shrine',
    bg: '#050510',
    fireCore: '#00d4ff',
    fireEdge: '#6366f1',
    particleColor: '#00d4ff',
    textPrimary: '#c0d8ff',
    textSecondary: '#7088b0',
    textMuted: '#3a4a6b',
    accentGlow: 'rgba(0, 212, 255, 0.3)',
    scriptureFont: '"Space Grotesk", "Inter", sans-serif',
    dataFont: '"Fira Code", "JetBrains Mono", monospace',
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
