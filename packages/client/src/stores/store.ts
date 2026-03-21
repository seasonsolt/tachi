import { create } from 'zustand';
import type { TokenData, ThemeName, Milestone, SessionInfo } from '@ritual-screen/shared';

export type AppMode = 'cli' | 'web';

interface RitualStore {
  tokenData: TokenData | null;
  theme: ThemeName;
  mode: AppMode;
  wsConnected: boolean;
  setupOpen: boolean;
  milestone: Milestone | null;
  sessions: SessionInfo[];
  setTokenData: (data: TokenData) => void;
  setTheme: (theme: ThemeName) => void;
  setMode: (mode: AppMode) => void;
  toggleSetup: () => void;
  setSetupOpen: (open: boolean) => void;
  setMilestone: (m: Milestone | null) => void;
  setWsConnected: (connected: boolean) => void;
  setSessions: (sessions: SessionInfo[]) => void;
}

export const useStore = create<RitualStore>((set) => ({
  tokenData: null,
  theme: 'cyber',
  mode: 'cli',
  wsConnected: false,
  setupOpen: false,
  milestone: null,
  sessions: [],
  setTokenData: (data) => set({ tokenData: data }),
  setTheme: (theme) => set({ theme }),
  setMode: (mode) => set({ mode }),
  toggleSetup: () => set((s) => ({ setupOpen: !s.setupOpen })),
  setSetupOpen: (open) => set({ setupOpen: open }),
  setMilestone: (milestone) => set({ milestone }),
  setWsConnected: (connected) => set({ wsConnected: connected }),
  setSessions: (sessions) => set({ sessions }),
}));
