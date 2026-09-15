import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
