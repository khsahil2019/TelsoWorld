// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telsoworld/core/services/theme_service.dart';
import 'package:telsoworld/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App builds and shows splash', (WidgetTester tester) async {
    final themeService = ThemeService();
    // Build our app and trigger a frame.
    await tester.pumpWidget(TelsoWorldRootApp(themeService: themeService));

    // Verify that the splash screen renders the Telso World branding.
    expect(find.text('TELSO WORLD'), findsOneWidget);
  });
}
