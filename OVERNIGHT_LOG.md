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

## Task 3: Fix layout shift from triple-dot hover button
Status: **done**
Files changed: `lib/widgets/project_card.dart`, `test/widget_test.dart`
Notes: Root cause: the actions `IconButton` was only added to the
header/compact `Row` conditionally on hover, and its default 48x48 Material
tap target is taller than the row's other content, so the row's height grew
whenever it appeared, pushing the divider/task-preview list below it down.
Fixed by always mounting the button and controlling only its visibility via
`Visibility(maintainSize: true, maintainAnimation: true, maintainState: true)`
so its layout footprint is reserved at all times — no reflow on hover.
Updated the one widget test that asserted the icon was absent pre-hover
(`findsNothing`) to instead check the `Visibility.visible` flag, since the
button is now always in the tree.
Assumptions: scoped to `ProjectCard` (the "project pane" named in the spec).
`TemplatesScreen`'s row-hover menu uses the same show/hide-on-hover pattern
and likely has the same latent issue, but the spec named the project pane
specifically, so left untouched per "don't refactor unrelated code."

---
