---
name: Midnight Lounge
colors:
  surface: '#101415'
  surface-dim: '#101415'
  surface-bright: '#363a3b'
  surface-container-lowest: '#0b0f10'
  surface-container-low: '#191c1e'
  surface-container: '#1d2022'
  surface-container-high: '#272a2c'
  surface-container-highest: '#323537'
  on-surface: '#e0e3e5'
  on-surface-variant: '#d0c5af'
  inverse-surface: '#e0e3e5'
  inverse-on-surface: '#2d3133'
  outline: '#99907c'
  outline-variant: '#4d4635'
  surface-tint: '#e9c349'
  primary: '#f2ca50'
  on-primary: '#3c2f00'
  primary-container: '#d4af37'
  on-primary-container: '#554300'
  inverse-primary: '#735c00'
  secondary: '#95d3ba'
  on-secondary: '#003829'
  secondary-container: '#0b513d'
  on-secondary-container: '#83c2a9'
  tertiary: '#c8cee3'
  on-tertiary: '#293040'
  tertiary-container: '#acb3c7'
  on-tertiary-container: '#3e4556'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffe088'
  primary-fixed-dim: '#e9c349'
  on-primary-fixed: '#241a00'
  on-primary-fixed-variant: '#574500'
  secondary-fixed: '#b0f0d6'
  secondary-fixed-dim: '#95d3ba'
  on-secondary-fixed: '#002117'
  on-secondary-fixed-variant: '#0b513d'
  tertiary-fixed: '#dce2f7'
  tertiary-fixed-dim: '#c0c6db'
  on-tertiary-fixed: '#141b2b'
  on-tertiary-fixed-variant: '#404758'
  background: '#101415'
  on-background: '#e0e3e5'
  surface-variant: '#323537'
typography:
  card-value:
    fontFamily: Noto Serif
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 24px
  player-name:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0.05em
  label-caps:
    fontFamily: Manrope
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.1em
  body-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  button-text:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  card-overlap: -40px
  gutter-md: 24px
  margin-edge: 32px
  panel-padding: 16px
---

## Brand & Style

This design system targets an upscale, adult audience seeking a premium digital card-playing experience. The brand personality is sophisticated, exclusive, and composed, mirroring the atmosphere of a high-stakes midnight lounge. 

The aesthetic blends **Tactile Skeuomorphism** with **Glassmorphism**. While the primary playing surface uses rich, physical textures to ground the experience, the UI overlays utilize translucent, blurred layers to feel modern and non-intrusive. The goal is to evoke the sensory weight of a physical casino—heavy cards, felt tables, and dim lighting—while maintaining the efficiency of a high-end modern application.

## Colors

The palette is anchored by "Midnight Emerald," a deep, desaturated green that serves as the tactile base for the table. 

- **Primary (Gold):** Used exclusively for highlights, primary CTA buttons (like "End Turn"), and critical game indicators. It should feel metallic and luminous against the dark backgrounds.
- **Secondary (Emerald):** The table surface. This should be treated with a subtle noise or "felt" texture to provide visual depth.
- **Tertiary (Charcoal):** The foundation for UI panels, player labels, and glassmorphic backgrounds. It provides the "night" atmosphere.
- **Neutral:** A range of off-whites used for typography and the faces of the cards to ensure high legibility.
- **Functional Red:** A deep, rich crimson used for heart and diamond suits, ensuring they pop without breaking the sophisticated mood.

## Typography

This design system employs a high-contrast typographic pairing to balance tradition and modernity. 

**Noto Serif** is reserved for the cards themselves—values and suits. It provides a classic, authoritative feel reminiscent of traditional luxury decks.

**Manrope** handles all functional UI elements. It is used for player names, game statistics, and system labels. Large labels (like "WELL" or "BOARD") should be set in uppercase with increased letter spacing to enhance the premium, architectural feel of the interface.

## Layout & Spacing

The layout follows a **Fixed Grid** approach for the central board to ensure strategic clarity, while player hands and wells use contextual spacing.

- **The Board:** Centrally aligned with four distinct slots, each defined by a subtle glassmorphic container.
- **The Well & Hand:** Positioned at the corners and bottom edge respectively. Cards in the "hand" should have a negative horizontal margin (`card-overlap`) to simulate a fan-out effect.
- **Safe Zones:** A 32px margin is maintained from the screen edge for all critical UI elements to ensure they don't feel "cramped" against the bezel.
- **Hierarchy:** Spacing is used to group the "Well" and "Board" cards of each player together, creating clear visual ownership.

## Elevation & Depth

Depth is a critical component of the "Midnight Lounge" experience. 

1. **The Table (Level 0):** The bottom-most layer, featuring a felt texture and deep emerald color.
2. **UI Panels (Level 1):** Use a glassmorphic effect—`background-color: rgba(17, 24, 39, 0.7)` with a high backdrop-blur (20px). This allows the table color to bleed through while keeping the UI legible.
3. **The Cards (Level 2):** Cards feature a multi-layered shadow. A sharp, dark shadow for immediate contact, and a softer, diffused shadow to suggest they are hovering or resting slightly above the felt.
4. **Active State (Level 3):** When a card is selected or hovered, its elevation increases via a larger, more spread shadow and a 1px Gold (#d4af37) outer glow.

## Shapes

The shape language is "Soft," utilizing refined radii that suggest quality craftsmanship without appearing too playful or bubbly.

- **Cards:** Use `rounded-lg` (8px) to mimic the standard die-cut of professional playing cards.
- **UI Panels:** Use `rounded-xl` (12px) for a modern, glass-like appearance.
- **Buttons:** Primary actions like "End Turn" use `rounded-md` (4px) to maintain a sense of formal precision. 
- **Icons:** Use thin strokes (1.5px) and sharp terminals to match the sophisticated typography.

## Components

### Cards
Cards are the hero of the system. They feature a pure white or cream background, Noto Serif typography for values, and high-fidelity suit icons. The back of the cards should feature a geometric, gold-foiled pattern on a charcoal or deep emerald base.

### Buttons
Primary buttons (e.g., "End Turn") are filled with the Gold (#d4af37) accent, using dark charcoal text. Secondary buttons (e.g., "Settings") are glassmorphic "ghost" buttons with a thin gold border.

### Player Labels
Player names sit atop a semi-transparent charcoal pill. A gold indicator dot or border glow signifies the current active turn.

### The "Well" & "Board" Containers
These are not empty spaces but "ghost slots"—subtle, dashed gold or low-opacity charcoal outlines that guide where cards should be placed, maintaining the grid's integrity even when the board is empty.

### Game Info Bar
A full-width bar at the bottom uses the glassmorphism style. It contains the "Your turn" status on the left and primary game controls on the right, ensuring the center of the screen remains dedicated to the tactical board.