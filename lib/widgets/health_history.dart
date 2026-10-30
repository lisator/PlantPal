import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/database_service.dart';

class HealthHistory extends StatelessWidget {
  const HealthHistory({
    super.key,
    required this.userId,
    required this.plantId,
  });

  final String userId;
  final String plantId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health History',
          style: Theme.of(context).textTheme.headlineSmall,
        ),

        const SizedBox(height: 6),

        Text(
          'Saved plant analyses appear here so you can track '
          'changes in your plant\'s health over time.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
        ),

        const SizedBox(height: 16),

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
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
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
                  _AnalysisCard(
                    data: analyses[i].data(),
                    isLatest: i == 0,
                  ),
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

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.data,
    required this.isLatest,
  });

  final Map<String, dynamic> data;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final status = data['healthStatus']?.toString() ?? 'Unknown';

    final confidence =
        (data['confidence'] as num?)?.toDouble();

    final timestamp =
        data['analyzedAt'] as Timestamp?;

    final issues =
        (data['issues'] as List?)
                ?.whereType<Map>()
                .map(
                  (item) => Map<String, dynamic>.from(item),
                )
                .toList() ??
            [];

    final care =
        (data['recommendedCare'] as List?)
                ?.map(
                  (item) => item.toString(),
                )
                .toList() ??
            [];

    final imageUrl =
        data['imageUrl'] as String?;

    final healthy =
        status == 'Healthy';

    final dateText = timestamp == null
        ? 'Unknown date'
        : _formatDate(timestamp.toDate());

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 155,
              fit: BoxFit.cover,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return Container(
                  height: 155,
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.local_florist,
                    size: 50,
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: healthy
                ? const Color(0xFFE4F3DF)
                : const Color(0xFFFFEDBC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                healthy
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: healthy
                    ? const Color(0xFF3B7D44)
                    : Colors.orange.shade800,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (confidence != null) ...[
          const SizedBox(height: 10),
          Text(
            'Identification confidence: '
            '${(confidence * 100).toStringAsFixed(1)}%',
          ),
        ],

        if (issues.isNotEmpty) ...[
          const SizedBox(height: 14),

          Text(
            'Detected Issues',
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.eco_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      issue['name']?.toString() ??
                          'Unknown issue',
                    ),
                  ),
                  if (issue['probability'] is num)
                    Text(
                      '${(((issue['probability'] as num).toDouble()) * 100).toStringAsFixed(1)}%',
                    ),
                ],
              ),
            ),
        ],

        if (care.isNotEmpty) ...[
          const SizedBox(height: 14),

          Text(
            'Suggested Treatment',
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          for (final item in care)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF4F7C56),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item),
                  ),
                ],
              ),
            ),
        ],
      ],
    );

    if (isLatest) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F3DF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Latest Analysis',
                  style: TextStyle(
                    color: Color(0xFF315D3A),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                dateText,
                style: Theme.of(context).textTheme.titleMedium,
              ),

              details,
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        title: Text(
          dateText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(status),
        leading: Icon(
          healthy
              ? Icons.check_circle_outline
              : Icons.warning_amber_rounded,
          color: healthy
              ? const Color(0xFF3B7D44)
              : Colors.orange.shade800,
        ),
        children: [
          details,
        ],
      ),
    );
  }
}
class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

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