import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/models/project.dart';
import 'package:procheck/models/task.dart';
import 'package:procheck/providers/projects_provider.dart';
import 'package:procheck/providers/tasks_provider.dart';
import 'package:procheck/screens/dashboard_screen.dart';
import 'package:procheck/theme/nocturne_theme.dart';

void main() {
  final now = DateTime(2026, 9, 16, 12);

  Task makeTask({bool isChecked = false, DateTime? dueDate}) => Task(
    id: 't',
    title: 'Task',
    createdAt: now,
    isChecked: isChecked,
    dueDate: dueDate,
  );

  group('isOpenTask', () {
    test('an unchecked task with no due date is open', () {
      expect(isOpenTask(makeTask(), now), isTrue);
    });

    test('an unchecked overdue task is open', () {
      expect(
        isOpenTask(makeTask(dueDate: now.subtract(const Duration(days: 1))), now),
        isTrue,
      );
    });

    test('an unchecked task due in the future is not open', () {
      expect(
        isOpenTask(makeTask(dueDate: now.add(const Duration(days: 1))), now),
        isFalse,
      );
    });

    test('a checked task is never open, regardless of due date', () {
      expect(isOpenTask(makeTask(isChecked: true), now), isFalse);
      expect(
        isOpenTask(
          makeTask(isChecked: true, dueDate: now.subtract(const Duration(days: 1))),
          now,
        ),
        isFalse,
      );
    });
  });

  group('isPendingTask', () {
    test('an unchecked task due in the future is pending', () {
      expect(
        isPendingTask(makeTask(dueDate: now.add(const Duration(days: 1))), now),
        isTrue,
      );
    });

    test('an unchecked task with no due date is not pending', () {
      expect(isPendingTask(makeTask(), now), isFalse);
    });

    test('an unchecked overdue task is not pending', () {
      expect(
        isPendingTask(makeTask(dueDate: now.subtract(const Duration(days: 1))), now),
        isFalse,
      );
    });

    test('a checked task is never pending, regardless of due date', () {
      expect(
        isPendingTask(
          makeTask(isChecked: true, dueDate: now.add(const Duration(days: 1))),
          now,
        ),
        isFalse,
      );
    });

    test('open and pending are mutually exclusive for every task', () {
      for (final task in [
        makeTask(),
        makeTask(dueDate: now.add(const Duration(days: 1))),
        makeTask(dueDate: now.subtract(const Duration(days: 1))),
        makeTask(isChecked: true),
        makeTask(isChecked: true, dueDate: now.add(const Duration(days: 1))),
      ]) {
        expect(isOpenTask(task, now) && isPendingTask(task, now), isFalse);
      }
    });
  });

  group('computeProjectCompletions', () {
    var counter = 0;
    Project makeProject(String name) => Project(
      id: 'p${counter++}_$name',
      name: name,
      createdAt: now,
    );
    Task makeProjectTask(String projectId, {bool isChecked = false}) => Task(
      id: 't${counter++}',
      title: 'task',
      createdAt: now,
      projectId: projectId,
      isChecked: isChecked,
    );

    test('ranks projects by completion fraction, most complete first', () {
      final alpha = makeProject('Alpha'); // 1/2 = 50%
      final beta = makeProject('Beta'); // 2/2 = 100%
      final gamma = makeProject('Gamma'); // 0/2 = 0%
      final tasks = [
        makeProjectTask(alpha.id, isChecked: true),
        makeProjectTask(alpha.id),
        makeProjectTask(beta.id, isChecked: true),
        makeProjectTask(beta.id, isChecked: true),
        makeProjectTask(gamma.id),
        makeProjectTask(gamma.id),
      ];

      final result = computeProjectCompletions([alpha, beta, gamma], tasks);

      expect(
        result.map((r) => r.project.name).toList(),
        ['Beta', 'Alpha', 'Gamma'],
      );
      expect(result[0].fraction, 1.0);
      expect(result[1].fraction, 0.5);
      expect(result[2].fraction, 0.0);
    });

    test(
      'a project with no tasks has a null fraction and sorts after every ranked one',
      () {
        final hasTasks = makeProject('Has Tasks');
        final empty = makeProject('Empty');
        final tasks = [makeProjectTask(hasTasks.id, isChecked: true)];

        final result = computeProjectCompletions([empty, hasTasks], tasks);

        expect(result.map((r) => r.project.name).toList(), ['Has Tasks', 'Empty']);
        expect(result.first.fraction, 1.0);
        expect(result.last.fraction, isNull);
        expect(result.last.total, 0);
      },
    );

    test('ties in completion fraction break by project name', () {
      final bravo = makeProject('Bravo');
      final alpha = makeProject('Alpha');
      final tasks = [
        makeProjectTask(bravo.id, isChecked: true),
        makeProjectTask(alpha.id, isChecked: true),
      ];

      final result = computeProjectCompletions([bravo, alpha], tasks);

      expect(result.map((r) => r.project.name).toList(), ['Alpha', 'Bravo']);
    });

    test('multiple zero-task projects sort alphabetically among themselves', () {
      final zulu = makeProject('Zulu');
      final alphaEmpty = makeProject('Alpha');

      final result = computeProjectCompletions([zulu, alphaEmpty], const []);

      expect(result.map((r) => r.project.name).toList(), ['Alpha', 'Zulu']);
      expect(result.every((r) => r.fraction == null), isTrue);
    });

    test('returns nothing for an empty project list', () {
      expect(computeProjectCompletions(const [], const []), isEmpty);
    });
  });

  group('DashboardScreen', () {
    late Directory tempDir;

    // Hive keeps opened boxes cached in memory by name for the life of the
    // process, regardless of a later Hive.init(newPath) call — so, as with
    // the rest of this test suite's widget tests, these two tests share
    // Hive state and must not assume a pristine box. setUpAll/tearDownAll
    // (once for the group, not once per test) makes that sharing explicit;
    // the empty-state test runs first, before anything below adds data.
    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('procheck_dashboard_test_');
      await setUpHive(testDirectoryPath: tempDir.path);
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    Widget wrap(Widget child, ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildNocturneTheme(
            brightness: Brightness.dark,
            accent: nocturneAccentPalette.first,
          ),
          home: Scaffold(body: child),
        ),
      );
    }

    // Runs before any other test in this group adds data — see the note by
    // setUpAll above on why these tests share Hive state.
    testWidgets('shows the empty message when nothing is active yet', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        wrap(
          DashboardScreen(onOpenProject: (_, _) {}, onOpenTask: (_, _, _) {}),
          container,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No active projects or unfiled tasks yet.'), findsOneWidget);
    });

    testWidgets(
      'counts open/pending correctly and skips an archived project',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final launch = container
            .read(projectsProvider.notifier)
            .addProject('Launch', colorIndex: 0);
        final shelved = container
            .read(projectsProvider.notifier)
            .addProject('Shelved', colorIndex: 1);
        container.read(projectsProvider.notifier).archiveProject(shelved.id);

        final tasksNotifier = container.read(tasksProvider.notifier);
        final overdue = tasksNotifier.addBlankTask(
          title: 'Overdue in Launch',
          projectId: launch.id,
        );
        tasksNotifier.setTaskDueDate(
          overdue.id,
          DateTime.now().subtract(const Duration(days: 1)),
        );
        final scheduled = tasksNotifier.addBlankTask(
          title: 'Scheduled in Launch',
          projectId: launch.id,
        );
        tasksNotifier.setTaskDueDate(
          scheduled.id,
          DateTime.now().add(const Duration(days: 7)),
        );
        // A task in the archived project must not count anywhere.
        final ignored = tasksNotifier.addBlankTask(
          title: 'In shelved project',
          projectId: shelved.id,
        );
        tasksNotifier.setTaskDueDate(
          ignored.id,
          DateTime.now().subtract(const Duration(days: 1)),
        );
        final unfiledOverdue = tasksNotifier.addBlankTask(
          title: 'Unfiled overdue',
        );
        tasksNotifier.setTaskDueDate(
          unfiledOverdue.id,
          DateTime.now().subtract(const Duration(days: 1)),
        );

        await tester.pumpWidget(
          wrap(
            DashboardScreen(onOpenProject: (_, _) {}, onOpenTask: (_, _, _) {}),
            container,
          ),
        );
        await tester.pumpAndSettle();

        // Only the "Active projects" stat tile remains — the ambiguous
        // "Open tasks"/"Pending tasks" tiles were removed.
        String cardValue(IconData icon) {
          final textWidgets = tester
              .widgetList<Text>(
                find.descendant(
                  of: find.ancestor(
                    of: find.byIcon(icon),
                    matching: find.byType(Card),
                  ),
                  matching: find.byType(Text),
                ),
              )
              .toList();
          return textWidgets.first.data!;
        }

        expect(cardValue(Icons.folder_outlined), '1'); // Active projects
        expect(find.text('Open tasks'), findsNothing);
        expect(find.text('Pending tasks'), findsNothing);

        // Per-project breakdown: Launch shows its own open/pending tags,
        // the archived project never appears, and Unfiled shows up because
        // it has an open task.
        expect(find.text('Shelved'), findsNothing);
        expect(find.text('Unfiled'), findsNWidgets(2));
        expect(find.text('1 open'), findsNWidgets(2)); // Launch row + Unfiled row
        expect(find.text('1 pending'), findsOneWidget); // Launch row only

        // "Launch" now appears three times: the BY PROJECT row, its overdue
        // task's project label, and its PROJECT COMPLETION row.
        expect(find.text('Launch'), findsNWidgets(3));

        // Ring chart legend: overdue(2) = Launch's overdue + unfiled
        // overdue, active(1) = Launch's future-dated task, none completed.
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);

        // Overdue list: both overdue tasks show up with their project.
        expect(find.text('Overdue in Launch'), findsOneWidget);
        expect(find.text('Unfiled overdue'), findsOneWidget);

        // Project completion: Launch has 0 of 2 tasks done. Unfiled tasks
        // aren't a project, so they don't get a row here.
        expect(find.text('PROJECT COMPLETION'), findsOneWidget);
        expect(find.text('0%'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping an overdue task opens its project via onOpenTask',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final project = container
            .read(projectsProvider.notifier)
            .addProject('ClickTarget');
        final tasksNotifier = container.read(tasksProvider.notifier);
        final overdue = tasksNotifier.addBlankTask(
          title: 'Click this overdue task',
          projectId: project.id,
        );
        tasksNotifier.setTaskDueDate(
          overdue.id,
          DateTime.now().subtract(const Duration(days: 1)),
        );

        String? openedProjectId;
        String? openedTaskId;
        await tester.pumpWidget(
          wrap(
            DashboardScreen(
              onOpenProject: (_, _) {},
              onOpenTask: (projectId, taskId, _) {
                openedProjectId = projectId;
                openedTaskId = taskId;
              },
            ),
            container,
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Click this overdue task'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Click this overdue task'));
        await tester.pumpAndSettle();

        expect(openedProjectId, project.id);
        expect(openedTaskId, overdue.id);
      },
    );
  });
}
