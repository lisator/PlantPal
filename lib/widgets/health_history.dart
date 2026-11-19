import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/plantpal_colors.dart';

// Displays the saved health analyses for a plant.
class HealthHistory extends StatelessWidget {
  const HealthHistory({
    super.key,
    required this.userId,
    required this.plantId,
    this.onRunAnalysis,
  });

  final String userId;
  final String plantId;
  final VoidCallback? onRunAnalysis;

  @override
  Widget build(BuildContext context) {
    final textColor = PlantPalColors.text(context);
    final secondaryColor = PlantPalColors.secondaryText(context);
    final accentColor = PlantPalColors.accent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Health History heading.
        Text(
          'Health History',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: textColor, fontWeight: FontWeight.bold),
        ),

        // Button to start another health analysis.
        if (onRunAnalysis != null) ...[
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRunAnalysis,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Run New Health Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PlantPalColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],

        const SizedBox(height: 6),

        // Description works in light and dark mode.
        Text(
          'Saved plant analyses appear here so you can track '
          'changes in your plant\'s health over time.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: secondaryColor),
        ),

        const SizedBox(height: 16),

        // Retrieve saved analyses from Firebase.
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: DatabaseService().getPlantAnalyses(
            userId: userId,
            plantId: plantId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _MessageCard(
                message: 'Could not load health history.',
              );
            }

            if (!snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: accentColor),
                ),
              );
            }

            final analyses = snapshot.data!.docs;

            if (analyses.isEmpty) {
              return const _MessageCard(
                message:
                    'No health analyses have been saved for this plant yet.',
              );
            }

            return Column(
              children: [
                for (var i = 0; i < analyses.length; i++) ...[
                  _AnalysisCard(data: analyses[i].data(), isLatest: i == 0),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// Individual saved analysis card.
class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.data, required this.isLatest});

  final Map<String, dynamic> data;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final isDark = PlantPalColors.isDark(context);

    final cardColor = PlantPalColors.card(context);
    final textColor = PlantPalColors.text(context);
    final secondaryColor = PlantPalColors.secondaryText(context);
    final borderColor = PlantPalColors.border(context);
    final accentColor = PlantPalColors.accent(context);
    final softColor = PlantPalColors.softBackground(context);

    // Read health analysis information.
    final status = data['healthStatus']?.toString() ?? 'Unknown';

    final confidence = (data['confidence'] as num?)?.toDouble();

    final timestamp = data['analyzedAt'] as Timestamp?;

    final issues =
        (data['issues'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        [];

    final care =
        (data['recommendedCare'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        [];

    final imageUrl = data['imageUrl'] as String?;

    final healthy = status == 'Healthy';

    final dateText = timestamp == null
        ? 'Unknown date'
        : _formatDate(timestamp.toDate());

    // Health status colors for light and dark mode.
    final statusBackground = healthy
        ? (isDark ? const Color(0xFF294A36) : const Color(0xFFE4F3DF))
        : (isDark ? const Color(0xFF51402A) : const Color(0xFFFFEDBC));

    final statusTextColor = healthy
        ? (isDark ? const Color(0xFFB8EBC3) : const Color(0xFF285D36))
        : (isDark ? const Color(0xFFFFD18A) : const Color(0xFF805000));

    final statusIconColor = healthy
        ? (isDark ? const Color(0xFF9BD5AD) : const Color(0xFF3B7D44))
        : (isDark ? const Color(0xFFFFC36B) : Colors.orange.shade800);

    // Expandable analysis details.
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Saved health analysis photo.
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          const SizedBox(height: 10),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _FullScreenImage(imageUrl: imageUrl),
                ),
              );
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 155,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 155,
                        color: softColor,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.local_florist,
                          size: 50,
                          color: accentColor,
                        ),
                      );
                    },
                  ),
                ),

                // Zoom icon on the photo.
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Healthy or possible health issue.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                healthy
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: statusIconColor,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Identification confidence.
        if (confidence != null) ...[
          const SizedBox(height: 10),

          Text(
            'Identification confidence: '
            '${(confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(color: secondaryColor),
          ),
        ],

        // Detected health issues.
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 14),

          Text(
            'Detected Issues',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 8),

          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.eco_outlined, size: 18, color: accentColor),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      issue['name']?.toString() ?? 'Unknown issue',
                      style: TextStyle(color: textColor),
                    ),
                  ),

                  if (issue['probability'] is num)
                    Text(
                      '${((issue['probability'] as num).toDouble() * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: secondaryColor),
                    ),
                ],
              ),
            ),
        ],

        // Suggested treatment.
        if (care.isNotEmpty) ...[
          const SizedBox(height: 14),

          Text(
            'Suggested Treatment',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 8),

          for (final item in care)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: accentColor,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: textColor, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );

    // Main card with expand/collapse functionality.
    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        backgroundColor: cardColor,
        collapsedBackgroundColor: cardColor,

        iconColor: accentColor,
        collapsedIconColor: secondaryColor,

        textColor: textColor,
        collapsedTextColor: textColor,

        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

        title: Row(
          children: [
            Expanded(
              child: Text(
                dateText,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),

            // Latest analysis label.
            if (isLatest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Latest',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),

        subtitle: Text(status, style: TextStyle(color: secondaryColor)),

        leading: Icon(
          healthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          color: statusIconColor,
        ),

        children: [details],
      ),
    );
  }
}

// Full-screen preview of a saved health analysis photo.
class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Health Analysis Photo'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Unable to load image.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Message displayed when health history is empty or fails.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: PlantPalColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: PlantPalColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: PlantPalColors.secondaryText(context)),
        ),
      ),
    );
  }
}

// Format the saved analysis date.
String _formatDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[date.month - 1]} '
      '${date.day}, ${date.year}';
}
