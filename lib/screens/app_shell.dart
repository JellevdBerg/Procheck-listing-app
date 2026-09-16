import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../models/shortcut_binding.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/nocturne_theme.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/sidebar/app_sidebar.dart';
import '../widgets/text_prompt_dialog.dart';
import 'app_screen.dart';
import 'archived_screen.dart';
import 'dashboard_screen.dart';
import 'day_screen.dart';
import 'project_detail_overlay.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';
import 'templates_screen.dart';
import 'today_screen.dart';
import 'upcoming_screen.dart';

/// Requests the bottom-right undo button, replacing whatever it was
/// currently offering to undo.
typedef ShowUndo = void Function({required String label, required VoidCallback onUndo});

/// Requests the project-detail overlay open on top of whatever screen is
/// currently showing — [originRect] is the tapped card's rect (in the main
/// content area's own coordinate space) for the card-morph animation, or
/// null to just fade in (e.g. opened from a sidebar favorite, with no card
/// to morph from).
typedef OpenProjectDetail = void Function(String projectId, {Rect? originRect});

/// The app's root shell once past the splash screen: a persistent sidebar
/// plus a main content area that swaps between screens without the sidebar
/// ever leaving. Project detail is a card-morph overlay drawn on top of the
/// main content area (see [ProjectDetailOverlay]), not a separate route —
/// that's what lets the sidebar stay visible while it's open.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with TickerProviderStateMixin {
  late AppScreen _screen;
  DateTime? _selectedDay;
  DateTime _calendarMonth = DateTime.now();

  String? _toastMessage;
  Timer? _toastTimer;

  _PendingUndo? _pendingUndo;
  Timer? _undoTimer;

  String? _detailProjectId;
  Rect? _originRect;
  late final AnimationController _morphController = AnimationController(
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 260),
    vsync: this,
  );

  final GlobalKey _mainAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _screen = switch (settings.defaultLanding) {
      LandingScreenOption.projects => AppScreen.projects,
      LandingScreenOption.templates => AppScreen.templates,
      LandingScreenOption.lastViewed =>
        AppScreen.values[settings.lastViewedScreenIndex.clamp(
          0,
          AppScreen.values.length - 1,
        )],
    };
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _undoTimer?.cancel();
    _morphController.dispose();
    super.dispose();
  }

  void _switchScreen(AppScreen screen) {
    setState(() => _screen = screen);
    ref.read(settingsProvider.notifier).recordLastViewedScreen(screen.index);
    if (_detailProjectId != null) _closeProjectDetail();
  }

  void _showToast(String message) {
    setState(() => _toastMessage = message);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  void _showUndo({required String label, required VoidCallback onUndo}) {
    _undoTimer?.cancel();
    setState(() => _pendingUndo = _PendingUndo(label: label, onUndo: onUndo));
    _undoTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _pendingUndo = null);
    });
  }

  void _resolveUndo() {
    _undoTimer?.cancel();
    _pendingUndo?.onUndo();
    setState(() => _pendingUndo = null);
  }

  void _openProjectDetail(String projectId, {Rect? originRect}) {
    final reduceMotion = ref.read(settingsProvider).reduceMotion;
    setState(() {
      _detailProjectId = projectId;
      _originRect = originRect;
    });
    if (reduceMotion) {
      _morphController.value = 1;
    } else {
      _morphController.forward(from: 0);
    }
  }

  void _closeProjectDetail() {
    final reduceMotion = ref.read(settingsProvider).reduceMotion;
    if (reduceMotion) {
      _morphController.value = 0;
      setState(() => _detailProjectId = null);
      return;
    }
    _morphController.reverse().whenComplete(() {
      if (mounted) setState(() => _detailProjectId = null);
    });
  }

  void _openProjectFromCard(String projectId, BuildContext cardContext) {
    final cardBox = cardContext.findRenderObject() as RenderBox?;
    final mainBox =
        _mainAreaKey.currentContext?.findRenderObject() as RenderBox?;
    Rect? rect;
    if (cardBox != null && mainBox != null) {
      final origin = cardBox.localToGlobal(Offset.zero, ancestor: mainBox);
      rect = origin & cardBox.size;
    }
    ref.read(projectsProvider.notifier).touchProject(projectId);
    _openProjectDetail(projectId, originRect: rect);
  }

  void _openFavoriteProject(Project project) {
    ref.read(projectsProvider.notifier).touchProject(project.id);
    setState(() => _screen = AppScreen.projects);
    _openProjectDetail(project.id);
  }

  Future<void> _newProjectShortcut() async {
    _showToast('New project');
    final result = await showProjectPromptDialog(
      context,
      title: 'New project',
      confirmLabel: 'Create',
    );
    if (result != null) {
      final (name, colorIndex) = result;
      ref.read(projectsProvider.notifier).addProject(name, colorIndex: colorIndex);
    }
  }

  Future<void> _newTaskShortcut() async {
    _showToast('New task');
    await showCreateTaskSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final settings = ref.watch(settingsProvider);

    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final activator
        in settings.shortcutFor(ShortcutAction.newProject).toActivators()) {
      bindings[activator] = _newProjectShortcut;
    }
    for (final activator
        in settings.shortcutFor(ShortcutAction.newTask).toActivators()) {
      bindings[activator] = _newTaskShortcut;
    }

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: bindings,
        child: Scaffold(
          backgroundColor: tokens.bg,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSidebar(
                currentScreen: _screen,
                onScreenSelected: _switchScreen,
                onFavoriteProjectTap: _openFavoriteProject,
                onDaySelected: (day) {
                  setState(() {
                    _selectedDay = day;
                    _calendarMonth = day;
                    _screen = AppScreen.day;
                  });
                  if (_detailProjectId != null) _closeProjectDetail();
                },
                calendarMonth: _calendarMonth,
                selectedDay: _selectedDay,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      key: _mainAreaKey,
                      children: [
                        Positioned.fill(child: _buildScreen()),
                        if (_detailProjectId != null)
                          _buildDetailOverlay(constraints),
                        if (_pendingUndo != null)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: _UndoButton(
                              label: _pendingUndo!.label,
                              onPressed: _resolveUndo,
                            ),
                          ),
                        if (_toastMessage != null)
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _Toast(message: _toastMessage!),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailOverlay(BoxConstraints constraints) {
    const margin = 16.8;
    final expanded = Rect.fromLTWH(
      margin,
      margin,
      (constraints.maxWidth - margin * 2).clamp(0, double.infinity),
      (constraints.maxHeight - margin * 2).clamp(0, double.infinity),
    );
    final origin = _originRect ?? expanded;

    return AnimatedBuilder(
      animation: _morphController,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_morphController.value);
        final rect = Rect.lerp(origin, expanded, t)!;
        final contentOpacity = ((_morphController.value - 0.35) / 0.65).clamp(
          0.0,
          1.0,
        );
        return Positioned.fromRect(
          rect: rect,
          child: Material(
            color: context.nocturne.bg,
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(NocturneRadius.md),
            child: Opacity(
              opacity: contentOpacity,
              child: child,
            ),
          ),
        );
      },
      child: ProjectDetailOverlay(
        projectId: _detailProjectId!,
        onClose: _closeProjectDetail,
      ),
    );
  }

  Widget _buildScreen() {
    return switch (_screen) {
      AppScreen.projects => ProjectsScreen(
        onShowUndo: _showUndo,
        onOpenProject: _openProjectFromCard,
      ),
      AppScreen.today => const TodayScreen(),
      AppScreen.upcoming => const UpcomingScreen(),
      AppScreen.day => DayScreen(date: _selectedDay ?? DateTime.now()),
      AppScreen.templates => const TemplatesScreen(),
      AppScreen.archived => ArchivedScreen(onOpenProject: _openProjectFromCard),
      AppScreen.settings => const SettingsScreen(),
      AppScreen.dashboard => DashboardScreen(onOpenProject: _openProjectFromCard),
    };
  }
}

/// What's currently offered for undo — at most one at a time.
class _PendingUndo {
  _PendingUndo({required this.label, required this.onUndo});
  final String label;
  final VoidCallback onUndo;
}

/// A small floating "Undo" button pinned to the bottom-right: it doesn't
/// queue behind earlier removals (a new one replaces it) and expires on its
/// own after a few seconds instead of lingering.
class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'undo-button',
      onPressed: onPressed,
      tooltip: label,
      icon: const Icon(Icons.undo),
      label: const Text('Undo'),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.neutral800,
        borderRadius: BorderRadius.circular(NocturneRadius.md),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Text(
          '$message (shortcut)',
          style: TextStyle(fontSize: 13, color: tokens.text),
        ),
      ),
    );
  }
}
