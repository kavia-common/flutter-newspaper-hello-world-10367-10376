import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutternewspaper_frontend/main.dart' as app;

void main() {
  testWidgets('App launches and shows home title', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.text('News App'), findsOneWidget);
  });

  testWidgets('Tabs are visible', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('business'), findsOneWidget);
    expect(find.text('entertainment'), findsOneWidget);
    expect(find.text('science'), findsOneWidget);
    expect(find.text('sports'), findsOneWidget);
    expect(find.text('technology'), findsOneWidget);
    expect(find.text('health'), findsOneWidget);
  });

  testWidgets('Saved button is present', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
  });
}
