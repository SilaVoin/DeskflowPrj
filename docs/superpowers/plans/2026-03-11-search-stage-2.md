# Search Stage 2 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Deskflow search into a faster workspace with synced personal history, sticky filters, and clearer browse-to-results flow.

**Architecture:** Keep the implementation inside `features/search`. Add explicit search control state, a user-scoped synced history repository, and extend the existing search providers so they understand entity and order-status filtering without duplicating repository logic.

**Tech Stack:** Flutter, Riverpod, Supabase, flutter_test

---

## File Map

- Create: `lib/features/search/domain/search_controls.dart`
- Create: `lib/features/search/domain/search_history_entry.dart`
- Create: `lib/features/search/data/search_history_repository.dart`
- Create: `test/features/search/domain/search_controls_test.dart`
- Create: `test/features/search/domain/search_history_entry_test.dart`
- Create: `test/features/search/data/search_history_repository_test.dart`
- Create: `test/features/search/presentation/universal_search_screen_test.dart`
- Modify: `lib/features/search/domain/search_providers.dart`
- Modify: `lib/features/search/presentation/universal_search_screen.dart`
- Modify: `lib/features/orders/data/order_repository.dart`
- Modify: `test/features/search/domain/search_results_test.dart`
- Modify: `test/features/orders/data/order_repository_test.dart`
- External: apply a Supabase schema migration for `search_history` storage and user-scoped access policies

## Chunk 1: Search History and Controls Foundation

### Task 1: Model search controls and history entities

**Files:**
- Create: `lib/features/search/domain/search_controls.dart`
- Create: `lib/features/search/domain/search_history_entry.dart`
- Create: `test/features/search/domain/search_controls_test.dart`
- Create: `test/features/search/domain/search_history_entry_test.dart`

- [x] **Step 1: Write failing domain tests**

Cover:

- entity filter and order-status filter state
- expanded history state
- history entry recency semantics
- normalized query storage rules

- [x] **Step 2: Run the tests to verify RED**

```bash
flutter test test/features/search/domain/search_controls_test.dart
flutter test test/features/search/domain/search_history_entry_test.dart
```

- [x] **Step 3: Implement the minimal domain models**

Add:

- search controls state object
- helper methods for switching entity filter and clearing status filter
- search history entry entity
- any normalization helpers needed for repository usage

- [x] **Step 4: Run the tests to verify GREEN**

Run the same two test files again.

## Chunk 2: Synced Search History Persistence

### Task 2: Add user-scoped search history repository

**Files:**
- Create: `lib/features/search/data/search_history_repository.dart`
- Create: `test/features/search/data/search_history_repository_test.dart`
- External: apply Supabase schema migration for `search_history`

- [x] **Step 1: Write failing repository tests**

Cover:

- fetch recent history for current user
- save executed query
- update recency for an existing query instead of duplicating it
- limit history results for compact view

- [x] **Step 2: Run repository tests to verify RED**

```bash
flutter test test/features/search/data/search_history_repository_test.dart
```

- [x] **Step 3: Implement persistence and schema**

Implement:

- repository methods for listing and saving history
- schema operation for `search_history` with user-scoped rows
- ordering by last-used timestamp
- deduplication by normalized query per user

- [x] **Step 4: Run repository tests to verify GREEN**

Run the repository test file again.

## Chunk 3: Search Providers and Filtering Logic

### Task 3: Extend provider layer for controls, history, and order-status filtering

**Files:**
- Modify: `lib/features/search/domain/search_providers.dart`
- Modify: `lib/features/orders/data/order_repository.dart`
- Modify: `test/features/search/domain/search_results_test.dart`
- Modify: `test/features/orders/data/order_repository_test.dart`

- [x] **Step 1: Write failing provider and repository tests**

Cover:

- history provider returns user-scoped recent queries
- universal search respects entity filter
- order search respects optional status filter
- browse mode still returns grouped results with no query

- [x] **Step 2: Run targeted tests to verify RED**

```bash
flutter test test/features/search/domain/search_results_test.dart
flutter test test/features/orders/data/order_repository_test.dart
```

- [x] **Step 3: Implement provider and repository support**

Add:

- provider-backed search controls state
- history provider and save-query command path
- search orchestration that can slice by entity type
- optional order-status filter support in order search

- [x] **Step 4: Run targeted tests to verify GREEN**

Run the same targeted tests again.

## Chunk 4: Search Screen UX

### Task 4: Add browse-plus-history layout and sticky filter bar

**Files:**
- Modify: `lib/features/search/presentation/universal_search_screen.dart`
- Create: `test/features/search/presentation/universal_search_screen_test.dart`

- [x] **Step 1: Write failing widget tests**

Cover:

- browse mode remains visible on empty query
- history block renders below browse
- history block expands with `Ещё`
- tapping history row runs search
- tapping right arrow inserts query text only
- sticky filter row switches entity slices
- order-status chips appear only in orders slice
- universal no-results state renders for empty search results

- [x] **Step 2: Run widget tests to verify RED**

```bash
flutter test test/features/search/presentation/universal_search_screen_test.dart
```

- [x] **Step 3: Implement presentation updates**

Add:

- compact synced-history block
- `Ещё` expansion behavior
- right-side arrow action for query insertion
- one sticky horizontal filter row
- clean no-results state
- preserve browse-first top section

- [x] **Step 4: Run widget tests to verify GREEN**

Run the search widget test again.

## Chunk 5: Save History on Real Search Execution

### Task 5: Persist only executed queries

**Files:**
- Modify: `lib/features/search/domain/search_providers.dart`
- Modify: `lib/features/search/presentation/universal_search_screen.dart`
- Modify: `test/features/search/presentation/universal_search_screen_test.dart`

- [x] **Step 1: Add failing behavior tests**

Cover:

- typing alone does not save a query
- executed search saves the query
- repeated execution updates recency
- history arrow insertion does not save the query until a real search occurs

- [x] **Step 2: Run targeted tests to verify RED**

```bash
flutter test test/features/search/presentation/universal_search_screen_test.dart
```

- [x] **Step 3: Implement executed-search persistence path**

Ensure:

- save happens on actual query execution only
- search result loading and history persistence do not fight each other
- history list refreshes after successful save

- [x] **Step 4: Run targeted tests to verify GREEN**

Run the same widget test again.

## Chunk 6: Final Verification

### Task 6: Verify search stage 2 end to end

**Files:**
- No code changes unless regressions appear

- [x] **Step 1: Run targeted search tests**

```bash
flutter test test/features/search/domain/search_controls_test.dart
flutter test test/features/search/domain/search_history_entry_test.dart
flutter test test/features/search/data/search_history_repository_test.dart
flutter test test/features/search/presentation/universal_search_screen_test.dart
```

- [x] **Step 2: Run orders/search regression tests**

```bash
flutter test test/features/orders/data/order_repository_test.dart
flutter test test/features/search/domain/search_results_test.dart
```

- [x] **Step 3: Run the full suite**

```bash
flutter test
```

- [x] **Step 4: Manual pass if local app run is available**

Check:

- empty query browse mode
- synced history block
- `Ещё` expansion
- tap-to-run history
- arrow insert behavior
- sticky filters during scroll
- order-status filtering inside orders slice

- [x] **Step 5: Commit**

```bash
git add lib test docs/superpowers/specs/2026-03-11-search-stage-2-design.md docs/superpowers/plans/2026-03-11-search-stage-2.md
git commit -m "feat: plan search stage 2 workspace"
```
