import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../data/hive_setup.dart';
import '../models/checklist_template.dart';
import '../models/template_item.dart';

final templatesProvider =
    StateNotifierProvider<TemplatesNotifier, List<ChecklistTemplate>>((ref) {
      return TemplatesNotifier();
    });

/// Persistence to Hive is fire-and-forget: [state] is the source of truth
/// for the UI and is updated synchronously, while the on-disk copy catches
/// up in the background.
class TemplatesNotifier extends StateNotifier<List<ChecklistTemplate>> {
  TemplatesNotifier() : super(_box.values.toList()) {
    _sortState();
  }

  static Box<ChecklistTemplate> get _box =>
      Hive.box<ChecklistTemplate>(templateBoxName);

  void _sortState() {
    final sorted = [...state]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = sorted;
  }

  ChecklistTemplate addTemplate(String name, List<String> itemTitles) {
    final template = ChecklistTemplate(
      id: const Uuid().v4(),
      name: name,
      items: itemTitles
          .map((title) => TemplateItem(id: const Uuid().v4(), title: title))
          .toList(),
      createdAt: DateTime.now(),
    );
    unawaited(_box.put(template.id, template));
    state = [...state, template];
    _sortState();
    return template;
  }

  void updateTemplate(String id, String name, List<TemplateItem> items) {
    final template = _box.get(id);
    if (template == null) return;
    template.name = name;
    template.items = items;
    unawaited(template.save());
    state = [
      for (final t in state)
        if (t.id == id) template else t,
    ];
    _sortState();
  }

  void deleteTemplate(String id) {
    unawaited(_box.delete(id));
    state = state.where((t) => t.id != id).toList();
  }
}
