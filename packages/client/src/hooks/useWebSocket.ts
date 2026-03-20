import { useEffect, useRef, useCallback } from 'react';
import { useStore } from '../stores/store';
import {
  WS_RECONNECT_BASE,
  WS_RECONNECT_MAX,
  getMilestone,
} from '@ritual-screen/shared';
import type { WSMessage, WSClientMessage } from '@ritual-screen/shared';

export function useWebSocket() {
  const wsRef = useRef<WebSocket | null>(null);
  const retriesRef = useRef(0);
  const timerRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const prevMilestoneRef = useRef<string | null>(null);

  const { setTokenData, setWsConnected, setMilestone } = useStore();

  const getUrl = useCallback(() => {
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
      setWsConnected(true);
    };

    ws.onmessage = (event) => {
      try {
        const msg: WSMessage = JSON.parse(event.data);
        switch (msg.type) {
          case 'token_update': {
            setTokenData(msg.data);
            const m = getMilestone(msg.data.totalTokens);
            if (m && m.name !== prevMilestoneRef.current) {
              prevMilestoneRef.current = m.name;
              setMilestone(m);
              setTimeout(() => setMilestone(null), 8000);
            }
            break;
          }
          case 'milestone':
            setMilestone(msg.milestone);
            prevMilestoneRef.current = msg.milestone.name;
            setTimeout(() => setMilestone(null), 8000);
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
      setWsConnected(false);
      wsRef.current = null;
      const delay = Math.min(
        WS_RECONNECT_BASE * 2 ** retriesRef.current,
        WS_RECONNECT_MAX,
      );
      retriesRef.current++;
      timerRef.current = setTimeout(connect, delay);
    };

    ws.onerror = () => {
      ws.close();
    };
  }, [getUrl, setTokenData, setWsConnected, setMilestone]);

  useEffect(() => {
    connect();
    return () => {
      clearTimeout(timerRef.current);
      wsRef.current?.close();
    };
  }, [connect]);

  return { send };
}
