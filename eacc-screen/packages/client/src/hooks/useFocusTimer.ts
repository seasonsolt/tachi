import { useCallback, useEffect, useRef } from 'react';
import { useStore } from '../stores/store';

const LS_FOCUS_DURATION = 'ritual-focus-duration';

function clampDuration(minutes: number): number {
  if (Number.isNaN(minutes)) return 25;
  return Math.max(5, Math.min(180, Math.round(minutes)));
}

function getPersistedDuration(): number {
  if (typeof window === 'undefined') return 25;
  const raw = window.localStorage.getItem(LS_FOCUS_DURATION);
  return clampDuration(raw ? Number(raw) : 25);
}

export function formatFocusTime(totalSeconds: number): string {
  const safe = Math.max(0, totalSeconds);
  const minutes = Math.floor(safe / 60);
  const seconds = safe % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

export function useFocusTimerController() {
  const focusDurationMinutes = useStore((s) => s.focusDurationMinutes);
  const focusRunning = useStore((s) => s.focusRunning);
  const setFocusDurationMinutes = useStore((s) => s.setFocusDurationMinutes);
  const setFocusRemainingSeconds = useStore((s) => s.setFocusRemainingSeconds);
  const setFocusRunning = useStore((s) => s.setFocusRunning);
  const setFocusCompletedAt = useStore((s) => s.setFocusCompletedAt);
  const bootedRef = useRef(false);

  useEffect(() => {
    if (bootedRef.current) return;
    bootedRef.current = true;
    const duration = getPersistedDuration();
    setFocusDurationMinutes(duration);
    setFocusRemainingSeconds(duration * 60);
  }, [setFocusDurationMinutes, setFocusRemainingSeconds]);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(LS_FOCUS_DURATION, String(focusDurationMinutes));
    }
  }, [focusDurationMinutes]);

  useEffect(() => {
    if (!focusRunning) return undefined;

    const timer = window.setInterval(() => {
      const current = useStore.getState().focusRemainingSeconds;
      if (current <= 1) {
        setFocusRemainingSeconds(0);
        setFocusRunning(false);
        setFocusCompletedAt(Date.now());
        return;
      }
      setFocusRemainingSeconds(current - 1);
    }, 1000);

    return () => window.clearInterval(timer);
  }, [focusRunning, setFocusCompletedAt, setFocusRemainingSeconds, setFocusRunning]);
}

export function useFocusTimer() {
  const durationMinutes = useStore((s) => s.focusDurationMinutes);
  const remainingSeconds = useStore((s) => s.focusRemainingSeconds);
  const running = useStore((s) => s.focusRunning);
  const completedAt = useStore((s) => s.focusCompletedAt);
  const setFocusDurationMinutes = useStore((s) => s.setFocusDurationMinutes);
  const setFocusRemainingSeconds = useStore((s) => s.setFocusRemainingSeconds);
  const setFocusRunning = useStore((s) => s.setFocusRunning);
  const setFocusCompletedAt = useStore((s) => s.setFocusCompletedAt);

  const setDuration = useCallback((minutes: number) => {
    const next = clampDuration(minutes);
    setFocusDurationMinutes(next);
    setFocusRemainingSeconds(next * 60);
    setFocusRunning(false);
    setFocusCompletedAt(null);
  }, [
    setFocusCompletedAt,
    setFocusDurationMinutes,
    setFocusRemainingSeconds,
    setFocusRunning,
  ]);

  const start = useCallback(() => {
    if (useStore.getState().focusRemainingSeconds <= 0) {
      setFocusRemainingSeconds(durationMinutes * 60);
    }
    setFocusCompletedAt(null);
    setFocusRunning(true);
  }, [durationMinutes, setFocusCompletedAt, setFocusRemainingSeconds, setFocusRunning]);

  const pause = useCallback(() => {
    setFocusRunning(false);
  }, [setFocusRunning]);

  const reset = useCallback(() => {
    setFocusRunning(false);
    setFocusCompletedAt(null);
    setFocusRemainingSeconds(durationMinutes * 60);
  }, [durationMinutes, setFocusCompletedAt, setFocusRemainingSeconds, setFocusRunning]);

  return {
    durationMinutes,
    remainingSeconds,
    remainingLabel: formatFocusTime(remainingSeconds),
    running,
    completedAt,
    setDuration,
    start,
    pause,
    reset,
  };
}
