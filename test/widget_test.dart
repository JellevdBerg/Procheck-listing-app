import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procheck/data/hive_setup.dart';
import 'package:procheck/main.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('procheck_test_');
    await setUpHive(testDirectoryPath: tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('shows empty state, then a created checklist with progress', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ProcheckApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('No checklists yet'), findsOneWidget);

    // Open the "new checklist" flow from the FAB.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New checklist'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Lab safety check');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

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
}
