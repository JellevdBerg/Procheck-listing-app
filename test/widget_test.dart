import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/main.dart';
import 'package:procheck/widgets/checklist_tile.dart';
import 'package:procheck/widgets/folder_card.dart';

void main() {
  late Directory tempDir;

  // Hive is initialized once for the whole suite: closing or clearing boxes
  // under the widget-test binding hangs indefinitely (both route through
  // real backend disk I/O that never resolves in this environment). Tests
  // that run after the first therefore see checklists earlier tests left
  // behind, so each test scopes its finders to the checklist it itself
  // created rather than assuming a pristine app state.
  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('procheck_test_');
    await setUpHive(testDirectoryPath: tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> createChecklist(WidgetTester tester, String name) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New checklist'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, name);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  Future<void> createFolder(WidgetTester tester, String name) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state, then a created checklist with progress', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ProcheckApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('No checklists yet'), findsOneWidget);

    await createChecklist(tester, 'Lab safety check');

    // The new checklist appears on the home screen with 0/0 progress.
    expect(find.text('Lab safety check'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);

    // Drill in and add an item, then check it off.
    await tester.tap(find.text('Lab safety check'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Put on gloves');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Put on gloves'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('checking off every subtask auto-checks the parent task', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ProcheckApp()));
    await tester.pumpAndSettle();

    await createChecklist(tester, 'Release checklist');
    await tester.tap(find.text('Release checklist'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ship it');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Expand the item to reveal the subtasks section.
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

    // The parent's own checkbox plus one per subtask.
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(3));

    await tester.tap(checkboxes.at(1));
    await tester.pumpAndSettle();
    await tester.tap(checkboxes.at(2));
    await tester.pumpAndSettle();

    expect(find.text('2/2 subtasks'), findsOneWidget);

    // Parent checkbox should now be checked too.
    final parentCheckbox = tester.widget<Checkbox>(checkboxes.first);
    expect(parentCheckbox.value, isTrue);
  });

  testWidgets('hovering over a checklist reveals a delete button', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ProcheckApp()));
    await tester.pumpAndSettle();

    await createChecklist(tester, 'Old checklist');

    // Scope to this test's own tile: earlier tests' checklists are still
    // around too (see the note on setUpAll above).
    final tileFinder = find.ancestor(
      of: find.text('Old checklist'),
      matching: find.byType(ChecklistTile),
    );
    expect(tileFinder, findsOneWidget);
    final deleteButtonFinder = find.descendant(
      of: tileFinder,
      matching: find.byIcon(Icons.delete_outline),
    );
    expect(deleteButtonFinder, findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await tester.pumpAndSettle();

    await gesture.moveTo(tester.getCenter(tileFinder));
    await tester.pumpAndSettle();

    expect(deleteButtonFinder, findsOneWidget);

    await tester.tap(deleteButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Old checklist'), findsNothing);
  });

  testWidgets(
    'a new folder shows as a featured card, hover reveals delete, tap opens it',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: ProcheckApp()));
      await tester.pumpAndSettle();

      await createFolder(tester, 'Groceries');

      final cardFinder = find.ancestor(
        of: find.text('Groceries'),
        matching: find.byType(FolderCard),
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

      // Tapping the card itself (not the delete button) opens the folder.
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      expect(find.text('No checklists in this folder yet.'), findsOneWidget);
    },
  );
}
