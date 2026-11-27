import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plantpal/models/perenual_models.dart';
import 'package:plantpal/services/care_ai_service.dart';
import 'package:plantpal/services/wikipedia_service.dart';
import 'package:plantpal/widgets/plant_care_guide.dart';

void main() {
  // by default gemini is "offline", so the original text shows
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CareTipsService.rewriteForTesting = (_) async => null;
  });
  tearDown(() => CareTipsService.rewriteForTesting = null);

  const details = PlantDetails(
    id: 1,
    commonName: 'Rose',
    scientificName: 'Rosa chinensis',
    watering: 'Average',
    sunlight: ['Full sun'],
  );
  const article = WikipediaSummary(
    title: 'Rosa chinensis',
    extract: 'A rose.',
    pageUrl: 'https://en.wikipedia.org/wiki/Rosa_chinensis',
  );

  Widget page(Future<WikipediaExtras> wikipedia) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlantCareGuide(details: details, wikipedia: wikipedia),
          ),
        ),
      );

  testWidgets('shows Perenual right away, then fills gaps from Wikipedia',
      (tester) async {
    final wikipedia = Completer<WikipediaExtras>();
    await tester.pumpWidget(page(wikipedia.future));

    // Perenual has water and light; soil waits for Wikipedia.
    expect(find.textContaining('Average'), findsOneWidget);
    expect(find.textContaining('Full sun'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    wikipedia.complete((
      article: article,
      care: {
        CareTopic.soil: const CareExcerpt(
          text: 'It needs well-drained soil.',
          article: article,
        ),
      },
    ));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('It needs well-drained soil.'), findsOneWidget);
  });

  testWidgets('shows a Wikipedia excerpt once when topics share it',
      (tester) async {
    const noCareDetails = PlantDetails(
      id: 2,
      commonName: 'Pink princess',
      scientificName: 'Philodendron erubescens',
    );
    const shared = CareExcerpt(
      text: 'Keep it in bright, indirect light and water when the soil is dry.',
      article: article,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PlantCareGuide(
            details: noCareDetails,
            wikipedia: Future.value((
              article: article,
              care: {
                CareTopic.water: shared,
                CareTopic.light: shared,
                CareTopic.soil: const CareExcerpt(
                  text: 'It needs well-drained soil.',
                  article: article,
                ),
              },
            )),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text(shared.text), findsOneWidget);
    expect(find.text('Water & Light'), findsOneWidget);
    expect(find.text('Soil'), findsOneWidget);
  });

  testWidgets('says when neither source has a topic', (tester) async {
    await tester.pumpWidget(page(Future.value(noWikipediaExtras)));
    await tester.pump();

    expect(find.text('Details not available yet.'), findsOneWidget);
  });

  testWidgets('swaps long care text for short tips once they are ready',
      (tester) async {
    const longDetails = PlantDetails(
      id: 3,
      commonName: 'Fern',
      scientificName: 'Nephrolepis exaltata',
      watering: 'Frequent',
      careGuide: {
        'watering': 'Ferns love moisture. Water them often so the soil stays '
            'evenly moist, but never let them sit in water.',
      },
    );
    final tips = Completer<Map<String, String>?>();
    CareTipsService.rewriteForTesting = (sources) {
      expect(sources['water'], contains('Ferns love moisture'));
      return tips.future;
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PlantCareGuide(
            details: longDetails,
            wikipedia: Future.value(noWikipediaExtras),
          ),
        ),
      ),
    ));
    await tester.pump();

    // the original text shows while gemini works
    expect(find.textContaining('Ferns love moisture'), findsOneWidget);

    tips.complete({'water': 'Keep the soil evenly moist, never soggy.'});
    await tester.pump();
    await tester.pump();

    expect(find.text('Keep the soil evenly moist, never soggy.'),
        findsOneWidget);
    expect(find.textContaining('Ferns love moisture'), findsNothing);
  });

  testWidgets('gives each topic its own tip from a shared excerpt',
      (tester) async {
    const noCareDetails = PlantDetails(
      id: 4,
      commonName: 'Snake plant',
      scientificName: 'Dracaena trifasciata',
    );
    const shared = CareExcerpt(
      text: 'It is tolerant of low light levels and irregular watering.',
      article: article,
    );
    CareTipsService.rewriteForTesting = (_) async => {
          'water': 'It handles missed waterings well.',
          'light': 'It can live in low light.',
        };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PlantCareGuide(
            details: noCareDetails,
            wikipedia: Future.value((
              article: article,
              care: {CareTopic.water: shared, CareTopic.light: shared},
            )),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('It handles missed waterings well.'), findsOneWidget);
    expect(find.text('It can live in low light.'), findsOneWidget);
    expect(find.text(shared.text), findsNothing);
    expect(find.text('Excerpt from Wikipedia'), findsNothing);
    expect(find.text('Read more on Wikipedia'), findsNWidgets(2));
  });
}
