import { create } from 'zustand';
import type { TokenData, ThemeName, Milestone } from '@ritual-screen/shared';

interface RitualStore {
  tokenData: TokenData | null;
  theme: ThemeName;
  wsConnected: boolean;
  setupOpen: boolean;
  milestone: Milestone | null;
  setTokenData: (data: TokenData) => void;
  setTheme: (theme: ThemeName) => void;
  toggleSetup: () => void;
  setSetupOpen: (open: boolean) => void;
  setMilestone: (m: Milestone | null) => void;
  setWsConnected: (connected: boolean) => void;
}

export const useStore = create<RitualStore>((set) => ({
  tokenData: null,
  theme: 'ancient',
  wsConnected: false,
  setupOpen: false,
  milestone: null,
  setTokenData: (data) => set({ tokenData: data }),
  setTheme: (theme) => set({ theme }),
  toggleSetup: () => set((s) => ({ setupOpen: !s.setupOpen })),
  setSetupOpen: (open) => set({ setupOpen: open }),
  setMilestone: (milestone) => set({ milestone }),
  setWsConnected: (connected) => set({ wsConnected: connected }),
}));
