import 'package:flutter_test/flutter_test.dart';
import 'package:flutternewspaper_frontend/main.dart';

void main() {
  testWidgets('Home screen renders app title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('News App'), findsOneWidget);
  });

  testWidgets('Tab titles render', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('business'), findsOneWidget);
    expect(find.text('entertainment'), findsOneWidget);
    expect(find.text('science'), findsOneWidget);
    expect(find.text('sports'), findsOneWidget);
    expect(find.text('technology'), findsOneWidget);
    expect(find.text('health'), findsOneWidget);
  });
}
