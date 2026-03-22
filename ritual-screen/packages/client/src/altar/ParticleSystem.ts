import {
  PARTICLE_LIFETIME_MIN,
  PARTICLE_LIFETIME_MAX,
  PARTICLE_DRIFT_MIN,
  PARTICLE_DRIFT_MAX,
} from '@ritual-screen/shared';

// Convert px/s to Three.js world units/s (roughly 1 world unit = 100px at our camera distance)
const DRIFT_SCALE = 0.01;
const SPREAD_X = 4;
const SPAWN_Y = -1;
const SPAWN_Y_RANGE = 0.5;

export interface Particle {
  x: number;
  y: number;
  z: number;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
  opacity: number;
  size: number;
  active: boolean;
}

export class ParticlePool {
  particles: Particle[];
  private activeCount: number;

  constructor(maxCount: number) {
    this.activeCount = maxCount;
    this.particles = [];
    for (let i = 0; i < maxCount; i++) {
      this.particles.push(this.spawn(true));
    }
  }

  private spawn(randomizeAge: boolean): Particle {
    const maxLife =
      PARTICLE_LIFETIME_MIN +
      Math.random() * (PARTICLE_LIFETIME_MAX - PARTICLE_LIFETIME_MIN);
    const driftPx =
      PARTICLE_DRIFT_MIN + Math.random() * (PARTICLE_DRIFT_MAX - PARTICLE_DRIFT_MIN);
    return {
      x: (Math.random() - 0.5) * SPREAD_X,
      y: SPAWN_Y + Math.random() * SPAWN_Y_RANGE,
      z: (Math.random() - 0.5) * 1.5,
      vx: (Math.random() - 0.5) * 0.15,
      vy: driftPx * DRIFT_SCALE,
      life: randomizeAge ? Math.random() * maxLife : 0,
      maxLife,
      opacity: 0,
      size: 8 + Math.random() * 16,
      active: true,
    };
  }

  private respawn(p: Particle): void {
    const maxLife =
      PARTICLE_LIFETIME_MIN +
      Math.random() * (PARTICLE_LIFETIME_MAX - PARTICLE_LIFETIME_MIN);
    const driftPx =
      PARTICLE_DRIFT_MIN + Math.random() * (PARTICLE_DRIFT_MAX - PARTICLE_DRIFT_MIN);
    p.x = (Math.random() - 0.5) * SPREAD_X;
    p.y = SPAWN_Y + Math.random() * SPAWN_Y_RANGE;
    p.z = (Math.random() - 0.5) * 1.5;
    p.vx = (Math.random() - 0.5) * 0.15;
    p.vy = driftPx * DRIFT_SCALE;
    p.life = 0;
    p.maxLife = maxLife;
    p.opacity = 0;
    p.size = 8 + Math.random() * 16;
    p.active = true;
  }

  update(deltaMs: number): void {
    const dt = deltaMs / 1000;
    for (let i = 0; i < this.particles.length; i++) {
      const p = this.particles[i];
      if (i >= this.activeCount) {
        p.active = false;
        p.opacity = 0;
        continue;
      }
      p.active = true;
      p.life += deltaMs;

      if (p.life >= p.maxLife) {
        this.respawn(p);
        continue;
      }

      const progress = p.life / p.maxLife;
      // Smooth fade in and out
      if (progress < 0.1) {
        p.opacity = progress / 0.1;
      } else if (progress > 0.65) {
        p.opacity = Math.max(0, (1 - progress) / 0.35);
      } else {
        p.opacity = 1;
      }

      // Slight flicker
      p.opacity *= 0.85 + Math.random() * 0.15;

      p.y += p.vy * dt;
      p.x += p.vx * dt;
      // Slight horizontal damping and drift
      p.vx *= 0.995;
      p.vx += (Math.random() - 0.5) * 0.01;
    }
  }

  setActiveCount(count: number): void {
    this.activeCount = Math.min(count, this.particles.length);
  }

  getActiveCount(): number {
    return this.activeCount;
  }

  /** Burst: respawn all particles at once for a visual burst effect */
  burst(): void {
    for (let i = 0; i < this.activeCount; i++) {
      const p = this.particles[i];
      this.respawn(p);
      p.vy *= 2.5;
      p.vx *= 3;
      p.size *= 1.5;
    }
  }
}
