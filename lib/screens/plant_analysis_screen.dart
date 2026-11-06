import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/plant_api_service.dart';

import '../models/my_plant.dart';
import '../services/cloudinary_service.dart';
import '../services/database_service.dart';
import 'home_screen.dart';
import 'plant_camera_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final List<XFile> _selectedImages = [];
  final List<Uint8List> _imageBytesList = [];

  static const int _maxImages = 5;

  //String? _fileName;
  bool _isAnalyzing = false;

  bool _isSaving = false;

  String? _scientificName;
  String? _commonName;
  double? _confidence;
  String? _healthStatus;
  String? _errorMessage;

  List<Map<String, dynamic>> _healthIssues = [];
  List<String> _recommendedCare = [];

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();

    if (_selectedImages.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can select up to 5 images.'),
        ),
      );
      return;
    }

    if (source == ImageSource.gallery) {
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isEmpty) {
        return;
      }

      final remainingSlots =
          _maxImages - _selectedImages.length;

      final imagesToAdd =
          images.take(remainingSlots).toList();

      final bytesToAdd = <Uint8List>[];

      for (final image in imagesToAdd) {
        bytesToAdd.add(await image.readAsBytes());
      }

      setState(() {
        _selectedImages.addAll(imagesToAdd);
        _imageBytesList.addAll(bytesToAdd);

        _clearResults();
      });

      if (images.length > remainingSlots && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Only the first 5 images were added.',
            ),
          ),
        );
      }
    } else {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      setState(() {
        _selectedImages.add(image);
        _imageBytesList.add(bytes);

        _clearResults();
      });
    }
  }

    void _clearResults() {
    _scientificName = null;
    _commonName = null;
    _confidence = null;
    _healthStatus = null;
    _errorMessage = null;

    _healthIssues = [];
    _recommendedCare = [];
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageBytesList.removeAt(index);

      _clearResults();
    });
  }
  
  Future<void> _openPlantCamera() async {
    if (_selectedImages.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can select up to 5 images.'),
        ),
      );
      return;
    }

    final XFile? image = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        builder: (context) => const PlantCameraScreen(),
      ),
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    setState(() {
      _selectedImages.add(image);
      _imageBytesList.add(bytes);

      _clearResults();
    });
  }

  Future<void> _analyzePlant() async {
    if (_imageBytesList.isEmpty) {
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
        imageBytesList: _imageBytesList,
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

  void _resetAnalysis() {
  setState(() {
    _selectedImages.clear();
    _imageBytesList.clear();
    //_fileName = null;

    _scientificName = null;
    _commonName = null;
    _confidence = null;
    _healthStatus = null;
    _errorMessage = null;

    _healthIssues = [];
    _recommendedCare = [];
  });
}

Future<void> _createNewPlant() async {
  final userId = currentUserId();

  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in to save plants.'),
      ),
    );
    return;
  }

  if (_scientificName == null ||
      _healthStatus == null ||
      _selectedImages.isEmpty) {
    return;
  }

  final nicknameController = TextEditingController();
  final locationController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create New Plant'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nicknameController,
            decoration: const InputDecoration(
              labelText: 'Nickname (optional)',
              hintText: 'e.g. Monty',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: locationController,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              hintText: 'e.g. Living room',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (result != true || !mounted) {
    nicknameController.dispose();
    locationController.dispose();
    return;
  }

  setState(() {
    _isSaving = true;
  });

  try {
    final imageUrl =
        await CloudinaryService().uploadImage(_selectedImages.first);

    final plantId =
        'analysis_${DateTime.now().millisecondsSinceEpoch}';

    final plant = MyPlant.fromAnalysis(
      id: plantId,
      commonName: _commonName ?? _scientificName!,
      scientificName: _scientificName!,
      imageUrl: imageUrl,
      nickname: nicknameController.text,
      location: locationController.text,
    );

    await DatabaseService().addMyPlant(
      userId: userId,
      plant: plant,
    );

    await DatabaseService().addPlantAnalysis(
      userId: userId,
      plantId: plantId,
      scientificName: _scientificName!,
      commonName: _commonName,
      confidence: _confidence,
      healthStatus: _healthStatus!,
      issues: _healthIssues,
      recommendedCare: _recommendedCare,
      imageUrl: imageUrl,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${plant.displayName} was added to My Plants.',
        ),
      ),
    );

    _resetAnalysis();
  } catch (e) {
    debugPrint('Save plant error: $e');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save plant. Try again.'),
        ),
      );
    }
  } finally {
    nicknameController.dispose();
    locationController.dispose();

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }
}

Future<void> _saveToExistingPlant() async {
  final userId = currentUserId();

  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in to save analyses.'),
      ),
    );
    return;
  }

  if (_scientificName == null ||
      _healthStatus == null ||
      _selectedImages.isEmpty) {
    return;
  }

  try {
    final plants =
        await DatabaseService().getMyPlants(userId).first;

    if (!mounted) return;

    if (plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You do not have any saved plants yet.',
          ),
        ),
      );
      return;
    }

    final selectedPlant = await showDialog<MyPlant>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save to Existing Plant'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: plants.length,
            separatorBuilder: (context, index) =>
                const Divider(),
            itemBuilder: (context, index) {
              final plant = plants[index];

              return ListTile(
                leading: plant.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          plant.imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) =>
                                  const Icon(
                            Icons.local_florist,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.local_florist,
                      ),
                title: Text(
                  plant.displayName,
                ),
                subtitle: Text(
                  plant.scientificName,
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                    plant,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedPlant == null || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final imageUrl =
        await CloudinaryService().uploadImage(
      _selectedImages.first);

    await DatabaseService().addPlantAnalysis(
      userId: userId,
      plantId: selectedPlant.id,
      scientificName: _scientificName!,
      commonName: _commonName,
      confidence: _confidence,
      healthStatus: _healthStatus!,
      issues: _healthIssues,
      recommendedCare: _recommendedCare,
      imageUrl: imageUrl,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Analysis saved to ${selectedPlant.displayName}.',
        ),
      ),
    );

    _resetAnalysis();
  } catch (e) {
    debugPrint(
      'Save existing plant analysis error: $e',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save analysis. Try again.',
          ),
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
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
                  onPressed: _openPlantCamera,
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

          if (_imageBytesList.isNotEmpty) ...[
              const SizedBox(height: 16),

              Text(
                '${_imageBytesList.length} of $_maxImages photos selected',
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageBytesList.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            _imageBytesList[index],
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),

                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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

          if (_imageBytesList.isNotEmpty)
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imageBytesList.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      _imageBytesList[index],
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),

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
              onPressed: _isSaving
                  ? null
                  : _createNewPlant,
              icon: const Icon(
                Icons.add_circle_outline,
              ),
              label: const Text(
                'Create New Plant',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF315D3A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
              onPressed: _isSaving
                ? null
                : _saveToExistingPlant,

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
                  onPressed: _resetAnalysis,
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
                  onPressed: _resetAnalysis,
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