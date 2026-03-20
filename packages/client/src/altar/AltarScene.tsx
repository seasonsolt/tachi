import { useRef, useMemo, useEffect, useState, useCallback } from 'react';
import { useStore } from '../stores/store';
import { useTokenData } from '../hooks/useTokenData';
import { THEMES, formatTokenCount, formatUSD } from '@ritual-screen/shared';

// CSS-based particle system — works everywhere, no WebGL needed
function CSSParticles() {
  const theme = useStore((s) => s.theme);
  const { tokensPerSecond, hasData } = useTokenData();
  const t = THEMES[theme];
  const count = hasData ? Math.min(40 + Math.floor(tokensPerSecond / 5), 120) : 25;

  const particles = useMemo(() => {
    return Array.from({ length: 120 }, (_, i) => {
      const duration = 3 + Math.random() * 5;
      const delay = Math.random() * duration;
      const x = 30 + Math.random() * 40; // 30-70% horizontal
      const size = 2 + Math.random() * 4;
      const drift = (Math.random() - 0.5) * 20;
      return { id: i, duration, delay, x, size, drift };
    });
  }, []);

  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none' }}>
      {particles.slice(0, count).map((p) => (
        <div
          key={p.id}
          className="fire-particle"
          style={{
            position: 'absolute',
            left: `${p.x}%`,
            bottom: '15%',
            width: p.size,
            height: p.size,
            borderRadius: '50%',
            background: t.fireCore,
            boxShadow: `0 0 ${p.size * 2}px ${t.fireCore}, 0 0 ${p.size * 4}px ${t.fireEdge}`,
            animation: `particleRise ${p.duration}s ease-out ${p.delay}s infinite`,
            opacity: 0,
            ['--drift' as string]: `${p.drift}px`,
          }}
        />
      ))}
    </div>
  );
}

function TokenHero() {
  const tokenData = useStore((s) => s.tokenData);
  const theme = useStore((s) => s.theme);
  const milestone = useStore((s) => s.milestone);
  const wsConnected = useStore((s) => s.wsConnected);
  const t = THEMES[theme];

  const displayValue = tokenData
    ? formatTokenCount(tokenData.totalTokens)
    : '—';

  const costDisplay = tokenData && tokenData.totalCostUSD > 0
    ? formatUSD(tokenData.totalCostUSD)
    : null;

  const subtitle = !wsConnected
    ? 'Connection lost'
    : !tokenData
      ? 'Begin your offering.'
      : null;

  const isWide = typeof window !== 'undefined' && window.innerWidth >= 1280;

  return (
    <div style={heroStyles.container}>
      <div
        style={{
          fontFamily: t.dataFont,
          fontSize: isWide ? 96 : 72,
          fontWeight: 300,
          color: t.textPrimary,
          textShadow: `0 0 40px ${t.accentGlow}, 0 0 80px ${t.accentGlow}, 0 0 120px ${t.accentGlow}`,
          lineHeight: 1,
          transition: 'color 1s ease, text-shadow 1s ease',
          letterSpacing: '-0.02em',
        }}
      >
        {displayValue}
      </div>
      {costDisplay && (
        <div
          style={{
            fontFamily: t.dataFont,
            fontSize: 20,
            color: t.textSecondary,
            marginTop: 12,
            opacity: 0.6,
            letterSpacing: '0.05em',
          }}
        >
          {costDisplay}
        </div>
      )}
      {subtitle && (
        <div
          style={{
            fontFamily: t.scriptureFont,
            fontSize: 18,
            color: !wsConnected ? '#ff4444' : t.textMuted,
            marginTop: 20,
            opacity: 0.8,
            fontStyle: 'italic',
          }}
        >
          {subtitle}
        </div>
      )}
      {milestone && (
        <div
          style={{
            fontFamily: t.scriptureFont,
            fontSize: 20,
            color: t.fireCore,
            marginTop: 16,
            textShadow: `0 0 20px ${t.accentGlow}`,
            animation: 'milestoneGlow 2s ease-in-out infinite',
          }}
        >
          {milestone.nameZh} — {milestone.name}
        </div>
      )}
    </div>
  );
}

function GlowOverlay() {
  const milestone = useStore((s) => s.milestone);
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];
  const [glowing, setGlowing] = useState(false);

  useEffect(() => {
    if (milestone && (milestone.effect === 'screen_glow' || milestone.effect === 'flash')) {
      setGlowing(true);
      const timer = setTimeout(() => setGlowing(false), 2000);
      return () => clearTimeout(timer);
    }
  }, [milestone]);

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        pointerEvents: 'none',
        background: `radial-gradient(ellipse at 50% 55%, ${t.accentGlow} 0%, transparent 60%)`,
        opacity: glowing ? 0.8 : 0.25,
        transition: 'opacity 2s ease',
        zIndex: 1,
      }}
    />
  );
}

export function AltarScene() {
  return (
    <div style={altarStyles.container}>
      <GlowOverlay />
      <CSSParticles />
      <TokenHero />
    </div>
  );
}

const heroStyles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    textAlign: 'center',
    zIndex: 5,
    pointerEvents: 'none',
    userSelect: 'none',
  },
};

const altarStyles: Record<string, React.CSSProperties> = {
  container: {
    width: '100%',
    height: '70vh',
    position: 'relative',
  },
};
