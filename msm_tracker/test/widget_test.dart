// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:msm_tracker/src/app.dart';
import 'package:msm_tracker/src/storage/storage.dart';
import 'package:msm_tracker/src/utils/timezone_init.dart';
import 'dart:io';

void main() {
  setUpAll(() async {
    ensureTimezonesInitialized();
    final dir = await Directory.systemTemp.createTemp('msm_tracker_test_');
    Hive.init(dir.path);
    await Storage.init();
  });

  testWidgets('Home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MsmTrackerApp());
    await tester.pumpAndSettle();
    expect(find.text('MSM Tracker'), findsOneWidget);
  });
}
