# Procheck

Procheck is a lightweight cross-platform checklist app built with Flutter. Make template checklists, organize checklists into folders, and track how far along each one is at a glance.

## Features

- **Checklists** — create a checklist, check items off, and see live progress (e.g. `3/5`).
- **Folders** — group related checklists together (e.g. "Onboarding", "Weekly routine").
- **Templates** — define a reusable set of items once, then spin up new checklists from it whenever you need that same list again.
- Works on Android, iOS, web, and Linux desktop from a single codebase. Data is stored locally on-device (via [Hive](https://pub.dev/packages/hive)), no account or server required.

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel).

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # generates Hive model adapters
flutter run                                                # or: flutter run -d chrome / -d linux
```

Run the tests with:

```sh
flutter analyze
flutter test
```

## Project structure

```
lib/
  models/      Hive data models (Folder, Checklist, ChecklistTemplate, ...)
  data/        Hive setup/initialization
  providers/   Riverpod state notifiers (persist to Hive in the background)
  screens/     Home, folder detail, checklist detail, template editor
  widgets/     Shared UI pieces (checklist tile, create-checklist sheet, dialogs)
```

State management uses [Riverpod](https://riverpod.dev/); local persistence uses [Hive](https://pub.dev/packages/hive). Notifier methods update in-memory state synchronously and persist to disk in the background, so the UI never blocks on I/O.
