# Orders Filter Block And FAB Restore Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Вернуть period presets на Orders, заменить системный выбор даты встроенным календарным блоком, сохранить фильтр суммы в том же блоке и восстановить единый тёмный glass-стиль add/FAB-кнопок.

**Architecture:** Верхняя зона Orders переводится на один scroll-safe filters card с period/date/amount controls. Дата и период хранятся в одном state-модуле как взаимоисключающие режимы фильтрации, а repository использует либо exact day, либо period range. FAB-стиль централизуется через общий glass component, чтобы избежать повторного дрейфа темы.

**Tech Stack:** Flutter, Riverpod, widget tests, repository tests, Supabase-backed filtering

---

## Chunk 1: Orders Filter State And Data

### Task 1: Extend orders controls with period presets

**Files:**
- Modify: `lib/features/orders/domain/orders_list_controls.dart`
- Modify: `lib/features/orders/domain/order_providers.dart`
- Modify: `test/features/orders/domain/orders_list_controls_test.dart`
- Modify: `test/features/orders/domain/order_stage2_providers_test.dart`

- [ ] **Step 1: Write failing tests for period preset state and period/date mutual reset behavior**
- [ ] **Step 2: Run the targeted controls/provider tests to verify they fail**
- [ ] **Step 3: Implement `OrdersPeriodPreset` and update controls/provider wiring**
- [ ] **Step 4: Run the targeted controls/provider tests to verify they pass**

### Task 2: Apply period filtering in repository

**Files:**
- Modify: `lib/features/orders/data/order_repository.dart`
- Modify: `test/features/orders/data/order_repository_test.dart`

- [ ] **Step 1: Write failing repository tests for period-based date range filtering**
- [ ] **Step 2: Run the repository test subset to verify it fails**
- [ ] **Step 3: Implement minimal repository logic for period ranges with exact-date precedence**
- [ ] **Step 4: Run the repository test subset to verify it passes**

## Chunk 2: Orders Filter Block UI

### Task 3: Replace the current pill row with a unified filters card

**Files:**
- Modify: `lib/features/orders/presentation/orders_list_screen.dart`
- Modify: `test/features/orders/presentation/orders_list_screen_test.dart`

- [ ] **Step 1: Write failing widget tests for the restored `Период` control and absence of overflow-prone layout**
- [ ] **Step 2: Run the orders screen widget tests to verify they fail**
- [ ] **Step 3: Implement the scroll-safe unified filters card layout**
- [ ] **Step 4: Run the widget tests to verify they pass**

### Task 4: Add inline calendar and keep amount section in the same block

**Files:**
- Modify: `lib/features/orders/presentation/orders_list_screen.dart`
- Modify: `test/features/orders/presentation/orders_list_screen_test.dart`

- [ ] **Step 1: Write failing widget tests for inline calendar expansion, amount section presence, and period/date reset rules**
- [ ] **Step 2: Run the focused orders screen tests to verify they fail**
- [ ] **Step 3: Implement the calendar section and amount section behavior**
- [ ] **Step 4: Run the focused orders screen tests to verify they pass**

## Chunk 3: FAB Restore

### Task 5: Restore dark glass add buttons across affected screens

**Files:**
- Modify: `lib/core/widgets/glass_floating_action_button.dart`
- Modify: `lib/features/customers/presentation/customers_list_screen.dart`
- Modify: `lib/features/products/presentation/products_list_screen.dart`
- Modify: `lib/features/admin/presentation/user_management_screen.dart`
- Modify: `lib/features/admin/presentation/pipeline_config_screen.dart`
- Modify: `lib/features/admin/presentation/catalog_management_screen.dart`
- Test: `test/features/admin/presentation/admin_glass_fab_test.dart`

- [ ] **Step 1: Write or update failing tests that assert the shared dark glass FAB styling contract**
- [ ] **Step 2: Run the targeted FAB tests to verify they fail**
- [ ] **Step 3: Restore the shared glass FAB usage/style on all affected screens**
- [ ] **Step 4: Run the targeted FAB tests to verify they pass**

## Chunk 4: Verification

### Task 6: Verify the whole package

**Files:**
- Modify: `docs/superpowers/plans/2026-03-12-orders-filter-block-and-fab-restore.md`

- [ ] **Step 1: Run `flutter analyze` on all touched Dart files**
- [ ] **Step 2: Run the targeted orders/FAB tests**
- [ ] **Step 3: Confirm the current `terminal.txt` issues are resolved or reduced to known unrelated items**
- [ ] **Step 4: Mark completed checkboxes in this plan**
