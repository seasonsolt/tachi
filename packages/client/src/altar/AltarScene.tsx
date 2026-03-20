import { useRef, useMemo, useEffect } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Html } from '@react-three/drei';
import * as THREE from 'three';
import { useStore } from '../stores/store';
import { useTokenData } from '../hooks/useTokenData';
import { THEMES, formatTokenCount } from '@ritual-screen/shared';
import { ParticlePool } from './ParticleSystem';

const MAX_PARTICLES = 1000;
const MIN_PARTICLES = 500;

function Particles() {
  const theme = useStore((s) => s.theme);
  const { tokensPerSecond, hasData } = useTokenData();
  const t = THEMES[theme];

  const meshRef = useRef<THREE.InstancedMesh>(null);
  const { viewport } = useThree();

  const pool = useMemo(
    () => new ParticlePool(MAX_PARTICLES, viewport.width, viewport.height),
    [],
  );

  useEffect(() => {
    pool.resize(viewport.width, viewport.height);
  }, [viewport.width, viewport.height, pool]);

  const dummy = useMemo(() => new THREE.Object3D(), []);
  const color = useMemo(() => new THREE.Color(), []);

  useFrame((_, delta) => {
    if (!meshRef.current || document.hidden) return;

    const rate = hasData ? Math.min(tokensPerSecond, 500) : 10;
    const count = Math.floor(
      MIN_PARTICLES + (rate / 500) * (MAX_PARTICLES - MIN_PARTICLES),
    );
    pool.setActiveCount(count);
    pool.update(delta * 1000);

    const active = pool.getActiveCount();
    for (let i = 0; i < MAX_PARTICLES; i++) {
      const p = pool.particles[i];
      if (i >= active) {
        dummy.position.set(0, -999, 0);
        dummy.scale.set(0, 0, 0);
      } else {
        dummy.position.set(p.x, p.y, p.z);
        const s = p.size * (0.5 + p.opacity * 0.5);
        dummy.scale.set(s, s, s);
      }
      dummy.updateMatrix();
      meshRef.current.setMatrixAt(i, dummy.matrix);

      color.set(t.particleColor);
      if (i < active) {
        meshRef.current.setColorAt(i, color);
      }
    }
    meshRef.current.instanceMatrix.needsUpdate = true;
    if (meshRef.current.instanceColor) {
      meshRef.current.instanceColor.needsUpdate = true;
    }
  });

  return (
    <instancedMesh ref={meshRef} args={[undefined, undefined, MAX_PARTICLES]}>
      <sphereGeometry args={[1, 6, 6]} />
      <meshBasicMaterial transparent opacity={0.8} toneMapped={false} />
    </instancedMesh>
  );
}

function TokenOverlay() {
  const tokenData = useStore((s) => s.tokenData);
  const theme = useStore((s) => s.theme);
  const milestone = useStore((s) => s.milestone);
  const wsConnected = useStore((s) => s.wsConnected);
  const t = THEMES[theme];

  const displayValue = tokenData
    ? formatTokenCount(tokenData.totalTokens)
    : '—';

  const subtitle = !wsConnected
    ? 'Connection lost'
    : !tokenData
      ? 'Begin your offering.'
      : null;

  return (
    <Html center style={{ pointerEvents: 'none', userSelect: 'none' }}>
      <div style={{ textAlign: 'center', whiteSpace: 'nowrap' }}>
        <div
          style={{
            fontFamily: t.dataFont,
            fontSize: window.innerWidth >= 1280 ? 96 : 72,
            fontWeight: 300,
            color: t.textPrimary,
            textShadow: `0 0 40px ${t.accentGlow}, 0 0 80px ${t.accentGlow}`,
            lineHeight: 1,
            transition: 'color 1s ease',
          }}
        >
          {displayValue}
        </div>
        {subtitle && (
          <div
            style={{
              fontFamily: t.scriptureFont,
              fontSize: 16,
              color: !wsConnected ? '#ff4444' : t.textMuted,
              marginTop: 16,
              opacity: 0.8,
            }}
          >
            {subtitle}
          </div>
        )}
        {milestone && (
          <div
            style={{
              fontFamily: t.scriptureFont,
              fontSize: 18,
              color: t.fireCore,
              marginTop: 12,
              opacity: 0.9,
              textShadow: `0 0 20px ${t.accentGlow}`,
            }}
          >
            {milestone.nameZh} — {milestone.name}
          </div>
        )}
      </div>
    </Html>
  );
}

export function AltarScene() {
  const theme = useStore((s) => s.theme);
  const t = THEMES[theme];

  return (
    <div style={styles.container}>
      <Canvas
        camera={{ position: [0, 2, 8], fov: 50 }}
        style={{ background: 'transparent' }}
        gl={{ alpha: true, antialias: true }}
      >
        <color attach="background" args={[t.bg]} />
        <ambientLight intensity={0.2} />
        <pointLight position={[0, 5, 0]} intensity={1} color={t.fireCore} />
        <Particles />
        <TokenOverlay />
      </Canvas>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    width: '100%',
    height: '65vh',
    position: 'relative',
  },
};
