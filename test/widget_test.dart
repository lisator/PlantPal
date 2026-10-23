import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plantpal/main.dart';
import 'package:plantpal/screens/home_screen.dart';

void main() {
  // Tests can't reach Firebase, so run the app the way it runs on Linux
  // desktop: no Firebase, straight to the home screen.
  testWidgets('PlantPal app loads the home screen without Firebase',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(const PlantPalApp());
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('PlantPal'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
