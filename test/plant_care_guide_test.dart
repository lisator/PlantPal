import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/perenual_models.dart';
import 'package:plantpal/services/wikipedia_service.dart';
import 'package:plantpal/widgets/plant_care_guide.dart';

void main() {
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

  testWidgets('says when neither source has a topic', (tester) async {
    await tester.pumpWidget(page(Future.value(noWikipediaExtras)));
    await tester.pump();

    expect(find.text('Details not available yet.'), findsOneWidget);
  });
}
