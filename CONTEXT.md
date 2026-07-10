# EACC — Ubiquitous Language

A glossary of the terms this project uses. Definitions only — no implementation details.

## Companion / Pet

The ambient creature that represents the current theme's presence. Each theme
resolves to a **Persona** (Orb, Laughing Man, Digital Rain, Folded Signal,
Monolith), and the persona's artwork reacts to **Mood**.

## Persona

The visual identity a companion takes. Distinct from theme: a theme *defaults*
to a persona, but the user can override the persona independently.

## Mood

The companion's activity state, driven by live token flow: `feasting`,
`alert`, `expecting`, `dozing`, `sleeping`. Everything the pet renders —
brightness, tempo, shadows — ramps with mood.

## Surface

A place a companion can be rendered. There are two: the **floating surface**
(a transparent window over the arbitrary, uncontrolled desktop) and the
**panel surface** (inside the menu-bar panel, whose background is controlled
by the active theme).

## Contrast Grounding

The design rule that a pet's artwork must remain readable on *any* surface
background — including white — without being placed in a visible box. Chosen
over a backdrop plate (breaks the frameless illusion) and over background
detection (requires screen-capture permission).

## Ambient Scrim

The soft, feathered dark radial layer behind a pet that implements contrast
grounding. Invisible against dark backgrounds, provides ground against light
ones. Scales with mood.

## Halo Pass

A blurred dark copy drawn beneath an individual bright element (a white glyph
head, the eclipse photosphere) — the subtitle trick. Used sparingly, only
where the ambient scrim alone cannot carry a pure-white element.
