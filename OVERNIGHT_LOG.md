# Overnight task log

Branch: `claude/overnight-fixes` (off `main` @ `fa2b3ea`)
Started: 2026-09-15

Working through the 8-item overnight task list. Each task is committed
separately. Entries appended below as each task finishes.

---

## Task 1: Unfavorite via right-click
Status: **done**
Files changed: `lib/widgets/sidebar/app_sidebar.dart`
Notes: Added `onSecondaryTapDown` to `_NavRow` (wrapped in a `GestureDetector`)
and wired it on Favorites rows to a `showMenu` context menu (same manual
`showMenu`-positioned-by-tap-point pattern used elsewhere), with a single
"Unfavorite" item that calls the existing `projectsProvider.toggleFavorite`.
No confirmation dialog, per spec. Riverpod rebuild removes the row from the
list immediately — no reload needed.
Assumptions: "right-click" = Flutter's `onSecondaryTapDown` (desktop mouse
right-click / trackpad secondary click), which is what this native app target
actually receives — there's no separate touch/right-click ambiguity here.

---

## Task 2: Remove wiggle from task shrink animation
Status: **done**
Files changed: `lib/widgets/pop_out_removal.dart`
Notes: `PopOutRemoval` (the shared shrink-and-pop-out animation used for both
task and project-card removal) layered a `_wiggle` rotation on top of the
scale/size-factor collapse. Removed the `_wiggle` Animation and its
`Transform.rotate` wrapper entirely; the scale-down, size collapse
(via `Align`'s width/heightFactor) and fade are untouched.
Assumptions: none — this is the only rotation/wiggle animation on the
removal path (`WobbleCheckbox`'s wobble is a separate check/uncheck
feedback animation, not the shrink animation, so left alone).

---
