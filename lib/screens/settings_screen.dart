import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup_service.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_templates_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/text_prompt_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) => notifier.setThemeMode(mode!),
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('Match system'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Light'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Dark'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionLabel('Accent color'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < accentPalette.length; i++)
                  _ColorSwatch(
                    color: accentPalette[i],
                    selected: settings.accentIndex == i,
                    onTap: () => notifier.setAccentIndex(i),
                  ),
              ],
            ),
          ),
          const Divider(),
          const _SectionLabel('Motion'),
          SwitchListTile(
            title: const Text('Reduce motion'),
            subtitle: const Text(
              'Use quick fades instead of sliding/scaling animations',
            ),
            value: settings.reduceMotion,
            onChanged: notifier.setReduceMotion,
          ),
          const Divider(),
          const _SectionLabel('Backup & restore'),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Export backup'),
            subtitle: const Text(
              'Saves every project, task, and template to a JSON file',
            ),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Import backup'),
            subtitle: const Text(
              'Replaces everything currently in ProCheck with a backup file',
            ),
            onTap: () => _importBackup(context, ref),
          ),
          const Divider(),
          const _SectionLabel('Danger zone'),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Wipe all data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text(
              'Permanently deletes every project, task, and template',
            ),
            onTap: () => _confirmWipe(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final json = buildBackupJson(
      projects: ref.read(projectsProvider),
      tasks: ref.read(tasksProvider),
      taskTemplates: ref.read(taskTemplatesProvider),
      settings: ref.read(settingsProvider),
    );
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
    );
    final fileName = suggestedBackupFileName();

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export ProCheck backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      // Only actually used by file_picker on web (it triggers the browser
      // download); desktop/mobile just returns a path and the bytes below
      // are written by hand instead.
      bytes: bytes,
    );
    if (savedPath == null) return; // user cancelled

    if (!kIsWeb) {
      await File(savedPath).writeAsBytes(bytes);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb ? 'Backup downloaded.' : 'Backup saved to $savedPath',
          ),
        ),
      );
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import ProCheck backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      if (context.mounted) {
        _showImportError(context, "Couldn't read that file.");
      }
      return;
    }

    final BackupData data;
    try {
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      data = parseBackupJson(decoded);
    } catch (e) {
      if (context.mounted) {
        _showImportError(
          context,
          e is BackupFormatException
              ? e.message
              : "This file isn't a valid ProCheck backup.",
        );
      }
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Import backup?',
      message:
          'This replaces everything currently in ProCheck with the backup: '
          '${data.projects.length} project(s), ${data.tasks.length} task(s), '
          'and ${data.taskTemplates.length} template(s). This cannot be undone.',
      confirmLabel: 'Import',
    );
    if (!confirmed) return;

    ref.read(projectsProvider.notifier).restoreAll(data.projects);
    ref.read(tasksProvider.notifier).restoreAll(data.tasks);
    ref.read(taskTemplatesProvider.notifier).restoreAll(data.taskTemplates);
    ref.read(settingsProvider.notifier).restoreAll(data.settings);

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Backup imported.')));
    }
  }

  void _showImportError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Wipe all data?',
      message:
          'This permanently deletes every project, task, subtask, and '
          'template, and resets settings to their defaults. This cannot '
          'be undone.',
      confirmLabel: 'Wipe everything',
    );
    if (!confirmed) return;

    ref.read(projectsProvider.notifier).clearAll();
    ref.read(tasksProvider.notifier).clearAll();
    ref.read(taskTemplatesProvider.notifier).clearAll();
    ref.read(settingsProvider.notifier).resetToDefaults();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All ProCheck data has been wiped.')),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
