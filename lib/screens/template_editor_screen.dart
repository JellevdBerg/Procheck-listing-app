import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/checklist_template.dart';
import '../models/template_item.dart';
import '../providers/templates_provider.dart';
import '../widgets/text_prompt_dialog.dart';

class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, this.templateId});

  /// Null when creating a brand new template.
  final String? templateId;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late final TextEditingController _nameController;
  final _newItemController = TextEditingController();
  late List<TemplateItem> _items;

  @override
  void initState() {
    super.initState();
    final template = _findTemplate();
    _nameController = TextEditingController(text: template?.name ?? '');
    _items = template == null
        ? []
        : template.items
              .map((item) => TemplateItem(id: item.id, title: item.title))
              .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newItemController.dispose();
    super.dispose();
  }

  ChecklistTemplate? _findTemplate() {
    if (widget.templateId == null) return null;
    final templates = ref.read(templatesProvider);
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
                  message:
                      'Existing checklists created from it are unaffected.',
                );
                if (confirmed) {
                  ref
                      .read(templatesProvider.notifier)
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
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Template name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Items', style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      'No items yet. Add one below.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _items.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        key: ValueKey(item.id),
                        leading: const Icon(Icons.drag_handle),
                        title: Text(item.title),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _items.removeAt(index)),
                        ),
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
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: _addItem,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    final title = _newItemController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _items.add(TemplateItem(id: const Uuid().v4(), title: title));
      _newItemController.clear();
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final notifier = ref.read(templatesProvider.notifier);
    if (widget.templateId == null) {
      notifier.addTemplate(name, _items.map((i) => i.title).toList());
    } else {
      notifier.updateTemplate(widget.templateId!, name, _items);
    }
    Navigator.of(context).pop();
  }
}
