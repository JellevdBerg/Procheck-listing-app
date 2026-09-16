import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/project.dart';
import '../../providers/projects_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_templates_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../screens/app_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../theme/nocturne_theme.dart';
import '../app_logo.dart';
import '../text_prompt_dialog.dart';
import 'mini_calendar.dart';

/// The persistent left navigation column: workspace switcher, smart views
/// (Today/Upcoming), Favorites, the Projects/Templates/Archived library,
/// a mini calendar, and Settings — collapsible to an icon-only rail.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentScreen,
    required this.onScreenSelected,
    required this.onFavoriteProjectTap,
    required this.onDaySelected,
    required this.calendarMonth,
    required this.selectedDay,
  });

  final AppScreen currentScreen;
  final ValueChanged<AppScreen> onScreenSelected;
  final ValueChanged<Project> onFavoriteProjectTap;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime calendarMonth;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final projects = ref.watch(projectsProvider);
    final tasks = ref.watch(tasksProvider);
    final templates = ref.watch(taskTemplatesProvider);
    final tokens = context.nocturne;
    final accent = context.nocturneAccent;
    final expanded = settings.sidebarExpanded;

    final now = DateTime.now();
    final todayCount = tasks
        .where((t) => !t.isChecked && t.dueDate != null && _isSameDay(t.dueDate!, now))
        .length;
    final upcomingCount = tasks
        .where(
          (t) =>
              !t.isChecked &&
              t.dueDate != null &&
              t.dueDate!.isAfter(DateTime(now.year, now.month, now.day, 23, 59)),
        )
        .length;
    final activeProjects = projects.where((p) => !p.archived).toList();
    final favorites = activeProjects.where((p) => p.favorite).toList();
    final archivedCount = projects.where((p) => p.archived).length;

    final activeProjectIds = activeProjects.map((p) => p.id).toSet();
    final dashboardCount = tasks
        .where(
          (t) =>
              (t.projectId == null || activeProjectIds.contains(t.projectId)) &&
              (isOpenTask(t, now) || isPendingTask(t, now)),
        )
        .length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: expanded ? 232 : 68,
      decoration: BoxDecoration(
        color: tokens.neutral900,
        border: Border(right: BorderSide(color: tokens.neutral800)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _Header(
            expanded: expanded,
            onToggle: () => ref
                .read(settingsProvider.notifier)
                .setSidebarExpanded(!expanded),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _NavRow(
              icon: Icons.business,
              label: settings.currentWorkspaceName,
              expanded: expanded,
              background: tokens.neutral800,
              trailing: expanded
                  ? Icon(
                      Icons.unfold_more,
                      size: 13,
                      color: tokens.neutral400,
                    )
                  : null,
              onTap: () => ref.read(settingsProvider.notifier).cycleWorkspace(),
              onSecondaryTapDown: (details) => _showWorkspaceContextMenu(
                context,
                ref,
                settings.workspaceIndex,
                details.globalPosition,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // The nav sections scroll independently of the calendar/Settings
          // pinned below: enough favorited/archived/templated content would
          // otherwise overflow a short window, since this is the one
          // variable-height part of an otherwise fixed sidebar.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        _NavRow(
                          icon: Icons.dashboard_outlined,
                          label: 'Dashboard',
                          count: dashboardCount,
                          expanded: expanded,
                          active: currentScreen == AppScreen.dashboard,
                          accent: accent,
                          onTap: () => onScreenSelected(AppScreen.dashboard),
                        ),
                        const SizedBox(height: 2),
                        _NavRow(
                          icon: Icons.wb_sunny_outlined,
                          label: 'Today',
                          count: todayCount,
                          expanded: expanded,
                          active: currentScreen == AppScreen.today,
                          accent: accent,
                          onTap: () => onScreenSelected(AppScreen.today),
                        ),
                        const SizedBox(height: 2),
                        _NavRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Upcoming',
                          count: upcomingCount,
                          expanded: expanded,
                          active: currentScreen == AppScreen.upcoming,
                          accent: accent,
                          onTap: () => onScreenSelected(AppScreen.upcoming),
                        ),
                      ],
                    ),
                  ),
                  if (expanded && favorites.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
                      child: _SmallSectionLabel('Favorites'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          for (final project in favorites)
                            _NavRow(
                              icon: Icons.folder,
                              label: project.name,
                              expanded: expanded,
                              iconColor: accentPalette[project.colorIndex],
                              onTap: () => onFavoriteProjectTap(project),
                              onSecondaryTapDown: (details) =>
                                  _showFavoriteContextMenu(
                                    context,
                                    ref,
                                    project,
                                    details.globalPosition,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                    child: expanded
                        ? const _SmallSectionLabel('Library')
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        _NavRow(
                          icon: Icons.folder,
                          label: 'Projects',
                          count: activeProjects.length,
                          expanded: expanded,
                          active: currentScreen == AppScreen.projects,
                          accent: accent,
                          onTap: () => onScreenSelected(AppScreen.projects),
                        ),
                        const SizedBox(height: 2),
                        _NavRow(
                          icon: Icons.copy_all_outlined,
                          label: 'Templates',
                          count: templates.length,
                          expanded: expanded,
                          active: currentScreen == AppScreen.templates,
                          accent: accent,
                          onTap: () => onScreenSelected(AppScreen.templates),
                        ),
                        const SizedBox(height: 2),
                        _NavRow(
                          icon: Icons.archive_outlined,
                          label: 'Archived',
                          count: archivedCount,
                          expanded: expanded,
                          active: currentScreen == AppScreen.archived,
                          accent: accent,
                          onTap: () => onScreenSelected(AppScreen.archived),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            MiniCalendar(
              month: calendarMonth,
              selectedDay: selectedDay,
              onDayTap: onDaySelected,
            ),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _NavRow(
              icon: Icons.settings_outlined,
              label: 'Settings',
              expanded: expanded,
              active: currentScreen == AppScreen.settings,
              accent: accent,
              onTap: () => onScreenSelected(AppScreen.settings),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static Future<void> _showWorkspaceContextMenu(
    BuildContext context,
    WidgetRef ref,
    int workspaceIndex,
    Offset globalPosition,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<_WorkspaceAction>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(
          value: _WorkspaceAction.add,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_business_outlined),
            title: Text('Add workspace'),
          ),
        ),
        PopupMenuItem(
          value: _WorkspaceAction.edit,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit workspace'),
          ),
        ),
        PopupMenuItem(
          value: _WorkspaceAction.remove,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline),
            title: Text('Remove workspace'),
          ),
        ),
      ],
    );
    if (!context.mounted || selected == null) return;

    final notifier = ref.read(settingsProvider.notifier);
    switch (selected) {
      case _WorkspaceAction.add:
        final name = await showTextPromptDialog(
          context,
          title: 'Add workspace',
          confirmLabel: 'Add',
        );
        if (name != null) notifier.addWorkspace(name);
      case _WorkspaceAction.edit:
        final currentName = ref.read(settingsProvider).currentWorkspaceName;
        final name = await showTextPromptDialog(
          context,
          title: 'Edit workspace',
          initialValue: currentName,
        );
        if (name != null) notifier.renameWorkspace(workspaceIndex, name);
      case _WorkspaceAction.remove:
        await _removeWorkspace(context, ref, workspaceIndex);
    }
  }

  /// Removing a workspace is destructive — unlike a rename, it takes every
  /// project/task/template tagged with that workspace down with it (see
  /// AppSettings.workspaceIds) — so this confirms with the user first,
  /// naming exactly how much would be deleted, then cascades the delete
  /// through each data provider before dropping the workspace itself.
  static Future<void> _removeWorkspace(
    BuildContext context,
    WidgetRef ref,
    int workspaceIndex,
  ) async {
    final settings = ref.read(settingsProvider);
    if (settings.workspaceNames.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Can't remove the only workspace.")),
      );
      return;
    }

    final workspaceId = settings.workspaceIds[workspaceIndex];
    final workspaceName = settings.workspaceNames[workspaceIndex];
    final projectCount = ref
        .read(projectsProvider.notifier)
        .countForWorkspace(workspaceId);
    final taskCount = ref
        .read(tasksProvider.notifier)
        .countForWorkspace(workspaceId);
    final templateCount = ref
        .read(taskTemplatesProvider.notifier)
        .countForWorkspace(workspaceId);

    final isEmpty = projectCount == 0 && taskCount == 0 && templateCount == 0;
    final message = isEmpty
        ? 'This workspace has no projects, tasks, or templates. This cannot be undone.'
        : 'This permanently deletes $projectCount project(s), $taskCount '
              'task(s), and $templateCount template(s) in "$workspaceName". '
              'This cannot be undone.';

    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove workspace?',
      message: message,
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;

    // Projects first — deleting one cascades to its own tasks — then a
    // sweep for whatever's left (unfiled tasks, templates).
    ref.read(projectsProvider.notifier).deleteAllForWorkspace(workspaceId);
    ref.read(tasksProvider.notifier).deleteAllForWorkspace(workspaceId);
    ref.read(taskTemplatesProvider.notifier).deleteAllForWorkspace(workspaceId);
    ref.read(settingsProvider.notifier).removeWorkspace(workspaceIndex);
  }

  static Future<void> _showFavoriteContextMenu(
    BuildContext context,
    WidgetRef ref,
    Project project,
    Offset globalPosition,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<_FavoriteAction>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(
          value: _FavoriteAction.unfavorite,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.star_border),
            title: Text('Unfavorite'),
          ),
        ),
      ],
    );
    if (selected == _FavoriteAction.unfavorite) {
      ref.read(projectsProvider.notifier).toggleFavorite(project.id);
    }
  }
}

enum _FavoriteAction { unfavorite }

enum _WorkspaceAction { add, edit, remove }

class _Header extends StatelessWidget {
  const _Header({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    if (!expanded) {
      return Column(
        children: [
          const AppLogo(size: 24),
          const SizedBox(height: 12),
          IconButton(
            icon: Icon(
              Icons.view_sidebar_outlined,
              size: 17,
              color: tokens.neutral400,
            ),
            onPressed: onToggle,
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const AppLogo(size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ProCheck',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: tokens.text,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.view_sidebar_outlined,
              size: 17,
              color: tokens.neutral400,
            ),
            onPressed: onToggle,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SmallSectionLabel extends StatelessWidget {
  const _SmallSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 0.06,
        color: context.nocturne.neutral500,
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.expanded,
    this.count,
    this.active = false,
    this.accent,
    this.iconColor,
    this.background,
    this.trailing,
    required this.onTap,
    this.onSecondaryTapDown,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final int? count;
  final bool active;
  final Color? accent;
  final Color? iconColor;
  final Color? background;
  final Widget? trailing;
  final VoidCallback onTap;
  final void Function(TapDownDetails details)? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final activeBg = active && accent != null
        ? Color.alphaBlend(accent!.withValues(alpha: 0.22), tokens.neutral900)
        : background;

    return GestureDetector(
      onSecondaryTapDown: onSecondaryTapDown,
      child: Material(
        color: activeBg ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: active && accent != null
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: accent!, width: 2),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: iconColor ?? (active ? accent : tokens.neutral300),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.neutral200,
                      ),
                    ),
                  ),
                  if (count != null && count! > 0)
                    Text(
                      '$count',
                      style: TextStyle(fontSize: 12, color: tokens.neutral400),
                    ),
                  if (trailing != null) ...[
                    const SizedBox(width: 4),
                    trailing!,
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
