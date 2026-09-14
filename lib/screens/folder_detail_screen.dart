import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/checklists_provider.dart';
import '../providers/folders_provider.dart';
import '../widgets/checklist_tile.dart';
import '../widgets/create_checklist_sheet.dart';
import '../widgets/text_prompt_dialog.dart';
import 'checklist_detail_screen.dart';

class FolderDetailScreen extends ConsumerWidget {
  const FolderDetailScreen({super.key, required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider);
    final matches = folders.where((f) => f.id == folderId);
    final folder = matches.isEmpty ? null : matches.first;

    if (folder == null) {
      // The folder was deleted (e.g. from another view); pop back.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final checklists = ref
        .watch(checklistsProvider)
        .where((c) => c.folderId == folderId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename folder',
            onPressed: () async {
              final name = await showTextPromptDialog(
                context,
                title: 'Rename folder',
                initialValue: folder.name,
              );
              if (name != null) {
                ref.read(foldersProvider.notifier).renameFolder(
                  folderId,
                  name,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete folder',
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Delete folder?',
                message:
                    'Checklists inside "${folder.name}" will move to Unfiled. This cannot be undone.',
              );
              if (confirmed) {
                ref.read(foldersProvider.notifier).deleteFolder(folderId);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: checklists.isEmpty
          ? Center(
              child: Text(
                'No checklists in this folder yet.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView(
              children: [
                for (final checklist in checklists)
                  ChecklistTile(
                    checklist: checklist,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ChecklistDetailScreen(checklistId: checklist.id),
                      ),
                    ),
                    onDelete: () => ref
                        .read(checklistsProvider.notifier)
                        .deleteChecklist(checklist.id),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showCreateChecklistSheet(context, initialFolderId: folderId),
        child: const Icon(Icons.add),
      ),
    );
  }
}
