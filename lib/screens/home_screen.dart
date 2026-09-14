import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/checklist_template.dart';
import '../providers/checklists_provider.dart';
import '../providers/folders_provider.dart';
import '../providers/templates_provider.dart';
import '../widgets/checklist_tile.dart';
import '../widgets/create_checklist_sheet.dart';
import '../widgets/folder_card.dart';
import '../widgets/page_transitions.dart';
import '../widgets/text_prompt_dialog.dart';
import 'checklist_detail_screen.dart';
import 'folder_detail_screen.dart';
import 'template_editor_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DropAwayOnPush(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Procheck'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Checklists'),
              Tab(text: 'Templates'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [_ChecklistsTab(), _TemplatesTab()],
        ),
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton(
                onPressed: () => _showChecklistTabActions(context),
                child: const Icon(Icons.add),
              )
            : FloatingActionButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TemplateEditorScreen(),
                  ),
                ),
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  void _showChecklistTabActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist_rtl_rounded),
              title: const Text('New checklist'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showCreateChecklistSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('New folder'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final name = await showTextPromptDialog(
                  context,
                  title: 'New folder',
                  confirmLabel: 'Create',
                );
                if (name != null) {
                  ref.read(foldersProvider.notifier).addFolder(name);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistsTab extends ConsumerWidget {
  const _ChecklistsTab();

  static const _featuredCount = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider);
    final checklists = ref.watch(checklistsProvider);
    final unfiledChecklists = checklists
        .where((checklist) => checklist.folderId == null)
        .toList();

    if (folders.isEmpty && unfiledChecklists.isEmpty) {
      return const _EmptyState(
        icon: Icons.checklist_rtl_rounded,
        message: 'No checklists yet.\nTap + to create your first checklist or folder.',
      );
    }

    final featuredFolders = folders.take(_featuredCount).toList();
    final otherFolders = folders.skip(_featuredCount).toList();

    void openFolder(String folderId) =>
        pushSlideIn(context, FolderDetailScreen(folderId: folderId));

    return ListView(
      children: [
        if (featuredFolders.isNotEmpty) ...[
          const _SectionHeader('Folders'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final folder in featuredFolders)
                  FolderCard(
                    folder: folder,
                    featured: true,
                    checklists: checklists
                        .where((c) => c.folderId == folder.id)
                        .toList(),
                    onTap: () => openFolder(folder.id),
                    onDelete: () => ref
                        .read(foldersProvider.notifier)
                        .deleteFolder(folder.id),
                  ),
              ],
            ),
          ),
        ],
        if (otherFolders.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final folder in otherFolders)
                  FolderCard(
                    folder: folder,
                    checklists: checklists
                        .where((c) => c.folderId == folder.id)
                        .toList(),
                    onTap: () => openFolder(folder.id),
                    onDelete: () => ref
                        .read(foldersProvider.notifier)
                        .deleteFolder(folder.id),
                  ),
              ],
            ),
          ),
        ],
        if (unfiledChecklists.isNotEmpty) ...[
          const _SectionHeader('Checklists'),
          for (final checklist in unfiledChecklists)
            ChecklistTile(
              checklist: checklist,
              onTap: () => pushSlideIn(
                context,
                ChecklistDetailScreen(checklistId: checklist.id),
              ),
              onDelete: () => ref
                  .read(checklistsProvider.notifier)
                  .deleteChecklist(checklist.id),
            ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);

    if (templates.isEmpty) {
      return const _EmptyState(
        icon: Icons.copy_all_outlined,
        message: 'No templates yet.\nTemplates let you reuse a predefined set of checklist items.',
      );
    }

    return ListView(
      children: [
        for (final ChecklistTemplate template in templates)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.copy_all_outlined)),
            title: Text(template.name),
            subtitle: Text('${template.items.length} item(s)'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TemplateEditorScreen(templateId: template.id),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.playlist_add_check),
              tooltip: 'Use template',
              onPressed: () =>
                  showCreateChecklistSheet(context, initialTemplate: template),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
