# ProCheck

A fast, cross-platform task manager for people who think in projects, not just to-do lists.

Organize work into projects, see everything that matters on one dashboard, and plan it on a real calendar — all without an account, a server, or your data leaving your device.

![Dashboard](docs/screenshots/dashboard.png)

## Why ProCheck

- **One dashboard, zero digging.** Overdue counts, what's due this week, and a live activity feed — the moment you open the app.
- **A calendar that actually shows your work.** Tasks render as bars across their due dates, drag to create new ones right on the grid, and a chime tells you when something's done.
- **Projects, not just lists.** Color-coded projects with subtasks, priorities, due-date ranges, and templates so you're never rebuilding the same structure twice.
- **Undo, for real.** Every deletion goes onto a real history stack — `Ctrl/Cmd+Z` walks back through more than just the last one.
- **Your data stays yours.** Everything is stored locally on-device. No sign-up, no sync server, no tracking.

![Calendar with Taskmaster](docs/screenshots/calendar.png)

![Project detail](docs/screenshots/project-detail.png)

## Platforms

Android, iOS, web, and Windows/Linux/macOS desktop — one Flutter codebase, built fresh on every push ([Releases](../../releases) has the latest Windows build, no installer needed).

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel).

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # generates Hive model adapters
flutter run                                                # or: flutter run -d chrome / -d windows / -d linux
```
