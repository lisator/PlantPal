import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plantpal/main.dart';
import 'package:plantpal/screens/home_screen.dart';

void main() {
  // Tests can't reach Firebase, so run the app the way it runs on Linux
  // desktop: no Firebase, straight to the home screen.
  testWidgets('PlantPal app loads the home screen without Firebase',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    try {
      await tester.pumpWidget(PlantPalApp(preferences: preferences));
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('PlantPal'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
