# Shell Aurora Background Design

**Date:** 2026-03-12

## Goal

Replace the plain AMOLED black background on the 4 main shell tabs with a richer purple-blue aurora/liquid-glass background inspired by the provided reference image, without changing auth/admin/form flows.

## Scope

- Apply only to the main shell tabs: Orders, Search, Customers, Profile.
- Keep modal sheets, dialogs, auth screens, and admin CRUD forms on the existing dark background.
- Preserve readability of glass cards, navbar, FABs, and text.

## Design

- Introduce a single reusable `DeskflowAuroraBackground` widget in `core/widgets`.
- Render it once in `MainShellScreen` behind `StatefulNavigationShell` using a full-screen `Stack`.
- Build the look procedurally instead of shipping the reference image as an asset:
  - AMOLED-black base gradient
  - bright top halo
  - two blurred liquid ribbons in violet/blue tones
  - a soft lower glow and small lens-flare accents
- Make the 4 shell screens use transparent `Scaffold` backgrounds so the shared shell background is visible.

## Safety

- Decorative background must be `IgnorePointer` and non-interactive.
- Painter must use `shouldRepaint => false`.
- Content contrast stays anchored to the existing `DeskflowColors` glass/text palette.

## Verification

- `flutter analyze` on the new widget, shell, and the 4 shell screens.
- Widget test for `DeskflowAuroraBackground`.
- Existing Orders/Search/Profile tests still compile and pass.
