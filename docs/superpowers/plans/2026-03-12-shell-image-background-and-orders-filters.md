# Shell Image Background And Orders Filter Sheets Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the shell image background, but move Orders date/amount/period controls into bottom sheets, improve glass contrast, and remove the visual seam on the Orders screen.

**Architecture:** Orders keeps compact top triggers inside the scroll content, but those triggers now launch dedicated modal bottom sheets that reuse the visual language of the existing order action/status sheets. Shared shell glass components get a darker tint so the PNG background stays visible without destroying text contrast.

**Tech Stack:** Flutter, Riverpod, modal bottom sheets, existing Orders repository/providers/tests, shared Deskflow theme and glass widgets.

---

## Chunk 1: Design Docs

### Task 1: Sync the spec and plan with the approved bottom-sheet redesign

**Files:**
- Modify: `docs/superpowers/specs/2026-03-12-shell-image-background-and-orders-filters-design.md`
- Modify: `docs/superpowers/plans/2026-03-12-shell-image-background-and-orders-filters.md`

- [x] Step 1: Replace the inline-panel design notes with bottom-sheet behavior.
- [x] Step 2: Record the stronger contrast and Orders background continuity requirements.

## Chunk 2: Red Tests

### Task 2: Write failing regression tests for the new Orders interaction model

**Files:**
- Modify: `test/features/orders/presentation/orders_list_screen_test.dart`

- [x] Step 1: Add a test asserting `Период` opens as a modal sheet from the bottom instead of rendering an inline card in the list.
- [x] Step 2: Add a test asserting `Сортировка` opens as a modal sheet containing date controls.
- [x] Step 3: Add a compact-height regression that opens amount mode inside the sheet and confirms no overflow/exception.
- [x] Step 4: Run the focused Orders widget tests and confirm they fail for the expected inline-vs-sheet reason.

## Chunk 3: Orders Filter Sheets

### Task 3: Rebuild Orders top filter flow around modal bottom sheets

**Files:**
- Modify: `lib/features/orders/presentation/orders_list_screen.dart`
- Modify: `lib/features/orders/domain/orders_list_controls.dart` (only if UI-driven state changes require cleanup)

- [x] Step 1: Remove the inline expanding filter card from the `ListView`.
- [x] Step 2: Implement a reusable Orders bottom sheet container matching the status/action sheets.
- [x] Step 3: Wire `Период` to its own bottom sheet with the 4 approved presets.
- [x] Step 4: Wire `Сортировка` to a bottom sheet that switches between advanced date and amount modes.
- [x] Step 5: Preserve advanced calendar capabilities: year affordance, manual input, icon-only range toggle, single/range selection.

## Chunk 4: Contrast And Background Continuity

### Task 4: Darken shell glass surfaces and eliminate the Orders seam

**Files:**
- Modify: `lib/core/theme/deskflow_theme.dart`
- Modify: `lib/core/widgets/glass_card.dart`
- Modify: `lib/core/widgets/pill_search_bar.dart`
- Modify: `lib/features/orders/presentation/orders_list_screen.dart`
- Modify: `lib/core/widgets/deskflow_shell_background.dart` (only if overlay tuning is needed)

- [x] Step 1: Increase dark tint/opacity for the shell-facing glass surfaces that sit on the bright PNG.
- [x] Step 2: Keep bottom sheets on a darker modal surface for readability.
- [x] Step 3: Ensure Orders no longer paints a large inline surface that visually splits the background.
- [x] Step 4: Keep the underlying image background visible and unblurred.

## Chunk 5: Verification

### Task 5: Run focused regression checks

**Files:**
- Test: `test/features/orders/presentation/orders_list_screen_test.dart`
- Test: `test/features/orders/domain/orders_list_controls_test.dart`
- Test: `test/features/orders/domain/order_stage2_providers_test.dart`
- Test: `test/features/orders/data/order_repository_test.dart`

- [x] Step 1: Run `flutter analyze` on the touched theme, widget, and Orders files.
- [x] Step 2: Run the focused Orders widget/domain/data tests.
- [x] Step 3: Confirm the new assertions reference modal sheets, not the removed inline panel.
