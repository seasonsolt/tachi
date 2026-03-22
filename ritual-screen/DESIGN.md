# Design System — Ritual Screen

## Product Context
- **What this is:** Full-screen web experience that frames AI token consumption as a sacred "offering" ritual
- **Who it's for:** Indie developers and founders who vibe-code daily with Claude Code / Cursor, spending $20-$500+/month on AI APIs
- **Space/industry:** Developer tools × ambient experience × e/acc culture
- **Project type:** Immersive single-screen ambient display (second monitor companion)
- **Core insight:** Transform token spending anxiety into ritual meaning — "Every token is an offering"

## Aesthetic Direction
- **Direction:** Luxury/Refined × Retro-Futuristic hybrid
- **Decoration level:** Intentional — fire particles, radial glow, but no gratuitous ornament
- **Mood:** Devotional, atmospheric, monumental. A digital temple, not a dashboard. The screen should feel sacred, not utilitarian.
- **Anti-patterns:** No cards, no grids, no feature sections, no CTAs. This is a single altar, not a webpage.

## Dual Theme System

### Theme A: "Ancient Altar" (古神殿)
| Token | Value | Usage |
|-------|-------|-------|
| `--bg` | `#0a0806` | Near-black warm brown. The void. |
| `--fire-core` | `#d4a017` | Amber/gold. The sacred flame. |
| `--fire-edge` | `#8b5e14` | Deep gold. Flame edge/glow. |
| `--text-primary` | `#e8d5b0` | Warm parchment. Hero number, headings. |
| `--text-secondary` | `#a89070` | Muted warm. Data values. |
| `--text-muted` | `#6b5a45` | Deep umber. Labels, controls. |
| `--accent-glow` | `rgba(212, 160, 23, 0.3)` | Radial glow, text-shadow. |
| Scripture font | `"EB Garamond", Georgia, serif` | Italic serif. Sacred, literary. |
| Data font | `"JetBrains Mono", "Fira Code", monospace` | Precise, technical. |

### Theme B: "Cyber Shrine" (赛博神殿)
| Token | Value | Usage |
|-------|-------|-------|
| `--bg` | `#050510` | Deep blue-black. The void, cold. |
| `--fire-core` | `#00d4ff` | Cyan. Electric flame. |
| `--fire-edge` | `#6366f1` | Indigo. Flame edge. |
| `--text-primary` | `#c0d8ff` | Cool blue-white. Hero number. |
| `--text-secondary` | `#7088b0` | Steel blue. Data values. |
| `--text-muted` | `#3a4a6b` | Deep slate. Labels, controls. |
| `--accent-glow` | `rgba(0, 212, 255, 0.3)` | Radial glow, text-shadow. |
| Scripture font | `"Space Grotesk", "Inter", sans-serif` | Geometric sans. Futuristic. |
| Data font | `"Fira Code", "JetBrains Mono", monospace` | Precise, technical. |

## Typography
- **Display/Hero:** Theme-dependent data font at 72-96px, weight 300, `font-variant-numeric: tabular-nums`, `letter-spacing: -0.02em`
- **Scripture:** Theme-dependent serif/sans at 18-20px italic, max-width 60%, `opacity: 0.6`
- **Data labels:** Data font at 10-13px, `text-transform: uppercase`, `letter-spacing: 1px`
- **Code/Numbers:** Data font, tabular-nums always
- **Loading:** Google Fonts with `display=swap` and `preconnect`
- **Scale:**
  - Hero: 96px (≥1280px) / 72px (<1280px)
  - Sub-hero: 24px
  - Body: 18-20px
  - Caption: 13-14px
  - Micro: 9-11px
  - Labels: 10px uppercase

## Spacing
- **Base unit:** 8px
- **Density:** Spacious — this is an ambient display, not a dense app
- **Scale:** xs(8) sm(16) md(24) lg(32) xl(48) 2xl(64)
- **Page margins:** 24px from edges for peripheral elements (Pulse, Chant)
- **Hero centering:** Absolute center of the altar area (70vh)

## Layout
- **Approach:** Fixed single-screen composition — no scrolling, no grid
- **Visual hierarchy:**
  1. Token count (center, 70% attention)
  2. Scripture (top center, intermittent)
  3. Pulse data (bottom-left, peripheral)
  4. Chant controls (bottom-right, peripheral)
  5. Settings gear (top-right, near-invisible)
- **Breakpoints:**
  - Full: ≥1280px — all elements, 96px hero
  - Compact: 768-1280px — all elements, 72px hero
  - Mobile: <768px — redirect message only
- **Border radius:** 0px everywhere. Sharp edges = monument/ritual feel.

## Motion
- **Approach:** Intentional — every animation serves the ritual atmosphere
- **Particles:** CSS `@keyframes particleRise` — 3-8s lifecycle, ease-out, 25-120 particles based on token rate
- **Scripture cycle:** opacity 0→0.6 (3s ease-in) → stay 12s → 0.6→0 (3s ease-out) → pause 8-15s random
- **Theme transitions:** `transition: background 1s ease` on root, `transition: color 1s ease` on text
- **Easing:** ease-out for particles (entering), ease-in for fading (exiting)
- **Duration range:** 200ms (number updates) to 3000ms (scripture fade) to 8000ms (particle life)
- **Reduced motion:** `@media (prefers-reduced-motion: reduce)` disables all animations
- **Never animate:** layout properties (width, height, top, left). Only opacity and transform.

## Interaction States
| Feature | Loading | Empty | Error | Normal |
|---------|---------|-------|-------|--------|
| Fire particles | Faint blue pulse | Ember state (faint glow) | Red tint, fade | Amber/cyan fire |
| Token number | "—" placeholder | "—" + "Begin your offering." | "Connection lost" red | Real-time count |
| Scripture | Hidden | Hidden | Unchanged | Cycling fade |
| Music | Loading indicator | Playing (ritual begins) | Silent degradation | Playing + controls |
| Settings | Hidden | Visible after first click | Unchanged | Slide-in panel |

## Milestone Effects
| Threshold | Name | Visual Effect |
|-----------|------|---------------|
| 10K | 初燃 First Flame | Flash (global opacity spike 1.5x, 1.5s) |
| 100K | 炽火 Blazing | Color pulse (white flash → return, 2s) |
| 500K | 烈焰 Inferno | Particle burst (count doubles 5s) |
| 1M | 恒火 Eternal Fire | Screen glow (radial gradient pulse) |
| 5M | 天火 Heavenly Fire | Theme color temporary shift |
| 10M | 永恒 Eternity | Permanent visual unlock |

## Accessibility
- **Keyboard:** Tab reaches settings gear, play button, volume slider, API key inputs, theme buttons
- **Focus visible:** 2px solid `var(--fire-core)` outline, 2px offset
- **Touch targets:** 44px minimum on all interactive elements
- **Color scheme:** `color-scheme: dark` on html element
- **Viewport:** No `maximum-scale` or `user-scalable=no` restrictions
- **Contrast:** All text meets WCAG AA 4.5:1 against dark backgrounds

## Audio
- **Default track:** 3-minute dark ambient drone (A minor, multi-layer sine waves + subtle noise)
- **Playback:** Web Audio API, loop, default volume 0.4
- **Controls:** Play/pause + volume slider, bottom-right, opacity 0.3 → 0.8 on hover

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-20 | CSS particles instead of WebGL | WebGL fails in many contexts; CSS particles work everywhere, bundle 5x smaller |
| 2026-03-20 | Token count as HTML overlay, not inside Three.js | Must be visible even without WebGL context |
| 2026-03-20 | 0px border-radius everywhere | Sharp edges create monument/ritual feel, distinguish from generic SaaS |
| 2026-03-20 | EB Garamond for Ancient, Space Grotesk for Cyber | Serif = sacred/literary, geometric sans = futuristic. Both are distinctive, not overused |
| 2026-03-20 | Opacity hierarchy (0.6/0.5/0.3) for peripheral elements | Central fire gets full attention; peripherals visible only in peripheral vision |
| 2026-03-20 | Initial design system codified | Created by /design-consultation from implemented product |
