# Shell Image Background And Orders Filter Sheets Design

**Date:** 2026-03-12

## Goal

Keep the user PNG as the shell background, but rebuild Orders filter interactions around bottom sheets that rise from the bottom like the order actions/status sheets. At the same time, increase darkening on transparent shell surfaces so text remains readable over the bright image, and remove the visual seam/black split on the Orders screen.

## Scope

- Keep the image background for the 4 shell tabs: Orders, Search, Customers, Profile.
- Do not restore the old procedural aurora background.
- Replace the inline expanding Orders filter panel with true modal bottom sheets.
- Strengthen shell glass contrast for search/filter surfaces against the bright PNG.
- Preserve the advanced date and amount controls already requested.

## Orders Interaction Model

### Top row

- Status chips remain at the top and continue to own status filtering.
- Compact glass triggers remain below the status chips:
  - `Сортировка`
  - `Период`
- Tapping either trigger opens a bottom sheet from the bottom edge.
- Nothing expands inline inside the scroll content.

### Period sheet

- Reuses the same visual language as `StatusChangeSheet`:
  - drag handle
  - dark sheet surface
  - rounded top corners
  - padded option list
- Options:
  - `Сегодня`
  - `7 дней`
  - `30 дней`
  - `Все время`
- Selecting a period clears exact date and date range.

### Sort sheet

- Opens as a real bottom sheet, not an inline card.
- Top area contains a compact mode switch:
  - `По дате`
  - `По сумме`
- If mode is `По дате`, the sheet shows the advanced calendar.
- If mode is `По сумме`, the sheet shows the range slider panel.

### Advanced calendar

- Default mode is single-date selection.
- A compact icon-only toggle switches to range mode.
- Header contains:
  - month navigation
  - tappable year affordance
  - keyboard-entry affordance for direct date input
- Range mode supports selecting `от` and `до`.
- Choosing exact date(s) clears `Период`.

### Amount mode

- Keeps the dual-ended slider.
- Lives inside the sort bottom sheet.
- Range summary remains visible in the trigger label.

### Status

- `По статусу` is not shown in the bottom sheet.
- Status remains only in the top chips to avoid duplicate controls.

## Visual System Changes

### Sheet behavior

- Sheets should visually match the existing order action / status sheets more than the generic inline glass card.
- Use a darker, more opaque surface so the background image does not fight with the content.
- Preserve the glass identity with border/highlight, but lean on readability first.

### Shell contrast

- Search bar, compact filter triggers, and top glass surfaces need stronger dark tint.
- The bright background image stays visible, but text should no longer wash out.
- Do not add blur to the background image itself.

### Orders background continuity

- Orders should no longer render a large inline panel that visually slices the image.
- The screen should read as one continuous background behind the scrolled content.
- Any local surface blocks must be intentional cards/sheets, not full-width dark bands.

## Data Rules

- `periodPreset`, `selectedDate`, and `selectedDateRange` remain mutually exclusive.
- Date range stays inclusive in UI and converts to `[startOfDay, nextDayAfterEnd)` for repository queries.
- Amount filtering remains independent from date/period filtering.

## Verification

- Update Orders widget tests from inline panel expectations to bottom-sheet expectations.
- Add regression coverage that:
  - `Сортировка` opens a modal sheet
  - `Период` opens a modal sheet
  - compact-height layouts do not overflow in `По сумме`
- Run `flutter analyze` on theme, shell background, and Orders files.
- Run focused Orders widget/domain/data tests.
