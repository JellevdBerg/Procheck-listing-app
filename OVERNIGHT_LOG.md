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

## Task 4: Rebindable keyboard shortcuts
Status: **done**
Files changed: `lib/models/shortcut_binding.dart` (new),
`lib/providers/settings_provider.dart`, `lib/screens/app_shell.dart`,
`lib/screens/settings_screen.dart`, `test/settings_provider_test.dart` (new)
Notes: New `ShortcutBinding` model (key + `cmdOrCtrl`/`shift`/`alt`) with
per-action overrides persisted in the settings Hive box (same
individual-primitive-keys convention as the rest of `AppSettings`), included
in the backup export/import round-trip. `AppShell`'s `CallbackShortcuts` now
builds its bindings map from `settings.shortcutFor(action)` instead of
hardcoded `SingleActivator`s. Added a 4th Settings card, "Keyboard
shortcuts", listing both actions (there are only two global shortcuts in the
whole app — New project, New task) with a "Change" button opening a small
recorder dialog: hold a modifier and press a key, Escape cancels. Rebinding
validates the new combo against every other action's current binding and
rejects a duplicate with an error snackbar instead of saving it. A rebound
action gets a reset-to-default button.
Assumptions:
- Modeled "Ctrl" and "Cmd" as one unified `cmdOrCtrl` flag rather than two
  separately-bindable modifiers, matching how the app's shortcuts already
  worked (both keys triggered the same action across platforms) — a
  rebind still requires holding *some* Ctrl/Cmd/Alt modifier (rejecting a
  bare unmodified key) so a shortcut can never quietly swallow normal
  typing input.
- Duplicate rejection compares the *effective* binding (override or
  default) of every other action — there's no way to end up with two
  actions bound to the same combo.

---

## Task 5: Add note/file functionality in Templates window
Status: **done**
Files changed: `lib/models/task_template.dart`, `lib/models/task_template.g.dart`,
`lib/providers/task_templates_provider.dart`, `lib/providers/tasks_provider.dart`,
`lib/screens/task_template_editor_screen.dart`, `lib/widgets/task_tile.dart`,
`lib/widgets/attachments_editor.dart` (new), `lib/widgets/notes_field.dart` (new),
`test/task_templates_provider_test.dart` (new)
Notes: Extracted `TaskTile`'s previously-private `_NotesField` and
`_AttachmentsSection`/`_AttachmentChip` into shared, provider-agnostic
`NotesField`/`AttachmentsEditor`/`AttachmentChip` widgets (they take a plain
`List<Attachment>` + `onAdd`/`onRemoveAt` callbacks instead of reaching into
`tasksProvider` directly), so the template editor uses the exact same
UI/file-picker flow instead of a re-implementation. `TaskTemplate` gained
`notes` (String?, HiveField 4) and `attachments` (List<Attachment>, HiveField
5) — ran `build_runner` to regenerate its adapter. The editor screen holds
both as local state (same pattern as its existing `_subtasks` list) until
Save, then passes them to `addTemplate`/`updateTemplate`.
`TasksNotifier.addFromTemplate` now copies `template.notes` and fresh
`Attachment` copies of `template.attachments` onto every task created from
it (a `HiveObject` shouldn't be shared between the template and every task
instantiated from it, so attachments are cloned, not reused by reference).
Added a provider-level test creating a template with a note + attachment,
instantiating a task from it, and asserting both carried over (and that the
attachment is a distinct copy).
Assumptions:
- Notes/attachments in the editor are staged locally and only actually
  persisted on Save, matching how the screen already treats subtasks —
  there's no separate "add attachment to this not-yet-saved template"
  provider call.
- Didn't attempt a visual/E2E capture of the file-picker dialog itself
  (native OS dialog, not capturable headlessly) — see PR notes on manual
  testing still needed.

---

## Task 6: Workspace CRUD via right-click + default "Personal" workspace
Status: **done**
Files changed: `lib/providers/settings_provider.dart`,
`lib/widgets/sidebar/app_sidebar.dart`, `test/settings_provider_test.dart`
Notes: Replaced the hardcoded `const _workspaceNames = ['Personal', 'Acme
Co.', 'Side projects']` demo list with a real, persisted
`AppSettings.workspaceNames` (`List<String>`), defaulting to `['Personal']`
on a fresh install — this is the actual seeding requirement, not just a
starting index into a fixed list. Added `SettingsNotifier.addWorkspace`/
`renameWorkspace`/`removeWorkspace`; `removeWorkspace` refuses to drop the
last remaining name (returns `false` instead of mutating state) so the
sidebar can show an error snackbar rather than silently no-op. Right-
clicking the sidebar's workspace row opens an Add/Edit/Remove context menu
(same `showMenu`-at-tap-point pattern as Task 1's favorites menu); Add/Edit
reuse the existing `showTextPromptDialog`. Left-click still cycles through
the list exactly as before. Workspace names round-trip through backup
export/import.
Assumptions:
- No confirmation dialog on Remove — unlike deleting a project (which
  cascades to delete real tasks/subtasks), a workspace here is still just a
  label with no data of its own to lose (per the design doc, ProCheck has
  no real multi-workspace data model), so it's treated like the low-stakes
  toggle actions (favorite/unfavorite) rather than a destructive one.
- Edit/Remove always act on the *currently displayed* workspace, since the
  switcher shows one name at a time (not a list of rows) — there's nothing
  else to disambiguate a right-click against.

---

## Task 7: Fix add-project/add-task button anchoring on window resize
Status: **done**
Files changed: `lib/screens/projects_screen.dart`, `test/widget_test.dart`
Notes: Confirmed the bug empirically first (measured the "New project" and
"New task" buttons' distance from the window's right edge at 1000px and
1800px window widths via a throwaway widget test before touching any code):
"New task"'s gap stayed constant (26.8 at both widths); "New project"'s grew
from 28.8 to 289.6. Root cause: the toolbar `Row` wrapped the search field in
a `Flexible` (flex:1 by default) *and* had a separate `Spacer` (also
flex:1) — Flutter's Flex layout splits leftover space between same-priority
flexible children, so the Spacer only got half the free width, and the
search field (capped at 360px by its own `ConstrainedBox`) never used the
half handed to it, leaving a growing dead gap and the button drifting
inward as the window widened. `TemplatesScreen`'s "New template" button
already used the correct one-`Expanded` pattern (checked it too — no bug
there). Fixed by replacing the `Flexible` + `Spacer` pair with a single
`Expanded` (containing an `Align` + the same capped-width `ConstrainedBox`),
matching exactly how the working "New task" row anchors its own trailing
button. Added a regression test asserting the gap is unchanged across a
1000px→1800px resize.
Assumptions: none — root cause was fully identified and the fix directly
addresses it (not a workaround).

---

## Task 8: Version bump to v1.2.1
Status: **done**
Files changed: `pubspec.yaml`
Notes: Searched the repo for the current version string (`1.2.0`) and for
any other place a version might be declared (this is a Flutter app, not a
Node project, so there's no `package.json`; checked `web/manifest.json`,
`web/index.html`, and `windows/runner/Runner.rc` too). `pubspec.yaml`'s
`version:` field is the only hardcoded declaration — the app has no
in-app "About" screen or `PackageInfo` usage displaying it anywhere, and
`Runner.rc`'s `FILEVERSION`/`PRODUCTVERSION` pull from
`FLUTTER_VERSION_MAJOR/MINOR/PATCH/BUILD` CMake defines that Flutter's own
build tooling derives from `pubspec.yaml` automatically, so nothing there
needs a manual edit. Bumped `version: 1.2.0+1` → `1.2.1+1`. Verified the
app still builds: reran the Hive codegen step CI uses
(`dart run build_runner build`) and a full `flutter build web --release`,
both succeeded, plus a clean `flutter analyze` and full `flutter test`.
Assumptions: kept the `+1` build number as-is (matching how every prior
version bump in this repo's history has only incremented the semver part
for a same-day release), since nothing in the task said to bump it too.

---
