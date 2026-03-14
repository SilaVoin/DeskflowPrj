# Orders Filters, Navbar, Template Dialog, And Invite RPC Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Починить layout navbar, сделать template dialog плотнее, заменить псевдо-сортировку на фильтры даты/суммы и исправить invite RPC migration-уровнем.

**Architecture:** UI-исправления остаются локальными: navbar правится в `FloatingIslandNav`, modal density в create/edit order dialogs, а `Orders` переводится на явные filters `selectedDate` и `amountRange` вместо старого `sort/status` UX. Backend fix выполняется через каноническую SQL-миграцию и применение через Supabase MCP, чтобы устранить зависимость от `search_path`.

**Tech Stack:** Flutter, Riverpod, Supabase, Postgres SQL migrations, widget tests, repository tests

---

## Chunk 1: Navbar And Template Dialog

### Task 1: Guard navbar active-pill layout

**Files:**
- Modify: `lib/core/widgets/floating_island_nav.dart`
- Modify: `test/core/widgets/floating_island_nav_test.dart`

- [x] **Step 1: Write a failing widget test for active tab label staying inside constrained layout**
- [x] **Step 2: Run the nav test to verify it fails**
- [x] **Step 3: Implement minimal navbar width/ellipsis constraints**
- [x] **Step 4: Run the nav test to verify it passes**

### Task 2: Make save-template dialog denser

**Files:**
- Modify: `lib/features/orders/presentation/create_order_screen.dart`
- Modify: `lib/features/orders/presentation/edit_order_screen.dart`
- Test: `test/features/orders/presentation/create_order_screen_test.dart`
- Test: `test/features/orders/presentation/edit_order_screen_test.dart`

- [x] **Step 1: Write failing tests for save-template dialog using the denser modal styling hooks**
- [x] **Step 2: Run the targeted dialog tests to verify they fail**
- [x] **Step 3: Implement the modal background/barrier tightening in both screens**
- [x] **Step 4: Run the targeted dialog tests to verify they pass**

## Chunk 2: Orders Filters

### Task 3: Replace secondary sort controls with date and amount filters

**Files:**
- Modify: `lib/features/orders/domain/orders_list_controls.dart`
- Modify: `lib/features/orders/presentation/orders_list_screen.dart`
- Modify: `test/features/orders/presentation/orders_list_screen_test.dart`

- [x] **Step 1: Write failing tests for `Дата` calendar trigger, `Сумма` range sheet, and removal of `По статусу`**
- [x] **Step 2: Run the orders presentation tests to verify they fail**
- [x] **Step 3: Implement the minimal UI/state changes for date and amount filters**
- [x] **Step 4: Run the orders presentation tests to verify they pass**

### Task 4: Apply filters in repository/provider layer

**Files:**
- Modify: `lib/features/orders/domain/order_providers.dart`
- Modify: `lib/features/orders/data/order_repository.dart`
- Modify: `test/features/orders/data/order_repository_test.dart`
- Modify: `test/features/orders/domain/order_stage2_providers_test.dart`

- [x] **Step 1: Write failing tests for exact-date and amount-range filtering**
- [x] **Step 2: Run the repository/provider tests to verify they fail**
- [x] **Step 3: Implement minimal provider/repository filtering logic**
- [x] **Step 4: Run the repository/provider tests to verify they pass**

## Chunk 3: Invite RPC

### Task 5: Fix `invite_member_by_email_v2` through migration

**Files:**
- Create: `supabase/migrations/20260312075010_fix_invite_rpc_and_orders_filters.sql`
- Modify: `lib/features/admin/data/admin_repository.dart`
- Modify: `test/features/admin/data/admin_repository_test.dart`

- [x] **Step 1: Write a failing regression test for surfacing raw backend function error as a mapped invite failure**
- [x] **Step 2: Run the invite screen tests to verify the new case fails**
- [x] **Step 3: Add canonical SQL migration enabling `pgcrypto` and schema-qualifying `gen_random_bytes`**
- [x] **Step 4: Extend error mapping only as needed for graceful fallback messaging**
- [x] **Step 5: Run the invite screen tests to verify they pass**
- [x] **Step 6: Apply the migration through Supabase MCP**

## Chunk 4: Verification

### Task 6: Verify the full fix set

**Files:**
- Modify: `docs/superpowers/plans/2026-03-12-orders-filters-nav-and-invite-fix.md`

- [x] **Step 1: Run `flutter analyze` on all touched Dart files**
- [x] **Step 2: Run all targeted tests for navbar, orders, and invite flows**
- [x] **Step 3: Verify the migration applied successfully in Supabase**
- [x] **Step 4: Mark completed checkboxes in this plan**
