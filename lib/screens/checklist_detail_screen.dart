import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/checklists_provider.dart';
import '../providers/folders_provider.dart';
import '../widgets/checklist_item_tile.dart';
import '../widgets/text_prompt_dialog.dart';

class ChecklistDetailScreen extends ConsumerStatefulWidget {
  const ChecklistDetailScreen({super.key, required this.checklistId});

  final String checklistId;

  @override
  ConsumerState<ChecklistDetailScreen> createState() =>
      _ChecklistDetailScreenState();
}

class _ChecklistDetailScreenState
    extends ConsumerState<ChecklistDetailScreen> {
  final _newItemController = TextEditingController();

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checklists = ref.watch(checklistsProvider);
    final matches = checklists.where((c) => c.id == widget.checklistId);
    final checklist = matches.isEmpty ? null : matches.first;

    if (checklist == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final notifier = ref.read(checklistsProvider.notifier);
    final folders = ref.watch(foldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(checklist.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  final name = await showTextPromptDialog(
                    context,
                    title: 'Rename checklist',
                    initialValue: checklist.name,
                  );
                  if (name != null) {
                    notifier.renameChecklist(checklist.id, name);
                  }
                  break;
                case 'move':
                  final choice = await _pickFolder(
                    context,
                    folders.map((f) => (f.id, f.name)).toList(),
                    checklist.folderId,
                  );
                  if (choice != null) {
                    notifier.moveToFolder(checklist.id, choice.folderId);
                  }
                  break;
                case 'reset':
                  notifier.resetProgress(checklist.id);
                  break;
                case 'delete':
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Delete checklist?',
                    message: 'This cannot be undone.',
                  );
                  if (confirmed) {
                    notifier.deleteChecklist(checklist.id);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'move', child: Text('Move to folder')),
              PopupMenuItem(value: 'reset', child: Text('Reset progress')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: checklist.items.isEmpty ? 0 : checklist.progress,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${checklist.completedCount}/${checklist.items.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: checklist.items.isEmpty
                ? Center(
                    child: Text(
                      'No items yet. Add one below.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: checklist.items.length,
                    itemBuilder: (context, index) {
                      final item = checklist.items[index];
                      return ChecklistItemTile(
                        key: ValueKey(item.id),
                        checklistId: checklist.id,
                        item: item,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newItemController,
                      decoration: const InputDecoration(
                        hintText: 'Add an item',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addItem(checklist.id, notifier),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addItem(checklist.id, notifier),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addItem(String checklistId, ChecklistsNotifier notifier) {
    final title = _newItemController.text.trim();
    if (title.isEmpty) return;
    notifier.addItem(checklistId, title);
    _newItemController.clear();
  }

  Future<_FolderChoice?> _pickFolder(
    BuildContext context,
    List<(String, String)> folders,
    String? currentFolderId,
  ) {
    return showDialog<_FolderChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Move to folder'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(const _FolderChoice(null)),
            child: Row(
              children: [
                if (currentFolderId == null)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                const Text('No folder'),
              ],
            ),
          ),
          for (final (id, name) in folders)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(_FolderChoice(id)),
              child: Row(
                children: [
                  if (currentFolderId == id)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(name),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Distinguishes "user picked no folder" (`folderId: null`) from
/// "user dismissed the dialog" (the whole choice is `null`).
class _FolderChoice {
  const _FolderChoice(this.folderId);

  final String? folderId;
}
