import { create } from 'zustand';
import type { TokenData, ThemeName, Milestone, SessionInfo } from '@ritual-screen/shared';

export type AppMode = 'cli' | 'web';
export type AudioSourceKind = 'default' | 'youtube' | 'local';

export interface AudioSource {
  kind: AudioSourceKind;
  url: string;
  label: string;
  youtubeVideoId?: string;
}

interface RitualStore {
  tokenData: TokenData | null;
  theme: ThemeName;
  mode: AppMode;
  wsConnected: boolean;
  setupOpen: boolean;
  milestone: Milestone | null;
  sessions: SessionInfo[];
  audioSource: AudioSource;
  audioPlaying: boolean;
  audioVolume: number;
  audioReady: boolean;
  audioError: string | null;
  focusDurationMinutes: number;
  focusRemainingSeconds: number;
  focusRunning: boolean;
  focusCompletedAt: number | null;
  setTokenData: (data: TokenData) => void;
  setTheme: (theme: ThemeName) => void;
  setMode: (mode: AppMode) => void;
  toggleSetup: () => void;
  setSetupOpen: (open: boolean) => void;
  setMilestone: (m: Milestone | null) => void;
  setWsConnected: (connected: boolean) => void;
  setSessions: (sessions: SessionInfo[]) => void;
  setAudioSource: (source: AudioSource) => void;
  setAudioPlaying: (playing: boolean) => void;
  setAudioVolume: (volume: number) => void;
  setAudioReady: (ready: boolean) => void;
  setAudioError: (error: string | null) => void;
  setFocusDurationMinutes: (minutes: number) => void;
  setFocusRemainingSeconds: (seconds: number) => void;
  setFocusRunning: (running: boolean) => void;
  setFocusCompletedAt: (completedAt: number | null) => void;
}

const DEFAULT_AUDIO_SOURCE: AudioSource = {
  kind: 'default',
  url: '/audio/ambient.mp3',
  label: 'ambient',
};

const LS_THEME = 'ritual-theme';

function loadTheme(): ThemeName {
  const saved = localStorage.getItem(LS_THEME);
  if (saved === 'cyber' || saved === 'bladerunner' || saved === 'matrix' || saved === 'blood' || saved === 'singularity') {
    return saved;
  }
  return 'cyber';
}

export const useStore = create<RitualStore>((set) => ({
  tokenData: null,
  theme: loadTheme(),
  mode: 'cli',
  wsConnected: false,
  setupOpen: false,
  milestone: null,
  sessions: [],
  audioSource: DEFAULT_AUDIO_SOURCE,
  audioPlaying: false,
  audioVolume: 0.4,
  audioReady: false,
  audioError: null,
  focusDurationMinutes: 25,
  focusRemainingSeconds: 25 * 60,
  focusRunning: false,
  focusCompletedAt: null,
  setTokenData: (data) => set({ tokenData: data }),
  setTheme: (theme) => {
    localStorage.setItem(LS_THEME, theme);
    set({ theme });
  },
  setMode: (mode) => set({ mode }),
  toggleSetup: () => set((s) => ({ setupOpen: !s.setupOpen })),
  setSetupOpen: (open) => set({ setupOpen: open }),
  setMilestone: (milestone) => set({ milestone }),
  setWsConnected: (connected) => set({ wsConnected: connected }),
  setSessions: (sessions) => set({ sessions }),
  setAudioSource: (audioSource) => set({ audioSource }),
  setAudioPlaying: (audioPlaying) => set({ audioPlaying }),
  setAudioVolume: (audioVolume) => set({ audioVolume }),
  setAudioReady: (audioReady) => set({ audioReady }),
  setAudioError: (audioError) => set({ audioError }),
  setFocusDurationMinutes: (focusDurationMinutes) => set({ focusDurationMinutes }),
  setFocusRemainingSeconds: (focusRemainingSeconds) => set({ focusRemainingSeconds }),
  setFocusRunning: (focusRunning) => set({ focusRunning }),
  setFocusCompletedAt: (focusCompletedAt) => set({ focusCompletedAt }),
}));
