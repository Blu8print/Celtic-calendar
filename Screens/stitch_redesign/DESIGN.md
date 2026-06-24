---
name: Lumina Astrology
colors:
  surface: '#fcf8f8'
  surface-dim: '#ddd9d9'
  surface-bright: '#fcf8f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f2'
  surface-container: '#f1eded'
  surface-container-high: '#ebe7e7'
  surface-container-highest: '#e5e2e1'
  on-surface: '#1c1b1c'
  on-surface-variant: '#45474a'
  inverse-surface: '#313030'
  inverse-on-surface: '#f4f0f0'
  outline: '#76777b'
  outline-variant: '#c6c6ca'
  surface-tint: '#5d5e62'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1a1c1f'
  on-primary-container: '#838487'
  inverse-primary: '#c6c6ca'
  secondary: '#775a19'
  on-secondary: '#ffffff'
  secondary-container: '#fed488'
  on-secondary-container: '#785a1a'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#161f00'
  on-tertiary-container: '#7b8a4d'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2e2e6'
  primary-fixed-dim: '#c6c6ca'
  on-primary-fixed: '#1a1c1f'
  on-primary-fixed-variant: '#45474a'
  secondary-fixed: '#ffdea5'
  secondary-fixed-dim: '#e9c176'
  on-secondary-fixed: '#261900'
  on-secondary-fixed-variant: '#5d4201'
  tertiary-fixed: '#d9eaa3'
  tertiary-fixed-dim: '#bdce89'
  on-tertiary-fixed: '#161f00'
  on-tertiary-fixed-variant: '#3e4c16'
  background: '#fcf8f8'
  on-background: '#1c1b1c'
  surface-variant: '#e5e2e1'
typography:
  display-lg:
    fontFamily: Playfair Display
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Playfair Display
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Playfair Display
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-md:
    fontFamily: Playfair Display
    fontSize: 24px
    fontWeight: '500'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  container-margin: 24px
  gutter: 16px
  section-gap: 40px
---

## Brand & Style

The design system is rooted in the "Quiet Luxury" aesthetic—a philosophy that prioritizes understated elegance, precision, and serene spatial awareness. The brand personality is sophisticated and celestial, aiming to evoke a sense of calm and ritualistic connection to time.

The visual style blends **Minimalism** with **Editorial Modernism**. It leverages generous whitespace to let high-contrast typography and precise astronomical icons serve as the primary visual interest. The experience should feel like a premium printed almanac translated into a fluid digital interface, avoiding unnecessary ornamentation in favor of structural clarity and tactile softness.

## Colors

The palette is anchored by **Midnight Navy** (Primary) and **Light Cream** (Background) to create a high-contrast yet warm reading environment. **Champagne Gold** (Secondary) is used exclusively for celestial highlights, lunar phases, and active interactive states, providing a metallic "leaf" quality against the dark navy.

Functional accents include **Sage Green** for growth-oriented events or positive status and **Dusty Terracotta** for grounding rituals or alerts. These colors are used sparingly with low saturation to maintain the sophisticated, muted atmosphere of the design system.

## Typography

This design system utilizes a traditional editorial pairing. **Playfair Display** provides a refined, high-contrast serif for headings, suggesting authority and timelessness. **Inter** is used for all functional and body text to ensure maximum legibility and a modern, technical counterpoint to the serif's grace.

Hierarchy is established through significant size shifts and purposeful use of uppercase tracking in labels. Body text maintains generous line-height to improve the "breathing room" of the interface.

## Layout & Spacing

The layout follows a **Fixed-Fluid hybrid** model. On mobile, it utilizes a single-column vertical stack with 24px side margins. On larger screens, the content is centered within a 1200px container. 

The vertical rhythm is strictly adhered to, with a 40px gap between major functional sections (Daily Details, Calendar, Events). Within cards, an 8pt grid dictates padding, ensuring that elements like the lunar phase icon and the corresponding data have a precise, mathematical relationship.

## Elevation & Depth

Depth is achieved through **Tonal Layers** rather than aggressive shadows. The primary background is the Light Cream surface, while cards and containers use a pure white surface with a very subtle, highly diffused 10% opacity shadow (Midnight Navy tint).

To emphasize importance, active calendar days use a soft inner glow or a subtle "lift" effect. Ghost borders (0.5px width) in a muted taupe color are used to define boundaries in the calendar grid, maintaining a light and airy feel without the heaviness of standard borders.

## Shapes

The design system uses a **Rounded (Level 2)** shape language. This equates to 12px for standard cards and 8px for smaller UI elements like input fields or chips. This level of rounding balances the organic nature of celestial bodies with the structured precision of a luxury application. Buttons and selection indicators for specific dates use "Pill-shaped" geometry to provide a clear interactive affordance that stands out against the rectangular grid of the calendar.

## Components

### Celestial Icons
Icons for lunar phases and zodiac signs must be thin-line (1pt stroke) and rendered in Champagne Gold or Midnight Navy. They are the focal points of the UI and should have enough padding to feel like "jewels" on the page.

### Calendar Grid
The monthly grid should be borderless, using only alignment and subtle background shifts to denote days. The "Current Day" is indicated by a solid Midnight Navy circle with white text, while days with events feature a small, centered dot in Champagne Gold.

### Cards
Daily detail cards at the top of the hierarchy should use a white background with 16px corner radius and a subtle 1px border in a slightly darker cream to separate them from the main background.

### Buttons & Interaction
The Primary Action Button (FAB) uses a deep Midnight Navy fill with a Champagne Gold icon. Secondary buttons are "Ghost" style—thin borders with serif labels—to maintain the editorial aesthetic.

### Events List
List items should be separated by thin, hairline dividers. Time stamps use `label-sm` in a muted grey, while event titles use `body-md` in Midnight Navy. Use the Sage Green and Terracotta accents as vertical "indicator bars" on the left side of the event card to denote category or status.