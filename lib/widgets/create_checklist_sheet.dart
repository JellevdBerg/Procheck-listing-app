import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/checklist.dart';
import '../models/checklist_template.dart';
import '../models/folder.dart';
import '../providers/checklists_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/templates_provider.dart';

Future<Checklist?> showCreateChecklistSheet(
  BuildContext context, {
  String? initialFolderId,
  ChecklistTemplate? initialTemplate,
}) {
  return showModalBottomSheet<Checklist>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CreateChecklistSheet(
      initialFolderId: initialFolderId,
      initialTemplate: initialTemplate,
    ),
  );
}

class _CreateChecklistSheet extends ConsumerStatefulWidget {
  const _CreateChecklistSheet({this.initialFolderId, this.initialTemplate});

  final String? initialFolderId;
  final ChecklistTemplate? initialTemplate;

  @override
  ConsumerState<_CreateChecklistSheet> createState() =>
      _CreateChecklistSheetState();
}

class _CreateChecklistSheetState
    extends ConsumerState<_CreateChecklistSheet> {
  final _nameController = TextEditingController();
  ChecklistTemplate? _selectedTemplate;
  String? _selectedFolderId;
  bool _nameEditedByUser = false;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.initialFolderId;
    _selectedTemplate = widget.initialTemplate;
    if (_selectedTemplate != null) {
      _nameController.text = _selectedTemplate!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(templatesProvider);
    final folders = ref.watch(foldersProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New checklist', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Checklist name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _nameEditedByUser = true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ChecklistTemplate?>(
            initialValue: _selectedTemplate,
            decoration: const InputDecoration(
              labelText: 'Start from',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<ChecklistTemplate?>(
                value: null,
                child: Text('Blank checklist'),
              ),
              ...templates.map(
                (template) => DropdownMenuItem<ChecklistTemplate?>(
                  value: template,
                  child: Text(template.name),
                ),
              ),
            ],
            onChanged: (template) {
              setState(() {
                _selectedTemplate = template;
                if (!_nameEditedByUser) {
                  _nameController.text = template?.name ?? '';
                }
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _selectedFolderId,
            decoration: const InputDecoration(
              labelText: 'Folder',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No folder'),
              ),
              ...folders.map(
                (Folder folder) => DropdownMenuItem<String?>(
                  value: folder.id,
                  child: Text(folder.name),
                ),
              ),
            ],
            onChanged: (folderId) =>
                setState(() => _selectedFolderId = folderId),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _create,
              child: const Text('Create'),
            ),
          ),
        ],
      ),
    );
  }

  void _create() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final notifier = ref.read(checklistsProvider.notifier);
    final Checklist checklist;
    if (_selectedTemplate != null) {
      checklist = notifier.addFromTemplate(
        template: _selectedTemplate!,
        folderId: _selectedFolderId,
        name: name,
      );
    } else {
      checklist = notifier.addBlankChecklist(
        name: name,
        folderId: _selectedFolderId,
      );
    }

    Navigator.of(context).pop(checklist);
  }
}
