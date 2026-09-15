import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/nocturne/nocturne_widgets.dart';
import 'empty_state.dart';

/// Archived projects: a color dot, name + task count, and an "Unarchive"
/// ghost button. Search filters by name, same as the Projects screen.
class ArchivedScreen extends ConsumerStatefulWidget {
  const ArchivedScreen({super.key, required this.onOpenProject});

  final void Function(String projectId, BuildContext rowContext) onOpenProject;

  @override
  ConsumerState<ArchivedScreen> createState() => _ArchivedScreenState();
}

class _ArchivedScreenState extends ConsumerState<ArchivedScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final archived = ref.watch(projectsProvider).where((p) => p.archived).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (archived.isEmpty) {
      return const EmptyState(
        icon: Icons.archive_outlined,
        message: 'No archived projects.\nArchive a project to see it here.',
      );
    }

    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? archived
        : archived.where((p) => p.name.toLowerCase().contains(query)).toList();

    return Padding(
      padding: const EdgeInsets.all(16.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Archived', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16.8),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(hintText: 'Search archived projects'),
          ),
          const SizedBox(height: 16.8),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No archived projects match "${_query.trim()}".',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 11.2),
                  itemCount: visible.length,
                  itemBuilder: (context, index) =>
                      _ArchivedRow(project: visible[index], taskCount: tasks
                          .where((t) => t.projectId == visible[index].id)
                          .length, onOpenProject: widget.onOpenProject),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchivedRow extends ConsumerWidget {
  const _ArchivedRow({
    required this.project,
    required this.taskCount,
    required this.onOpenProject,
  });

  final Project project;
  final int taskCount;
  final void Function(String projectId, BuildContext rowContext) onOpenProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = accentPalette[project.colorIndex];
    return Builder(
      builder: (rowContext) => InkWell(
        onTap: () => onOpenProject(project.id, rowContext),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: project.name,
                    style: const TextStyle(fontSize: 14),
                    children: [
                      TextSpan(
                        text: ' ($taskCount task${taskCount == 1 ? '' : 's'})',
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              NocturneButton(
                label: 'Unarchive',
                icon: Icons.restore,
                variant: NocturneButtonVariant.ghost,
                onPressed: () =>
                    ref.read(projectsProvider.notifier).unarchiveProject(project.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
