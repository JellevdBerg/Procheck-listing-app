import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/task_template.dart';
import '../models/template_subtask.dart';
import '../providers/task_templates_provider.dart';
import '../widgets/text_prompt_dialog.dart';

class TaskTemplateEditorScreen extends ConsumerStatefulWidget {
  const TaskTemplateEditorScreen({super.key, this.templateId});

  /// Null when creating a brand new template.
  final String? templateId;

  @override
  ConsumerState<TaskTemplateEditorScreen> createState() =>
      _TaskTemplateEditorScreenState();
}

class _TaskTemplateEditorScreenState
    extends ConsumerState<TaskTemplateEditorScreen> {
  late final TextEditingController _nameController;
  final _newSubtaskController = TextEditingController();
  late List<TemplateSubtask> _subtasks;

  @override
  void initState() {
    super.initState();
    final template = _findTemplate();
    _nameController = TextEditingController(text: template?.name ?? '');
    _subtasks = template == null
        ? []
        : template.subtasks
              .map((s) => TemplateSubtask(id: s.id, title: s.title))
              .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  TaskTemplate? _findTemplate() {
    if (widget.templateId == null) return null;
    final templates = ref.read(taskTemplatesProvider);
    final matches = templates.where((t) => t.id == widget.templateId);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.templateId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit template' : 'New template'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete template',
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete template?',
                  message: 'Existing tasks created from it are unaffected.',
                );
                if (confirmed) {
                  ref
                      .read(taskTemplatesProvider.notifier)
                      .deleteTemplate(widget.templateId!);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Main task name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSubtaskController,
                    decoration: const InputDecoration(
                      hintText: 'Add a subtask',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: _addSubtask,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Subtasks',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: _subtasks.isEmpty
                ? Center(
                    child: Text(
                      'No subtasks yet. Add one above.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _subtasks.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final subtask = _subtasks.removeAt(oldIndex);
                        _subtasks.insert(newIndex, subtask);
                      });
                    },
                    itemBuilder: (context, index) {
                      final subtask = _subtasks[index];
                      return ListTile(
                        key: ValueKey(subtask.id),
                        leading: const Icon(Icons.drag_handle),
                        title: Text(subtask.title),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _subtasks.removeAt(index)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addSubtask() {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _subtasks.add(TemplateSubtask(id: const Uuid().v4(), title: title));
      _newSubtaskController.clear();
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final notifier = ref.read(taskTemplatesProvider.notifier);
    if (widget.templateId == null) {
      notifier.addTemplate(name, _subtasks.map((s) => s.title).toList());
    } else {
      notifier.updateTemplate(widget.templateId!, name, _subtasks);
    }
    Navigator.of(context).pop();
  }
}
