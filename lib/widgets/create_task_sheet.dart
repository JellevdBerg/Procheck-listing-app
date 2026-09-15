import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/task_templates_provider.dart';
import '../providers/tasks_provider.dart';
import 'blurred_dialog.dart';

Future<Task?> showCreateTaskSheet(
  BuildContext context, {
  String? initialProjectId,
  TaskTemplate? initialTemplate,
}) {
  return showBlurredDialog<Task>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _CreateTaskSheet(
          initialProjectId: initialProjectId,
          initialTemplate: initialTemplate,
        ),
      ),
    ),
  );
}

class _CreateTaskSheet extends ConsumerStatefulWidget {
  const _CreateTaskSheet({this.initialProjectId, this.initialTemplate});

  final String? initialProjectId;
  final TaskTemplate? initialTemplate;

  @override
  ConsumerState<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<_CreateTaskSheet> {
  final _nameController = TextEditingController();
  TaskTemplate? _selectedTemplate;
  String? _selectedProjectId;
  bool _nameEditedByUser = false;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
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
    final templates = ref.watch(taskTemplatesProvider);
    final projects = ref.watch(projectsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New task', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Task name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _nameEditedByUser = true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TaskTemplate?>(
            initialValue: _selectedTemplate,
            decoration: const InputDecoration(
              labelText: 'Start from',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<TaskTemplate?>(
                value: null,
                child: Text('Blank task'),
              ),
              ...templates.map(
                (template) => DropdownMenuItem<TaskTemplate?>(
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
            initialValue: _selectedProjectId,
            decoration: const InputDecoration(
              labelText: 'Project',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No project'),
              ),
              ...projects.map(
                (Project project) => DropdownMenuItem<String?>(
                  value: project.id,
                  child: Text(project.name),
                ),
              ),
            ],
            onChanged: (projectId) =>
                setState(() => _selectedProjectId = projectId),
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

    final notifier = ref.read(tasksProvider.notifier);
    final defaultPriority = ref.read(settingsProvider).defaultPriority;
    final Task task;
    if (_selectedTemplate != null) {
      task = notifier.addFromTemplate(
        template: _selectedTemplate!,
        projectId: _selectedProjectId,
        title: name,
        priority: defaultPriority,
      );
    } else {
      task = notifier.addBlankTask(
        title: name,
        projectId: _selectedProjectId,
        priority: defaultPriority,
      );
    }

    Navigator.of(context).pop(task);
  }
}
