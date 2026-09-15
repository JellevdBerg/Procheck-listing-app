/// Which top-level destination the [AppShell]'s main content area shows.
/// Project detail is deliberately not one of these — it's an overlay on
/// top of whatever screen was showing, not a destination of its own (see
/// `ProjectDetailOverlay`).
enum AppScreen { projects, today, upcoming, day, templates, archived, settings }
