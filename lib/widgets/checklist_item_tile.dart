import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/checklist_item.dart';
import '../providers/checklists_provider.dart';

/// A single checklist item: a checkbox + title row that expands to reveal
/// a notes field and a list of subtasks. Checking every subtask
/// automatically checks the parent item, and vice versa.
class ChecklistItemTile extends ConsumerStatefulWidget {
  const ChecklistItemTile({
    super.key,
    required this.checklistId,
    required this.item,
  });

  final String checklistId;
  final ChecklistItem item;

  @override
  ConsumerState<ChecklistItemTile> createState() => _ChecklistItemTileState();
}

class _ChecklistItemTileState extends ConsumerState<ChecklistItemTile> {
  bool _expanded = false;
  late final TextEditingController _notesController;
  late final FocusNode _notesFocusNode;
  final _newSubtaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes ?? '');
    _notesFocusNode = FocusNode()..addListener(_onNotesFocusChange);
  }

  @override
  void didUpdateWidget(covariant ChecklistItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in sync with external changes (e.g. undo elsewhere)
    // without clobbering text the user is actively editing.
    if (!_notesFocusNode.hasFocus && widget.item.notes != oldWidget.item.notes) {
      _notesController.text = widget.item.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesFocusNode.removeListener(_onNotesFocusChange);
    _notesFocusNode.dispose();
    _notesController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  void _onNotesFocusChange() {
    if (!_notesFocusNode.hasFocus) _saveNotes();
  }

  void _saveNotes() {
    final text = _notesController.text.trim();
    ref
        .read(checklistsProvider.notifier)
        .setItemNotes(widget.checklistId, widget.item.id, text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final notifier = ref.read(checklistsProvider.notifier);
    final theme = Theme.of(context);

    final subtitleParts = <String>[
      if ((item.notes ?? '').trim().isNotEmpty) item.notes!.trim(),
      if (item.hasSubtasks)
        '${item.completedSubtaskCount}/${item.subtasks.length} subtasks',
    ];

    return Column(
      children: [
        ListTile(
          onTap: () => setState(() => _expanded = !_expanded),
          leading: Checkbox(
            value: item.isChecked,
            onChanged: (_) => notifier.toggleItem(widget.checklistId, item.id),
          ),
          title: Text(
            item.title,
            style: item.isChecked
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: subtitleParts.isEmpty
              ? null
              : Text(
                  subtitleParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete item',
                onPressed: () =>
                    notifier.removeItem(widget.checklistId, item.id),
              ),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _notesController,
                  focusNode: _notesFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                if (item.subtasks.isNotEmpty) ...[
                  Text('Subtasks', style: theme.textTheme.labelLarge),
                  for (final subtask in item.subtasks)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: subtask.isChecked,
                      title: Text(
                        subtask.title,
                        style: subtask.isChecked
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      onChanged: (_) =>
                          notifier.toggleItem(widget.checklistId, subtask.id),
                      secondary: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Remove subtask',
                        onPressed: () => notifier.removeSubtask(
                          widget.checklistId,
                          subtask.id,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubtaskController,
                        decoration: const InputDecoration(
                          hintText: 'Add a subtask',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addSubtask(notifier),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _addSubtask(notifier),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  void _addSubtask(ChecklistsNotifier notifier) {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;
    notifier.addSubtask(widget.checklistId, widget.item.id, title);
    _newSubtaskController.clear();
  }
}
