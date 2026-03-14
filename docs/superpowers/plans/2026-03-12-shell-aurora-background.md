# Shell Aurora Background Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable aurora/liquid background to the main shell tabs without affecting forms and admin flows.

**Architecture:** A single decorative background widget is rendered behind the shell navigation content. The 4 shell screens switch to transparent scaffolds so the shell-owned background becomes visible everywhere those tabs render.

**Tech Stack:** Flutter, CustomPaint, Stack, existing Deskflow theme system, widget tests.

---

## Chunk 1: Background Layer

### Task 1: Add the reusable aurora background widget

**Files:**
- Create: `lib/core/widgets/deskflow_aurora_background.dart`
- Modify: `lib/core/theme/deskflow_theme.dart`
- Test: `test/core/widgets/deskflow_aurora_background_test.dart`

- [ ] Step 1: Add aurora accent colors to the theme palette.
- [ ] Step 2: Create `DeskflowAuroraBackground` with a non-interactive `CustomPaint` composition.
- [ ] Step 3: Add a widget test that pumps the background and asserts it renders without exceptions.

## Chunk 2: Shell Integration

### Task 2: Render the background from the shell

**Files:**
- Modify: `lib/core/router/main_shell_screen.dart`

- [ ] Step 1: Place the background behind `navigationShell` in a full-screen `Stack`.
- [ ] Step 2: Keep `extendBody` so the background remains visible under the floating navbar.

### Task 3: Reveal the shell background on the 4 root tabs

**Files:**
- Modify: `lib/features/orders/presentation/orders_list_screen.dart`
- Modify: `lib/features/search/presentation/universal_search_screen.dart`
- Modify: `lib/features/customers/presentation/customers_list_screen.dart`
- Modify: `lib/features/profile/presentation/profile_screen.dart`

- [ ] Step 1: Switch those shell tab scaffolds to transparent backgrounds.
- [ ] Step 2: Leave non-shell screens unchanged.

## Chunk 3: Verification

### Task 4: Run regression checks

**Files:**
- Test: `test/core/widgets/deskflow_aurora_background_test.dart`
- Test: `test/features/orders/presentation/orders_list_screen_test.dart`
- Test: `test/features/profile/presentation/profile_screen_test.dart`

- [ ] Step 1: Run `flutter analyze` on the new widget, shell, and updated screens.
- [ ] Step 2: Run focused widget tests for the new background and existing shell screens.
- [ ] Step 3: Review the result for obvious readability regressions.
