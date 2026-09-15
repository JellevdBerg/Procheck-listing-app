import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/main.dart';
import 'package:procheck/widgets/project_card.dart';
import 'package:procheck/widgets/task_tile.dart';

void main() {
  late Directory tempDir;

  // Hive is initialized once for the whole suite: closing or clearing boxes
  // under the widget-test binding hangs indefinitely (both route through
  // real backend disk I/O that never resolves in this environment). Tests
  // that run after the first therefore see tasks/projects earlier tests
  // left behind, so each test scopes its finders to what it itself created
  // rather than assuming a pristine app state.
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('procheck_test_');
    await setUpHive(testDirectoryPath: tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  // The app now shows a brief splash screen before the home screen; advance
  // past its timer (fake-async under the hood, so this doesn't slow the
  // test down for real) before interacting with anything.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProcheckApp()));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
  }

  // Scoped to the open dialog: the home screen's persistent project search
  // field is also a TextField and stays mounted (just visually behind the
  // blurred dialog), so an unscoped `find.byType(TextField)` would match both.
  Finder dialogTextField() => find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );

  Future<void> createTask(WidgetTester tester, String name) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();

    await tester.enterText(dialogTextField(), name);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  Future<void> createProject(WidgetTester tester, String name) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();

    await tester.enterText(dialogTextField(), name);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state, then a created task appears in the list', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.textContaining('No tasks yet'), findsOneWidget);

    await createTask(tester, 'Buy milk');

    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets('deleting the only project returns to the empty grid', (
    tester,
  ) async {
    // Runs before any other test creates a project, so this really is the
    // only one — exercising the pop-out animation's edge case of a Wrap
    // section going from one item straight to zero.
    await pumpApp(tester);

    await createProject(tester, 'OnlyOne');
    expect(find.text('OnlyOne'), findsOneWidget);

    final cardFinder = find.ancestor(
      of: find.text('OnlyOne'),
      matching: find.byType(ProjectCard),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(cardFinder));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: cardFinder,
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('OnlyOne'), findsNothing);
    expect(find.byType(ProjectCard), findsNothing);
  });

  testWidgets('a project task can be checked off and stays checked', (
    tester,
  ) async {
    await pumpApp(tester);

    await createProject(tester, 'Errands');
    await tester.tap(find.text('Errands'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField(), 'Buy milk');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);

    final checkboxFinder = find.ancestor(
      of: find.text('Buy milk'),
      matching: find.byType(ListTile),
    );
    final checkbox = find.descendant(
      of: checkboxFinder,
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
  });

  testWidgets('checking off every subtask auto-checks the parent task', (
    tester,
  ) async {
    await pumpApp(tester);

    // Created inside a project: an unfiled task would be auto-removed once
    // fully checked (see the dedicated test below), which would defeat the
    // point of this one.
    await createProject(tester, 'Launch');
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField(), 'Ship it');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Expand the task to reveal the subtasks section.
    await tester.tap(find.text('Ship it'));
    await tester.pumpAndSettle();

    final subtaskField = find.widgetWithText(TextField, 'Add a subtask');
    await tester.enterText(subtaskField, 'Run tests');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.enterText(subtaskField, 'Tag release');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Run tests'), findsOneWidget);
    expect(find.text('Tag release'), findsOneWidget);
    expect(find.text('0/2 subtasks'), findsOneWidget);

    // Scope to this test's own task tile: earlier tests' tasks are still
    // around too (see the note on setUpAll above).
    final taskTileFinder = find.ancestor(
      of: find.text('Ship it'),
      matching: find.byType(TaskTile),
    );

    // The task's own checkbox plus one per subtask.
    final checkboxes = find.descendant(
      of: taskTileFinder,
      matching: find.byType(Checkbox),
    );
    expect(checkboxes, findsNWidgets(3));

    await tester.tap(checkboxes.at(1));
    await tester.pumpAndSettle();
    await tester.tap(checkboxes.at(2));
    await tester.pumpAndSettle();

    expect(find.text('2/2 subtasks'), findsOneWidget);

    // The task checkbox should now be checked too.
    final taskCheckbox = tester.widget<Checkbox>(checkboxes.first);
    expect(taskCheckbox.value, isTrue);
  });

  testWidgets('deleting a task removes it from the list', (tester) async {
    await pumpApp(tester);

    await createTask(tester, 'Temporary task');
    expect(find.text('Temporary task'), findsOneWidget);

    final rowFinder = find.ancestor(
      of: find.text('Temporary task'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: rowFinder,
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Temporary task'), findsNothing);
  });

  testWidgets('checking off an unfiled task removes it automatically', (
    tester,
  ) async {
    await pumpApp(tester);

    await createTask(tester, 'Quick one-off');
    expect(find.text('Quick one-off'), findsOneWidget);

    final checkbox = find.descendant(
      of: find.ancestor(
        of: find.text('Quick one-off'),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(find.text('Quick one-off'), findsNothing);
  });

  testWidgets(
    'checking off an unfiled task plays the bounce before removing it',
    (tester) async {
      await pumpApp(tester);

      await createTask(tester, 'Bouncy one-off');
      final checkbox = find.descendant(
        of: find.ancestor(
          of: find.text('Bouncy one-off'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(Checkbox),
      );
      await tester.tap(checkbox);

      // Immediately after checking it off — and partway through the bounce
      // — the task must still be on screen. An instant removal would tear
      // the checkbox out from under its own animation.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Bouncy one-off'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Bouncy one-off'), findsNothing);
    },
  );

  testWidgets(
    'a new project shows as a featured card, hover reveals delete, tap opens it',
    (tester) async {
      await pumpApp(tester);

      await createProject(tester, 'Groceries');

      final cardFinder = find.ancestor(
        of: find.text('Groceries'),
        matching: find.byType(ProjectCard),
      );
      expect(cardFinder, findsOneWidget);

      final deleteFinder = find.descendant(
        of: cardFinder,
        matching: find.byIcon(Icons.delete_outline),
      );
      expect(deleteFinder, findsNothing);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await tester.pumpAndSettle();

      await gesture.moveTo(tester.getCenter(cardFinder));
      await tester.pumpAndSettle();

      expect(deleteFinder, findsOneWidget);

      // Tapping the card itself (not the delete button) opens the project.
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      expect(find.text('No tasks in this project yet.'), findsOneWidget);
    },
  );

  testWidgets('deleting a project also deletes its tasks', (tester) async {
    await pumpApp(tester);

    await createProject(tester, 'Kitchen Remodel');
    await tester.tap(find.text('Kitchen Remodel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField(), 'Pick tiles');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Pick tiles'), findsOneWidget);

    // Back to the projects list, then delete the project via hover + the
    // card's delete button.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    final cardFinder = find.ancestor(
      of: find.text('Kitchen Remodel'),
      matching: find.byType(ProjectCard),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(cardFinder));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: cardFinder,
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();
    // Confirm the "Delete project?" dialog.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Kitchen Remodel'), findsNothing);
    expect(find.text('Pick tiles'), findsNothing);
  });

  testWidgets('a lone project card is centered, not stretched full width', (
    tester,
  ) async {
    await pumpApp(tester);

    await createProject(tester, 'Solo Project');

    final cardFinder = find.ancestor(
      of: find.text('Solo Project'),
      matching: find.byType(ProjectCard),
    );
    final cardWidth = tester.getSize(cardFinder).width;
    final windowWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    // Well short of the available width (minus the 32px of horizontal grid
    // padding) — a full-width stretch would come within a few px of it.
    expect(cardWidth, lessThan(windowWidth - 32 - 100));
  });

  testWidgets('Settings > Wipe All Data clears everything without restart', (
    tester,
  ) async {
    await pumpApp(tester);

    await createProject(tester, 'ToWipe');
    expect(find.text('ToWipe'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // The Backup & restore section pushed this further down the list.
    await tester.scrollUntilVisible(
      find.text('Wipe all data'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Wipe all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wipe everything'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('ToWipe'), findsNothing);
    expect(find.textContaining('No tasks yet'), findsOneWidget);
  });
}
