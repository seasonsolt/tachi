import { useEffect, useRef, useCallback } from 'react';
import { useStore } from '../stores/store';
import {
  WS_RECONNECT_BASE,
  WS_RECONNECT_MAX,
  getMilestone,
} from '@eacc/shared';
import type { WSMessage, WSClientMessage } from '@eacc/shared';

const MAX_RETRIES_BEFORE_WEB_MODE = 3;
const LS_SERVER_URL = 'ritual-server-url';

/** Read ?server= from URL params, persist to localStorage */
function resolveServerUrl(): string | null {
  const params = new URLSearchParams(location.search);
  const fromUrl = params.get('server');
  if (fromUrl) {
    localStorage.setItem(LS_SERVER_URL, fromUrl);
    return fromUrl;
  }
  return localStorage.getItem(LS_SERVER_URL);
}

export function getServerUrl(): string | null {
  return localStorage.getItem(LS_SERVER_URL);
}

export function setServerUrl(url: string | null): void {
  if (url) {
    localStorage.setItem(LS_SERVER_URL, url);
  } else {
    localStorage.removeItem(LS_SERVER_URL);
  }
}

export function useWebSocket() {
  const wsRef = useRef<WebSocket | null>(null);
  const retriesRef = useRef(0);
  const timerRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const prevMilestoneRef = useRef<string | null>(null);

  const mode = useStore((s) => s.mode);

  const getUrl = useCallback(() => {
    const customServer = resolveServerUrl();
    if (customServer) {
      // Custom server: always use ws:// (local dev server)
      const host = customServer.replace(/^https?:\/\//, '').replace(/\/$/, '');
      return `ws://${host}/ws`;
    }
    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
    return `${proto}//${location.host}/ws`;
  }, []);

  const send = useCallback((msg: WSClientMessage) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(msg));
    }
  }, []);

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    const ws = new WebSocket(getUrl());
    wsRef.current = ws;

    ws.onopen = () => {
      retriesRef.current = 0;
      useStore.getState().setWsConnected(true);
    };

    ws.onmessage = (event) => {
      try {
        const msg: WSMessage = JSON.parse(event.data);
        const { setTokenData, setMilestone, setSessions, setTheme, setMarketState } = useStore.getState();
        switch (msg.type) {
          case 'token_update': {
            setTokenData(msg.data);
            const m = getMilestone(msg.data.totalTokens);
            if (m && m.name !== prevMilestoneRef.current) {
              prevMilestoneRef.current = m.name;
              setMilestone(m);
              setTimeout(() => useStore.getState().setMilestone(null), 8000);
            }
            break;
          }
          case 'milestone':
            setMilestone(msg.milestone);
            prevMilestoneRef.current = msg.milestone.name;
            setTimeout(() => useStore.getState().setMilestone(null), 8000);
            break;
          case 'session_update':
            setSessions(msg.sessions);
            break;
          case 'theme_change':
            setTheme(msg.theme);
            break;
          case 'market_state':
            setMarketState(msg.market);
            break;
          case 'connected':
          case 'error':
            break;
        }
      } catch {
        // ignore malformed messages
      }
    };

    ws.onclose = () => {
      const store = useStore.getState();
      store.setWsConnected(false);
      wsRef.current = null;
      retriesRef.current++;

      if (retriesRef.current >= MAX_RETRIES_BEFORE_WEB_MODE) {
        store.setMode('web');
        return;
      }

      const delay = Math.min(
        WS_RECONNECT_BASE * 2 ** retriesRef.current,
        WS_RECONNECT_MAX,
      );
      timerRef.current = setTimeout(connect, delay);
    };

    ws.onerror = () => {
      ws.close();
    };
  }, [getUrl]);

  useEffect(() => {
    if (mode === 'web') return;
    connect();
    return () => {
      clearTimeout(timerRef.current);
      wsRef.current?.close();
    };
  }, [connect, mode]);

  return { send };
}
