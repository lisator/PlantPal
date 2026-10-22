import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/plant_api_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  Uint8List? _imageBytes;
  String? _fileName;
  bool _isAnalyzing = false;

  String? _scientificName;
  String? _commonName;
  double? _confidence;
  String? _healthStatus;
  String? _errorMessage;

  List<Map<String, dynamic>> _healthIssues = [];
  List<String> _recommendedCare = [];

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: source,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    setState(() {
      _imageBytes = bytes;
      _fileName = image.name;

      _scientificName = null;
      _commonName = null;
      _confidence = null;
      _healthStatus = null;
      _errorMessage = null;

      _healthIssues = [];
      _recommendedCare = [];
    });
  }

  Future<void> _analyzePlant() async {
    if (_imageBytes == null) {
      return;
    }

    setState(() {
      _isAnalyzing = true;

      _scientificName = null;
      _commonName = null;
      _confidence = null;
      _healthStatus = null;
      _errorMessage = null;

      _healthIssues = [];
      _recommendedCare = [];
    });

    try {
      final plantApi = PlantApiService();

      final response = await plantApi.identifyPlant(
        imageBytes: _imageBytes!,
      );

      // -----------------------------
      // PLANT IDENTIFICATION
      // -----------------------------

      final suggestions =
          response['result']['classification']['suggestions'] as List;

      final firstSuggestion =
          suggestions.first as Map<String, dynamic>;

      final scientificName =
          firstSuggestion['name'].toString();

      final confidence =
          (firstSuggestion['probability'] as num).toDouble();

      // Common plant names
      final plantDetails =
          firstSuggestion['details'] as Map<String, dynamic>?;

      final commonNames =
          (plantDetails?['common_names'] as List?) ?? [];

      final commonName = commonNames.isNotEmpty
          ? commonNames.first.toString()
          : null;

      // -----------------------------
      // HEALTH STATUS
      // -----------------------------

      final isHealthy =
          response['result']['is_healthy']['binary'] as bool;

      final diseaseSuggestions =
          (response['result']['disease']['suggestions'] as List?) ?? [];

      // Top 3 possible health issues
      final healthIssues =
          diseaseSuggestions.take(3).map<Map<String, dynamic>>((issue) {
        final issueMap =
            issue as Map<String, dynamic>;

        return {
          'name': issueMap['name'].toString(),
          'probability':
              (issueMap['probability'] as num).toDouble(),
        };
      }).toList();

      // -----------------------------
      // SUGGESTED TREATMENT
      // -----------------------------

      List<String> recommendedCare = [];

      if (diseaseSuggestions.isNotEmpty) {
        final topIssue =
            diseaseSuggestions.first as Map<String, dynamic>;

        final issueDetails =
            topIssue['details'] as Map<String, dynamic>?;

        final treatment =
            issueDetails?['treatment'] as Map<String, dynamic>?;

        if (treatment != null) {
          final biological =
              (treatment['biological'] as List?) ?? [];

          final chemical =
              (treatment['chemical'] as List?) ?? [];

          final prevention =
              (treatment['prevention'] as List?) ?? [];

          recommendedCare = [
            ...biological.map((item) => item.toString()),
            ...chemical.map((item) => item.toString()),
            ...prevention.map((item) => item.toString()),
          ].take(5).toList();
        }
      }

      // -----------------------------
      // SAVE RESULTS
      // -----------------------------

      setState(() {
        _scientificName = scientificName;
        _commonName = commonName;
        _confidence = confidence;

        _healthStatus =
            isHealthy ? 'Healthy' : 'Possible health issue';

        _healthIssues = healthIssues;
        _recommendedCare = recommendedCare;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to analyze plant: $e';

        _scientificName = null;
        _commonName = null;
        _confidence = null;
        _healthStatus = null;

        _healthIssues = [];
        _recommendedCare = [];
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasResults = _scientificName != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ============================================================
        // PAGE TITLE
        // ============================================================

        const Text(
          'Plant Analysis',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F4D2E),
          ),
        ),

        const SizedBox(height: 18),

        // ============================================================
        // BEFORE ANALYSIS
        // Take Picture / Upload Picture / Preview / Analyze
        // ============================================================

        if (!hasResults) ...[
          Row(
            children: [
              // TAKE PICTURE
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _pickImage(ImageSource.camera),
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  label: const Text(
                    'Take Picture',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // UPLOAD PICTURE
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _pickImage(ImageSource.gallery),
                  icon: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  label: const Text(
                    'Upload Picture',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ------------------------------------------------------------
          // SELECTED IMAGE
          // ------------------------------------------------------------

          if (_imageBytes != null) ...[
            const SizedBox(height: 16),

            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.memory(
                _imageBytes!,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 16),

            // ----------------------------------------------------------
            // ANALYZE BUTTON
            // ----------------------------------------------------------

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isAnalyzing ? null : _analyzePlant,

                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.eco,
                      ),

                label: Text(
                  _isAnalyzing
                      ? 'Analyzing...'
                      : 'Analyze Plant',
                ),

                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],

        // ============================================================
        // ERROR MESSAGE
        // ============================================================

        if (_errorMessage != null) ...[
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade700,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ============================================================
        // AFTER ANALYSIS
        // Photo + Plant + Health + Treatment + Save Options
        // ============================================================

        if (hasResults) ...[
          // ------------------------------------------------------------
          // RESULT IMAGE
          // ------------------------------------------------------------

          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.memory(
                _imageBytes!,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          const SizedBox(height: 16),

          // ============================================================
          // PLANT IDENTIFICATION CARD
          // ============================================================

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7EC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scientificName!,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F4D2E),
                        ),
                      ),

                      if (_commonName != null) ...[
                        const SizedBox(height: 4),

                        Text(
                          _commonName!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (_confidence != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDEBD5),
                      borderRadius:
                          BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.eco,
                          size: 18,
                          color: Color(0xFF315D3A),
                        ),

                        const SizedBox(width: 5),

                        Text(
                          '${(_confidence! * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF315D3A),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ============================================================
          // HEALTH STATUS
          // ============================================================

          if (_healthStatus != null)
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: _healthStatus == 'Healthy'
                    ? const Color(0xFFE4F3DF)
                    : const Color(0xFFFFEDBC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    _healthStatus == 'Healthy'
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    color: _healthStatus == 'Healthy'
                        ? const Color(0xFF3B7D44)
                        : Colors.orange.shade800,
                    size: 32,
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _healthStatus!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        if (_healthStatus !=
                            'Healthy') ...[
                          const SizedBox(height: 3),

                          const Text(
                            'Your plant shows signs of stress.',
                            style: TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ============================================================
          // DETECTED ISSUES
          // ============================================================

          if (_healthIssues.isNotEmpty) ...[
            const SizedBox(height: 24),

            const Text(
              'Detected Issues',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F4D2E),
              ),
            ),

            const SizedBox(height: 12),

            ..._healthIssues.map((issue) {
              final double probability =
                  issue['probability'] as double;

              return Container(
                margin:
                    const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(8),
                      decoration:
                          const BoxDecoration(
                        color: Color(0xFFE4F0DF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: Color(0xFF4F7C56),
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        issue['name'].toString(),
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),

                    Text(
                      '${(probability * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ============================================================
          // SUGGESTED TREATMENT
          // ============================================================

          if (_recommendedCare.isNotEmpty) ...[
            const SizedBox(height: 24),

            const Text(
              'Suggested Treatment',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F4D2E),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F0DF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children:
                    _recommendedCare.map((care) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding:
                              EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons
                                .check_circle_outline,
                            color:
                                Color(0xFF4F7C56),
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            care,
                            style:
                                const TextStyle(
                              fontSize: 15.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // ============================================================
          // SAVE ANALYSIS
          // ============================================================

          const SizedBox(height: 28),

          const Text(
            'Save Analysis',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F4D2E),
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Save this analysis to My Plants to track your plant\'s health over time.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 16),

          // ------------------------------------------------------------
          // CREATE NEW PLANT
          // ------------------------------------------------------------

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Temporary placeholder.
                // We'll connect this to My Plants next.

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Create New Plant will be connected to My Plants.',
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.add_circle_outline,
              ),
              label: const Text(
                'Create New Plant',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF315D3A),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ------------------------------------------------------------
          // SAVE TO EXISTING PLANT
          // ------------------------------------------------------------

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // Temporary placeholder.
                // We'll connect this to the user's
                // existing plants next.

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Save to Existing Plant will be connected to My Plants.',
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.bookmark_add_outlined,
              ),
              label: const Text(
                'Save to Existing Plant',
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ============================================================
          // DISCARD / ANALYZE ANOTHER
          // ============================================================

          Row(
            children: [
              // DISCARD
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _imageBytes = null;
                      _fileName = null;

                      _scientificName = null;
                      _commonName = null;
                      _confidence = null;
                      _healthStatus = null;
                      _errorMessage = null;

                      _healthIssues = [];
                      _recommendedCare = [];
                    });
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                  label: const Text(
                    'Discard',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Colors.red.shade700,
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // ANALYZE ANOTHER
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _imageBytes = null;
                      _fileName = null;

                      _scientificName = null;
                      _commonName = null;
                      _confidence = null;
                      _healthStatus = null;
                      _errorMessage = null;

                      _healthIssues = [];
                      _recommendedCare = [];
                    });
                  },
                  icon: const Icon(
                    Icons.refresh,
                  ),
                  label: const Text(
                    'Analyze Another',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),
        ],
      ],
    );
  }
}