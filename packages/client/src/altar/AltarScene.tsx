import { useRef, useMemo, useEffect, useState, useCallback } from 'react';
import { useStore } from '../stores/store';
import { useTokenData } from '../hooks/useTokenData';
import { THEMES, formatTokenCount, formatUSD } from '@ritual-screen/shared';
import { LaughingMan } from './LaughingMan';
import { BladeRunnerEye } from './BladeRunnerEye';
import { TronGrid } from './TronGrid';
import { NervHex } from './NervHex';
import { DuneRunes } from './DuneRunes';

// Matrix digital rain — canvas-based falling characters
function MatrixRain() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animRef = useRef<number>(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const resize = () => {
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;
    };
    resize();
    window.addEventListener('resize', resize);

    const fontSize = 14;
    const columns = Math.floor(canvas.width / fontSize);
    const drops: number[] = Array.from({ length: columns }, () => Math.random() * -100);
    const chars = 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789ABCDEF';

    let lastTime = 0;
    const draw = (time: number) => {
      if (document.hidden) {
        animRef.current = requestAnimationFrame(draw);
        return;
      }

      // Target ~20fps for the classic Matrix look
      if (time - lastTime < 50) {
        animRef.current = requestAnimationFrame(draw);
        return;
      }
      lastTime = time;

      // Fade trail
      ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      ctx.font = `${fontSize}px "Fira Code", monospace`;

      const centerX = canvas.width / 2;
      const centerY = canvas.height * 0.45;

      for (let i = 0; i < columns; i++) {
        const char = chars[Math.floor(Math.random() * chars.length)];
        const x = i * fontSize;
        const y = drops[i] * fontSize;

        // Fade out columns near center to give hero number breathing room
        const dx = Math.abs(x - centerX) / (canvas.width * 0.3);
        const dy = Math.abs(y - centerY) / (canvas.height * 0.25);
        const distFromCenter = Math.sqrt(dx * dx + dy * dy);
        const centerFade = Math.min(1, Math.max(0.1, distFromCenter));

        // Head character is bright white-green
        if (Math.random() > 0.3) {
          ctx.fillStyle = '#00ff41';
          ctx.globalAlpha = 0.9 * centerFade;
        } else {
          ctx.fillStyle = '#80ff80';
          ctx.globalAlpha = 1 * centerFade;
        }
        ctx.fillText(char, x, y);
        ctx.globalAlpha = 1;

        // Reset drop to top when it reaches bottom
        if (y > canvas.height && Math.random() > 0.975) {
          drops[i] = 0;
        }
        drops[i]++;
      }

      animRef.current = requestAnimationFrame(draw);
    };

    animRef.current = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(animRef.current);
      window.removeEventListener('resize', resize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'absolute',
        inset: 0,
        width: '100%',
        height: '100%',
        opacity: 0.4,
        pointerEvents: 'none',
        zIndex: 0,
      }}
    />
  );
}

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
  const isMatrix = theme === 'matrix';

  return (
    <div style={heroStyles.container}>
      {/* Dark backdrop behind hero number for Matrix readability */}
      {isMatrix && (
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: '120%',
          height: '200%',
          background: 'radial-gradient(ellipse, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0.4) 50%, transparent 70%)',
          zIndex: -1,
        }} />
      )}
      <div
        style={{
          fontFamily: t.dataFont,
          fontSize: isWide ? 96 : 72,
          fontWeight: isMatrix ? 400 : 300,
          color: isMatrix ? '#ffffff' : t.textPrimary,
          textShadow: isMatrix
            ? '0 0 20px #00ff41, 0 0 40px #00ff41, 0 0 80px rgba(0,255,65,0.5)'
            : `0 0 40px ${t.accentGlow}, 0 0 80px ${t.accentGlow}, 0 0 120px ${t.accentGlow}`,
          lineHeight: 1,
          transition: 'color 1s ease, text-shadow 1s ease',
          letterSpacing: '-0.02em',
          fontVariantNumeric: 'tabular-nums',
        }}
      >
        {displayValue}
      </div>
      {costDisplay && (
        <div
          style={{
            fontFamily: t.dataFont,
            fontSize: 20,
            color: isMatrix ? '#88ff88' : t.textSecondary,
            marginTop: 12,
            opacity: isMatrix ? 0.8 : 0.6,
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
  const theme = useStore((s) => s.theme);
  const isMatrix = theme === 'matrix';

  const isCyber = theme === 'cyber';

  return (
    <div style={{ ...altarStyles.container, height: isMatrix ? '100vh' : '70vh' }}>
      <GlowOverlay />
      {isMatrix ? <MatrixRain /> : <CSSParticles />}
      {isCyber && <LaughingMan />}
      {theme === 'cyberpunk' && <BladeRunnerEye />}
      {theme === 'synthwave' && <TronGrid />}
      {theme === 'blood' && <NervHex />}
      {theme === 'ancient' && <DuneRunes />}
      <TokenHero />
    </div>
  );
}

const heroStyles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    top: '45%',
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
