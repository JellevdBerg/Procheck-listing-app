import '../models/project.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../providers/settings_provider.dart';

/// The current on-disk shape of a backup file. Bump this if the shape of
/// [buildBackupJson]/[parseBackupJson] ever changes incompatibly, and branch
/// on it in [parseBackupJson] so older backups still import correctly.
const backupSchemaVersion = 1;

/// Thrown by [parseBackupJson] when the given JSON isn't a recognizable
/// ProCheck backup (wrong shape, or a schema version this build doesn't
/// know how to read).
class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Everything [parseBackupJson] extracts from a backup file, ready to hand
/// to each provider's `restoreAll`.
class BackupData {
  const BackupData({
    required this.projects,
    required this.tasks,
    required this.taskTemplates,
    required this.settings,
  });

  final List<Project> projects;
  final List<Task> tasks;
  final List<TaskTemplate> taskTemplates;
  final AppSettings settings;
}

/// Builds the full-store JSON document written out by Settings > Export
/// backup.
Map<String, dynamic> buildBackupJson({
  required List<Project> projects,
  required List<Task> tasks,
  required List<TaskTemplate> taskTemplates,
  required AppSettings settings,
}) {
  return {
    'schemaVersion': backupSchemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'projects': projects.map((p) => p.toJson()).toList(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'taskTemplates': taskTemplates.map((t) => t.toJson()).toList(),
    'settings': settings.toJson(),
  };
}

/// Parses a backup document produced by [buildBackupJson] (or an older
/// build's version of it). Throws [BackupFormatException] if [json] isn't a
/// recognizable backup.
BackupData parseBackupJson(Map<String, dynamic> json) {
  final schemaVersion = json['schemaVersion'];
  if (schemaVersion is! int) {
    throw BackupFormatException("This file isn't a valid ProCheck backup.");
  }
  if (schemaVersion > backupSchemaVersion) {
    throw BackupFormatException(
      "This backup was made by a newer version of ProCheck and can't be "
      'read here.',
    );
  }

  try {
    final projects = (json['projects'] as List<dynamic>? ?? [])
        .map((p) => Project.fromJson(p as Map<String, dynamic>))
        .toList();
    final tasks = (json['tasks'] as List<dynamic>? ?? [])
        .map((t) => Task.fromJson(t as Map<String, dynamic>))
        .toList();
    final taskTemplates = (json['taskTemplates'] as List<dynamic>? ?? [])
        .map((t) => TaskTemplate.fromJson(t as Map<String, dynamic>))
        .toList();
    final settingsJson = json['settings'] as Map<String, dynamic>? ?? {};
    final settings = AppSettings.fromJson(settingsJson);

    return BackupData(
      projects: projects,
      tasks: tasks,
      taskTemplates: taskTemplates,
      settings: settings,
    );
  } on BackupFormatException {
    rethrow;
  } catch (e) {
    throw BackupFormatException('This file isn\'t a valid ProCheck backup.');
  }
}

/// A short, sortable default filename for a fresh export, e.g.
/// `procheck-backup-2026-09-15-143210.json`.
String suggestedBackupFileName([DateTime? now]) {
  final t = now ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${t.year}-${two(t.month)}-${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  return 'procheck-backup-$stamp.json';
}
