# Procheck

Procheck is a lightweight cross-platform task app built with Flutter. Organize tasks into projects, break a task into subtasks, and reuse task templates whenever you need that same structure again.

## Features

- **Projects** — group related tasks together (e.g. "Onboarding", "Weekly routine"). The first 4 projects show as tall featured cards previewing up to 4 of their tasks; any more show as compact chips below. Hover a project (or a task) to reveal a delete button.
- **Tasks & subtasks** — a task can carry notes and a list of subtasks. Checking off every subtask automatically checks the task, and toggling the task cascades to all its subtasks. Tap a task to expand it in place — subtasks appear below it, notes in a panel beside them.
- **Templates** — define a main task and its subtasks once as a template, then spin up new tasks from it whenever you need that same structure again.
- **Settings** — theme (system/light/dark), a curated accent color palette, and a "reduce motion" toggle for the app's animations.
- Works on Android, iOS, web, and Windows/Linux desktop from a single codebase. Data is stored locally on-device (via [Hive](https://pub.dev/packages/hive)), no account or server required.

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
  screens/     Home, project detail, task template editor, settings
  widgets/     Shared UI pieces (project card, task tile, create-task sheet, page transitions)
```

State management uses [Riverpod](https://riverpod.dev/); local persistence uses [Hive](https://pub.dev/packages/hive). Notifier methods update in-memory state synchronously and persist to disk in the background, so the UI never blocks on I/O.

Opening a project slides its task list in from the right while the home screen fades away behind it; the tapped project card morphs into the project's header bar via a `Hero` animation. Tasks then expand in place within that list — no further navigation — pushing the tasks below them down to make room for the subtasks/notes view.

## Windows builds

Every push builds a Windows release via GitHub Actions (`.github/workflows/windows-build.yml`) and publishes it as a versioned GitHub Release (e.g. `ProCheck v1.0.2`, tagged `v1.0.2-build.<run-number>` for uniqueness). Grab the latest `.zip` from the repo's [Releases page](../../releases), unzip it, and run `procheck.exe` — no installer needed.
