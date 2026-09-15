import '../models/project.dart';

/// Builds an id→name map for tasks' project-name subtitles in the smart
/// views — a plain lookup avoids `firstWhere(orElse: ...)` needing a
/// fallback [Project] instance when none exists.
Map<String, String> buildProjectNameLookup(List<Project> projects) => {
  for (final p in projects) p.id: p.name,
};

String projectNameFor(Map<String, String> lookup, String? projectId) =>
    projectId == null ? 'Unfiled' : (lookup[projectId] ?? 'Unfiled');
