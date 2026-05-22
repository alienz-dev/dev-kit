---
# DESIGN.md — Presentation Register
env: any
scope: any
# For: explainer pages, tutor content, portfolio presentations
# Register: brand surface (not product/dashboard)
colors:
  # Warm neutral base
  background: "#1a1a2e"
  surface: "#16213e"
  surface-elevated: "#1f3056"
  foreground: "#e8e6e3"
  foreground-muted: "#a8a5a0"
  # Accent
  accent: "#4fc3f7"
  accent-hover: "#81d4fa"
  accent-subtle: "rgba(79, 195, 247, 0.08)"
  # Semantic
  success: "#66bb6a"
  warning: "#ffa726"
  error: "#ef5350"
  info: "#4fc3f7"
  # Tinted neutrals (never pure gray)
  neutral-100: "#f5f3f0"
  neutral-200: "#e8e6e3"
  neutral-300: "#d4d1cc"
  neutral-400: "#a8a5a0"
  neutral-500: "#7a7774"
  neutral-600: "#4d4a47"
  neutral-700: "#2d2a27"
  neutral-800: "#1a1817"
  # Light theme overrides
  light:
    background: "#faf8f5"
    surface: "#ffffff"
    surface-elevated: "#ffffff"
    foreground: "#1a1817"
    foreground-muted: "#4d4a47"
    accent: "#0277bd"
    accent-hover: "#01579b"
    accent-subtle: "rgba(2, 119, 189, 0.06)"

typography:
  display:
    fontFamily: "'Inter', system-ui, -apple-system, sans-serif"
    fontSize: 56
    fontWeight: 900
    lineHeight: 1.1
    letterSpacing: "-0.03em"
  h1:
    fontFamily: "'Inter', system-ui, -apple-system, sans-serif"
    fontSize: 36
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.02em"
  h2:
    fontFamily: "'Inter', system-ui, -apple-system, sans-serif"
    fontSize: 24
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.01em"
  h3:
    fontFamily: "'Inter', system-ui, -apple-system, sans-serif"
    fontSize: 18
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "0"
  body:
    fontFamily: "'Inter', system-ui, -apple-system, sans-serif"
    fontSize: 16
    fontWeight: 400
    lineHeight: 1.7
    letterSpacing: "0"
  small:
    fontFamily: "'Inter', system-ui, -apple-system, sans-serif"
    fontSize: 14
    fontWeight: 400
    lineHeight: 1.5
  mono:
    fontFamily: "'JetBrains Mono', 'Fira Code', monospace"
    fontSize: 14
    fontWeight: 400
    lineHeight: 1.6

spacing:
  scale: [4, 8, 12, 16, 24, 32, 48, 64, 96, 128]
  section-gap: 64
  card-padding: 32
  inline-gap: 16

radius:
  sm: 6
  md: 12
  lg: 20
  xl: 32

elevation:
  sm: "0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08)"
  md: "0 4px 12px rgba(0,0,0,0.15), 0 2px 4px rgba(0,0,0,0.1)"
  lg: "0 12px 40px rgba(0,0,0,0.2), 0 4px 12px rgba(0,0,0,0.1)"

motion:
  duration-fast: "150ms"
  duration-normal: "300ms"
  duration-slow: "600ms"
  easing-default: "cubic-bezier(0.4, 0, 0.2, 1)"
  easing-entrance: "cubic-bezier(0, 0, 0.2, 1)"
  easing-exit: "cubic-bezier(0.4, 0, 1, 1)"
---

## Overview

This is a **brand surface** design system for presentation pages — explainer content, learning materials, portfolio-style pages. The goal is to feel like a professional design agency's work: confident, warm, with clear hierarchy and intentional whitespace.

Personality: **Professional. Warm. Confident.**

Not: generic developer docs, not SaaS marketing, not Material Design defaults.

## Colors

Warm-tinted dark base with a single cool accent (sky blue) for contrast. Never use pure gray — all neutrals have a warm brown undertone. The accent is used sparingly: headings, links, highlights, borders on active elements. Not for backgrounds.

Light theme uses warm cream (#faf8f5) instead of pure white, with a deeper blue accent for contrast.

## Typography

Inter is the sole typeface — used across all weights to create hierarchy through size and weight alone. The display size (56px/900) is reserved for hero sections only. Regular content uses h1 (36/700) → h2 (24/600) → body (16/400).

Letter-spacing tightens as size increases (negative tracking on display/h1). Body text has generous line-height (1.7) for readability.

## Layout

Content max-width: 900px (tighter than typical — creates focused reading experience).
Section gap: 64px (generous breathing room between sections).
Card padding: 32px.

No cards-in-cards. Sections are separated by whitespace, not borders. Use subtle background color shifts for grouping.

## Elevation & Depth

Three levels only:
- **sm** — subtle lift for interactive elements on hover
- **md** — cards and elevated surfaces
- **lg** — hero sections, modals, featured content

Shadows use warm-tinted black (not pure black rgba).

## Motion

All animations use `cubic-bezier(0.4, 0, 0.2, 1)` (Material ease) or entrance-specific `cubic-bezier(0, 0, 0.2, 1)`.

Never: bounce, elastic, or spring easing. Never: animation duration > 600ms.

Entrance pattern: fade-up (translateY(20px) + opacity 0 → 1), staggered by 80ms per element.

## Do's and Don'ts

**Do:**
- Use generous whitespace between sections (64px+)
- Tighten letter-spacing on large text
- Use accent color sparingly (links, highlights, one element per section max)
- Vary section backgrounds subtly (alternate surface/background)
- Use elevation to create depth hierarchy

**Don't:**
- Wrap everything in bordered cards
- Use uniform spacing everywhere
- Use pure gray (#808080, #666, etc)
- Use bounce/elastic easing
- Use more than one accent color
- Put cards inside cards
- Use glassmorphism or gradient backgrounds on content
- Use decorative elements that don't serve hierarchy
