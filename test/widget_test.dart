import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drive_for_women/main.dart';

void main() {
  testWidgets('Drive for Women app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DriveForWomenApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
