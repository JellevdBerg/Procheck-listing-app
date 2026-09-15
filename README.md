# ProCheck

ProCheck is a lightweight cross-platform task app built with Flutter. Organize tasks into projects, break a task into subtasks, and reuse task templates whenever you need that same structure again.

## Features

- **Projects** — group related tasks together (e.g. "Onboarding", "Weekly routine"), each with its own accent color and a search field to find one quickly. Projects sort by most-recently-opened and lay out as a centered, responsive grid: a single project sits centered rather than stretching edge-to-edge, and more projects fill in left-to-right before wrapping to a new row; extra projects beyond that show as compact chips below. Deleting a project deletes its tasks (and their subtasks) with it. Hover a project (or a task) to reveal a delete button.
- **Tasks & subtasks** — a task can carry notes and a list of subtasks. Checking either off plays a quick "wobble" animation, and checking off every subtask automatically checks the task (toggling the task cascades back down to all its subtasks). Tap a task to expand it in place — subtasks appear below it, notes in a panel beside them. A task with no project is a quick one-off: checking it off removes it instead of leaving it around.
- **Templates** — define a main task and its subtasks once as a template, then spin up new tasks from it whenever you need that same structure again.
- **Settings** — theme (system/light/dark), a curated accent color palette, a "reduce motion" toggle for the app's animations, and a "Wipe all data" option that resets the app to a clean first-run state.
- A brief splash screen greets you with the logo on launch; the "add project/task" flow opens as a centered, blurred-backdrop dialog rather than a bottom sheet.
- Works on Android, iOS, web, and Windows/Linux desktop from a single codebase. Data is stored locally on-device (via [Hive](https://pub.dev/packages/hive)), no account or server required. On Windows, data lives under `%LocalAppData%\ProCheck` (older installs that had data in Documents are migrated automatically on first launch).

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel).

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # generates Hive model adapters
flutter run                                                # or: flutter run -d chrome / -d windows / -d linux
```

Run the tests with:

```sh
flutter analyze
flutter test
```

## Project structure

```
lib/
  models/      Hive data models (Project, Task, Subtask, TaskTemplate, TemplateSubtask)
  data/        Hive setup/initialization
  providers/   Riverpod state notifiers (persist to Hive in the background)
  screens/     Splash, home, project detail, task template editor, settings
  widgets/     Shared UI pieces (app logo, project card, task tile, create-task sheet, page transitions)
```

State management uses [Riverpod](https://riverpod.dev/); local persistence uses [Hive](https://pub.dev/packages/hive). Notifier methods update in-memory state synchronously and persist to disk in the background, so the UI never blocks on I/O.

Opening a project slides its task list in from the right while the home screen fades away behind it; the tapped project card morphs into the project's header bar via a `Hero` animation. Tasks then expand in place within that list — no further navigation — pushing the tasks below them down to make room for the subtasks/notes view.

## Windows builds

Every push builds a Windows release via GitHub Actions (`.github/workflows/windows-build.yml`) and publishes it as a versioned GitHub Release (e.g. `ProCheck v1.0.5`, tagged `v1.0.5-build.<run-number>` for uniqueness). Grab the latest `.zip` from the repo's [Releases page](../../releases), unzip it, and run `procheck.exe` — no installer needed.
