import { useState, useEffect, useRef, useCallback } from 'react';
import { useStore } from '../stores/store';
import {
  THEMES,
  SCRIPTURES,
  SCRIPTURE_FADE_IN,
  SCRIPTURE_STAY,
  SCRIPTURE_FADE_OUT,
  SCRIPTURE_INTERVAL_MIN,
  SCRIPTURE_INTERVAL_MAX,
} from '@eacc/shared';

type Phase = 'fade-in' | 'stay' | 'fade-out' | 'pause';

export function Scripture() {
  const theme = useStore((s) => s.theme);
  const milestone = useStore((s) => s.milestone);
  const t = THEMES[theme];

  const [text, setText] = useState('');
  const [opacity, setOpacity] = useState(0);
  const indexRef = useRef(Math.floor(Math.random() * SCRIPTURES.length));
  const phaseRef = useRef<Phase>('pause');
  const timerRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  const cycle = useCallback(() => {
    const advance = (phase: Phase) => {
      phaseRef.current = phase;
      switch (phase) {
        case 'fade-in':
          indexRef.current = (indexRef.current + 1) % SCRIPTURES.length;
          setText(SCRIPTURES[indexRef.current]);
          setOpacity(0.6);
          timerRef.current = setTimeout(() => advance('stay'), SCRIPTURE_FADE_IN);
          break;
        case 'stay':
          timerRef.current = setTimeout(() => advance('fade-out'), SCRIPTURE_STAY);
          break;
        case 'fade-out':
          setOpacity(0);
          timerRef.current = setTimeout(() => advance('pause'), SCRIPTURE_FADE_OUT);
          break;
        case 'pause': {
          const pause =
            SCRIPTURE_INTERVAL_MIN +
            Math.random() * (SCRIPTURE_INTERVAL_MAX - SCRIPTURE_INTERVAL_MIN);
          timerRef.current = setTimeout(() => advance('fade-in'), pause);
          break;
        }
      }
    };
    advance('fade-in');
  }, []);

  useEffect(() => {
    const pause =
      SCRIPTURE_INTERVAL_MIN +
      Math.random() * (SCRIPTURE_INTERVAL_MAX - SCRIPTURE_INTERVAL_MIN);
    timerRef.current = setTimeout(cycle, pause);
    return () => clearTimeout(timerRef.current);
  }, [cycle]);

  useEffect(() => {
    if (milestone) {
      clearTimeout(timerRef.current);
      setText(milestone.scripture);
      setOpacity(0.8);
      timerRef.current = setTimeout(() => {
        setOpacity(0);
        setTimeout(cycle, 2000);
      }, 6000);
    }
  }, [milestone, cycle]);

  const isMatrix = theme === 'matrix';

  return (
    <div
      style={{
        ...styles.container,
        fontFamily: isMatrix ? t.dataFont : t.scriptureFont,
        fontStyle: isMatrix ? 'normal' : 'italic',
        fontSize: isMatrix ? 14 : 20,
        letterSpacing: isMatrix ? '0.1em' : undefined,
        textTransform: isMatrix ? 'uppercase' as const : undefined,
        color: isMatrix ? '#00ff41' : 'var(--text-primary)',
        background: isMatrix
          ? 'linear-gradient(90deg, transparent 0%, var(--surface-strong) 18%, var(--surface-strong) 82%, transparent 100%)'
          : 'linear-gradient(180deg, var(--surface-soft) 0%, var(--surface-strong) 100%)',
        padding: isMatrix ? '8px 24px' : '10px 28px',
        textShadow: isMatrix ? '0 0 12px rgba(0,255,65,0.28)' : '0 0 22px rgba(0,0,0,0.42)',
        backdropFilter: 'blur(2px)',
        borderColor: isMatrix ? 'var(--surface-border)' : 'transparent',
        opacity,
        filter: opacity === 0 ? 'blur(8px)' : 'blur(0px)',
      }}
    >
      {isMatrix ? `> ${text}_` : text}
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    top: 48,
    left: '50%',
    transform: 'translateX(-50%)',
    textAlign: 'center',
    fontSize: 20,
    fontStyle: 'italic',
    color: 'var(--text-secondary)',
    maxWidth: '60%',
    lineHeight: 1.6,
    transition: 'opacity 3s ease, filter 3s ease',
    pointerEvents: 'none',
    userSelect: 'none',
    zIndex: 10,
    border: '1px solid var(--surface-border)',
  },
};
