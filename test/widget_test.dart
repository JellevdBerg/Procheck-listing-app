import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/main.dart';
import 'package:procheck/screens/project_detail_overlay.dart';
import 'package:procheck/widgets/project_card.dart';
import 'package:procheck/widgets/sidebar/app_sidebar.dart';
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

  // The app now shows a brief splash screen before the shell; advance past
  // its timer (fake-async under the hood, so this doesn't slow the test
  // down for real) before interacting with anything.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProcheckApp()));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
  }

  // Scoped to the open dialog: some screens' own TextFields (search boxes,
  // comment boxes) stay mounted behind a blurred dialog, so an unscoped
  // `find.byType(TextField)` could match more than one.
  Finder dialogTextField() => find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );

  // The project detail overlay stays mounted underneath — well, the
  // Projects screen stays mounted *underneath* the overlay while it's open,
  // for the close-morph to animate back to — so finders inside the overlay
  // (e.g. its own "New task" button) must be scoped to it to avoid matching
  // the Projects screen's own same-labeled button too.
  Finder overlayFinder() => find.byType(ProjectDetailOverlay);

  Future<void> createProject(WidgetTester tester, String name) async {
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField(), name);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  Future<void> createTask(WidgetTester tester, String name) async {
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField(), name);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  Future<void> createTaskInOverlay(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(of: overlayFinder(), matching: find.text('New task')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(dialogTextField(), name);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
  }

  // Opens a hovering ProjectCard's actions menu (assumes the card is already
  // hovered) and taps the entry whose leading icon is [actionIcon] —
  // Icons.archive_outlined or Icons.delete_outline.
  Future<void> tapProjectCardAction(
    WidgetTester tester,
    Finder cardFinder,
    IconData actionIcon,
  ) async {
    await tester.tap(
      find.descendant(of: cardFinder, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.byIcon(actionIcon),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> hoverOver(WidgetTester tester, Finder finder) async {
    // Earlier tests leave projects behind (see the note on setUpAll above),
    // so by the time a later test runs there can be enough cards that the
    // one it cares about has scrolled out of view — moving a pointer to an
    // off-screen coordinate never triggers the MouseRegion's hover.
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: Offset.zero);
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(finder));
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state, then a created task appears in the list', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.textContaining('No unfiled tasks'), findsOneWidget);

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
    await hoverOver(tester, cardFinder);

    await tapProjectCardAction(tester, cardFinder, Icons.delete_outline);
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

    await createTaskInOverlay(tester, 'Buy milk');
    final taskTitle = find.descendant(
      of: overlayFinder(),
      matching: find.text('Buy milk'),
    );
    expect(taskTitle, findsOneWidget);

    final checkboxFinder = find.ancestor(
      of: taskTitle,
      matching: find.byType(ListTile),
    );
    final checkbox = find.descendant(
      of: checkboxFinder,
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(taskTitle, findsOneWidget);
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

    await createTaskInOverlay(tester, 'Ship it');
    final shipItInOverlay = find.descendant(
      of: overlayFinder(),
      matching: find.text('Ship it'),
    );

    // Expand the task to reveal the subtasks section. Tapping the
    // ancestor ListTile (its onTap is what toggles expansion) rather than
    // the title Text directly: the Text's own hit box is narrow and left-
    // aligned, while the ListTile spans the tile's full width.
    await tester.tap(
      find.ancestor(of: shipItInOverlay, matching: find.byType(ListTile)),
    );
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
      of: shipItInOverlay,
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
    'a new project shows as a featured card, hover reveals the actions menu, tap opens it',
    (tester) async {
      await pumpApp(tester);

      await createProject(tester, 'Groceries');

      final cardFinder = find.ancestor(
        of: find.text('Groceries'),
        matching: find.byType(ProjectCard),
      );
      expect(cardFinder, findsOneWidget);

      // The actions button stays mounted at all times (reserving its layout
      // space so hover never reflows the card) — only its Visibility flips.
      final actionsFinder = find.descendant(
        of: cardFinder,
        matching: find.byIcon(Icons.more_vert),
      );
      expect(actionsFinder, findsOneWidget);
      Visibility actionsVisibility() => tester.widget<Visibility>(
        find
            .ancestor(of: actionsFinder, matching: find.byType(Visibility))
            .first,
      );
      expect(actionsVisibility().visible, isFalse);

      await hoverOver(tester, cardFinder);

      expect(actionsVisibility().visible, isTrue);

      // Tapping the card itself (not the actions button) opens it via the
      // card-morph overlay.
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: overlayFinder(),
          matching: find.text('No tasks in this project yet.'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('deleting a project also deletes its tasks', (tester) async {
    await pumpApp(tester);

    await createProject(tester, 'Kitchen Remodel');
    await tester.tap(find.text('Kitchen Remodel'));
    await tester.pumpAndSettle();

    await createTaskInOverlay(tester, 'Pick tiles');
    expect(
      find.descendant(of: overlayFinder(), matching: find.text('Pick tiles')),
      findsOneWidget,
    );

    // Back to the projects list, then delete the project via hover + the
    // card's actions menu.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    final cardFinder = find.ancestor(
      of: find.text('Kitchen Remodel'),
      matching: find.byType(ProjectCard),
    );
    await hoverOver(tester, cardFinder);

    await tapProjectCardAction(tester, cardFinder, Icons.delete_outline);
    // Confirm the "Delete project?" dialog.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Kitchen Remodel'), findsNothing);
    expect(find.text('Pick tiles'), findsNothing);
  });

  testWidgets('favoriting a project surfaces it in the sidebar', (
    tester,
  ) async {
    await pumpApp(tester);

    await createProject(tester, 'Star Me');
    final cardFinder = find.ancestor(
      of: find.text('Star Me'),
      matching: find.byType(ProjectCard),
    );
    await hoverOver(tester, cardFinder);

    await tester.tap(
      find.descendant(of: cardFinder, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorite'));
    await tester.pumpAndSettle();

    // The sidebar's Favorites section now has a nav item for it — that's a
    // second "Star Me" on screen (the card, plus the sidebar row).
    expect(find.text('Star Me'), findsNWidgets(2));
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

    // Well short of the available main-content width (window minus the
    // sidebar and grid padding) — a full-width stretch would come within a
    // few px of it.
    expect(cardWidth, lessThan(windowWidth - 232 - 32 - 100));
  });

  testWidgets(
    "the toolbar's New project button stays flush against the right edge on resize",
    (tester) async {
      await pumpApp(tester);

      Future<double> rightGapAt(double width) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpAndSettle();
        return width - tester.getTopRight(find.text('New project')).dx;
      }

      final narrowGap = await rightGapAt(1000);
      final wideGap = await rightGapAt(1800);

      // A Flexible search field competing for flex space with a separate
      // Spacer (rather than one Expanded owning all the leftover space) let
      // this drift away from the edge as the window widened — regression
      // coverage for that.
      expect(wideGap, closeTo(narrowGap, 0.5));

      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );

  testWidgets('Settings > Wipe All Data clears everything without restart', (
    tester,
  ) async {
    await pumpApp(tester);

    await createProject(tester, 'ToWipe');
    expect(find.text('ToWipe'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Scoped to the Settings screen's own scroll view: the sidebar's mini
    // calendar is a GridView, which builds a Scrollable of its own even
    // with NeverScrollableScrollPhysics, so an unscoped find.byType(Scrollable)
    // would match two.
    await tester.scrollUntilVisible(
      find.text('Wipe all data'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('settings-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Wipe all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wipe everything'));
    await tester.pumpAndSettle();

    // Scoped to the sidebar: the Settings screen's own "default landing
    // screen" control also has a "Projects" option label on-screen here.
    await tester.tap(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Projects'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ToWipe'), findsNothing);
    expect(find.textContaining('No unfiled tasks'), findsOneWidget);
  });
}
