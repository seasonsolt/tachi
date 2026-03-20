import { useStore } from '../stores/store';

/**
 * Laughing Man — Ghost in the Shell: Stand Alone Complex
 * Uses the original SVG. Text ring rotates, face stays still.
 * Two layers: rotating full logo (text ring visible) + static face (clipped to center)
 */
export function LaughingMan() {
  const theme = useStore((s) => s.theme);

  // CSS filter to recolor the dark blue SVG to match theme cyan
  const filter = 'brightness(0) invert(1) sepia(1) saturate(10) hue-rotate(155deg) brightness(0.6) contrast(1.2)';

  return (
    <div style={styles.container}>
      {/* Layer 1: ROTATING — the full logo (text ring is what you see rotating) */}
      <div style={styles.rotatingLayer}>
        <img
          src="/images/laughing-man.svg"
          alt=""
          style={{ ...styles.img, filter, opacity: 0.25 }}
        />
      </div>

      {/* Layer 2: STATIC — face only, clipped to inner circle so text ring is hidden */}
      <div style={styles.staticLayer}>
        <img
          src="/images/laughing-man.svg"
          alt=""
          style={{ ...styles.img, filter, opacity: 0.3, clipPath: 'circle(38% at 50% 53%)' }}
        />
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    position: 'absolute',
    top: '45%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    width: '60vh',
    height: '60vh',
    maxWidth: '600px',
    maxHeight: '600px',
    pointerEvents: 'none',
    zIndex: 2,
  },
  rotatingLayer: {
    position: 'absolute',
    inset: 0,
    animation: 'laughingManSpin 50s linear infinite',
  },
  staticLayer: {
    position: 'absolute',
    inset: 0,
  },
  img: {
    width: '100%',
    height: '100%',
    objectFit: 'contain',
  },
};
