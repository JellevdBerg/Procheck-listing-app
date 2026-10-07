import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../providers/projects_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/nocturne/nocturne_widgets.dart';
import 'dashboard_screen.dart' show ProjectsTableCard, computeProjectSummaries;
import 'empty_state.dart';

/// Archived projects: how many there are, a search box, and the same
/// Projects table the Dashboard uses (scoped to archived projects), with an
/// "Unarchive" action on each row in place of the usual tap-to-open.
class ArchivedScreen extends ConsumerStatefulWidget {
  const ArchivedScreen({super.key, required this.onOpenProject, required this.onOpenTask});

  final void Function(String projectId, BuildContext rowContext) onOpenProject;

  /// Unused now that the table's own row tap is repurposed for Unarchive,
  /// but kept so callers don't need to change how they construct this screen.
  final void Function(String? projectId, String taskId, BuildContext rowContext)
  onOpenTask;

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
    final archived = ref.watch(projectsProvider).where((p) => p.archived).toList();

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

    final summaries = computeProjectSummaries(
      visible,
      _archivedProjectTasks(tasks, visible),
      DateTime.now(),
    );

    return Padding(
      padding: const EdgeInsets.all(16.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Archived', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: 10),
              Text(
                '${archived.length} project${archived.length == 1 ? '' : 's'}',
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16.8),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(hintText: 'Search archived projects'),
          ),
          const SizedBox(height: 16.8),
          if (summaries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No archived projects match "${_query.trim()}".',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ProjectsTableCard(
              summaries: summaries,
              emptyMessage: 'No archived projects yet.',
              onOpenProject: widget.onOpenProject,
              trailing: (summary) => NocturneButton(
                label: 'Unarchive',
                icon: Icons.restore,
                variant: NocturneButtonVariant.ghost,
                onPressed: () => ref
                    .read(projectsProvider.notifier)
                    .unarchiveProject(summary.project.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tasks belonging to any of [archived]'s projects — unfiled tasks aren't
/// "archived" in any sense, so (unlike the Dashboard's own overview, which
/// includes them) they're left out of this scope entirely.
List<Task> _archivedProjectTasks(List<Task> tasks, List<Project> archived) {
  final archivedIds = archived.map((p) => p.id).toSet();
  return tasks.where((t) => archivedIds.contains(t.projectId)).toList();
}
