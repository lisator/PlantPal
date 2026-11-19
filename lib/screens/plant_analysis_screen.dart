import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/my_plant.dart';
import '../services/cloudinary_service.dart';
import '../services/database_service.dart';
import '../services/plant_api_service.dart';
import '../theme/plantpal_colors.dart';

import 'home_screen.dart';
import 'my_plants_screen.dart';
import 'plant_camera_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, this.targetPlant});

  final MyPlant? targetPlant;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final List<XFile> _selectedImages = [];
  final List<Uint8List> _imageBytesList = [];

  static const int _maxImages = 5;

  late Future<List<_RecentAnalysisItem>> _recentAnalyses;

  bool _isAnalyzing = false;
  bool _isSaving = false;

  String? _scientificName;
  String? _commonName;
  double? _confidence;
  String? _healthStatus;
  String? _errorMessage;

  List<Map<String, dynamic>> _healthIssues = [];
  List<String> _recommendedCare = [];

  // Theme colors
  Color get _background => PlantPalColors.background(context);
  Color get _card => PlantPalColors.card(context);
  Color get _text => PlantPalColors.text(context);
  Color get _secondary => PlantPalColors.secondaryText(context);
  Color get _accent => PlantPalColors.accent(context);
  Color get _border => PlantPalColors.border(context);
  Color get _soft => PlantPalColors.softBackground(context);
  bool get _isDark => PlantPalColors.isDark(context);

  @override
  void initState() {
    super.initState();
    _recentAnalyses = _loadRecentAnalyses();
  }

  // Load recent analyses from saved plants.
  Future<List<_RecentAnalysisItem>> _loadRecentAnalyses() async {
    final userId = currentUserId();
    if (userId == null) return [];

    final database = DatabaseService();
    final plants = await database.getMyPlants(userId).first;
    final recent = <_RecentAnalysisItem>[];

    for (final plant in plants) {
      final snapshot = await database
          .getPlantAnalyses(userId: userId, plantId: plant.id)
          .first;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['analyzedAt'] as Timestamp?;

        recent.add(
          _RecentAnalysisItem(
            plant: plant,
            plantName: plant.displayName,
            imageUrl: data['imageUrl'] as String?,
            healthStatus: data['healthStatus']?.toString() ?? 'Unknown',
            analyzedAt: timestamp?.toDate(),
          ),
        );
      }
    }

    recent.sort((a, b) {
      final aDate = a.analyzedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.analyzedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return recent.take(3).toList();
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Gallery image selection
  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= _maxImages) {
      _message('You can select up to 5 images.');
      return;
    }

    try {
      final picker = ImagePicker();

      if (source == ImageSource.gallery) {
        final images = await picker.pickMultiImage();

        if (!mounted || images.isEmpty) return;

        final remaining = _maxImages - _selectedImages.length;
        final imagesToAdd = images.take(remaining).toList();
        final bytesToAdd = <Uint8List>[];

        for (final image in imagesToAdd) {
          bytesToAdd.add(await image.readAsBytes());
        }

        if (!mounted) return;

        setState(() {
          _selectedImages.addAll(imagesToAdd);
          _imageBytesList.addAll(bytesToAdd);
          _clearResults();
        });

        if (images.length > remaining) {
          _message('Only the first $remaining images were added.');
        }
      } else {
        final image = await picker.pickImage(source: ImageSource.camera);

        if (image == null) return;

        final bytes = await image.readAsBytes();
        if (!mounted) return;

        setState(() {
          _selectedImages.add(image);
          _imageBytesList.add(bytes);
          _clearResults();
        });
      }
    } catch (e) {
      _message('Unable to select picture: $e');
    }
  }

  // Open the custom PlantPal camera.
  Future<void> _openPlantCamera() async {
    if (_selectedImages.length >= _maxImages) {
      _message('You can select up to 5 images.');
      return;
    }

    try {
      final image = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(builder: (context) => const PlantCameraScreen()),
      );

      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedImages.add(image);
        _imageBytesList.add(bytes);
        _clearResults();
      });
    } catch (e) {
      _message('Unable to open the camera: $e');
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

  void _resetAnalysis() {
    setState(() {
      _selectedImages.clear();
      _imageBytesList.clear();
      _clearResults();
    });
  }

  // Analyze the selected plant pictures.
  Future<void> _analyzePlant() async {
    if (_imageBytesList.isEmpty || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _clearResults();
    });

    try {
      final response = await PlantApiService().identifyPlant(
        imageBytesList: _imageBytesList,
      );

      final result = response['result'] as Map<String, dynamic>;
      final classification = result['classification'] as Map<String, dynamic>;

      final suggestions = classification['suggestions'] as List;

      if (suggestions.isEmpty) {
        throw StateError('No plant identification was returned.');
      }

      final firstSuggestion = suggestions.first as Map<String, dynamic>;

      final scientificName = firstSuggestion['name'].toString();

      final confidence = (firstSuggestion['probability'] as num).toDouble();

      final plantDetails = firstSuggestion['details'] as Map<String, dynamic>?;

      final commonNames = (plantDetails?['common_names'] as List?) ?? [];

      final commonName = commonNames.isNotEmpty
          ? commonNames.first.toString()
          : null;

      final isHealthy = (result['is_healthy'] as Map)['binary'] as bool;

      final diseaseSuggestions =
          ((result['disease'] as Map?)?['suggestions'] as List?) ?? [];

      final healthIssues = diseaseSuggestions.take(3).map((issue) {
        final issueMap = issue as Map<String, dynamic>;

        return <String, dynamic>{
          'name': issueMap['name'].toString(),
          'probability': (issueMap['probability'] as num).toDouble(),
        };
      }).toList();

      List<String> recommendedCare = [];

      if (diseaseSuggestions.isNotEmpty) {
        final topIssue = diseaseSuggestions.first as Map<String, dynamic>;

        final details = topIssue['details'] as Map<String, dynamic>?;

        final treatment = details?['treatment'] as Map<String, dynamic>?;

        if (treatment != null) {
          final biological = (treatment['biological'] as List?) ?? [];

          final chemical = (treatment['chemical'] as List?) ?? [];

          final prevention = (treatment['prevention'] as List?) ?? [];

          recommendedCare = [
            ...biological.map((item) => item.toString()),
            ...chemical.map((item) => item.toString()),
            ...prevention.map((item) => item.toString()),
          ].take(5).toList();
        }
      }

      if (!mounted) return;

      setState(() {
        _scientificName = scientificName;
        _commonName = commonName;
        _confidence = confidence;
        _healthStatus = isHealthy ? 'Healthy' : 'Possible health issue';
        _healthIssues = healthIssues;
        _recommendedCare = recommendedCare;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _clearResults();
        _errorMessage = 'Unable to analyze plant: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  // Save the current analysis under a particular plant.
  Future<void> _storeAnalysis({
    required String userId,
    required String plantId,
    required String imageUrl,
  }) async {
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
  }

  // Create a new saved plant from the analysis.
  Future<void> _createNewPlant() async {
    final userId = currentUserId();

    if (userId == null) {
      _message('Please sign in to save plants.');
      return;
    }

    if (_scientificName == null ||
        _healthStatus == null ||
        _selectedImages.isEmpty ||
        _isSaving) {
      return;
    }

    final nicknameController = TextEditingController();
    final locationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New Plant'),
        content: SingleChildScrollView(
          child: Column(
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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

    setState(() => _isSaving = true);

    try {
      final imageUrl = await CloudinaryService().uploadImage(
        _selectedImages.first,
      );

      final plantId = 'analysis_${DateTime.now().millisecondsSinceEpoch}';

      final plant = MyPlant.fromAnalysis(
        id: plantId,
        commonName: _commonName ?? _scientificName!,
        scientificName: _scientificName!,
        imageUrl: imageUrl,
        nickname: nicknameController.text,
        location: locationController.text,
      );

      await DatabaseService().addMyPlant(userId: userId, plant: plant);

      await _storeAnalysis(
        userId: userId,
        plantId: plantId,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      _message('${plant.displayName} was added to My Plants.');

      _resetAnalysis();

      setState(() {
        _recentAnalyses = _loadRecentAnalyses();
      });
    } catch (e) {
      debugPrint('Save plant error: $e');
      _message('Could not save plant. Try again.');
    } finally {
      nicknameController.dispose();
      locationController.dispose();

      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Save a health check to the plant opened from My Plants.
  Future<void> _saveToTargetPlant() async {
    final targetPlant = widget.targetPlant;
    final userId = currentUserId();

    if (targetPlant == null || userId == null) return;

    if (_scientificName == null ||
        _healthStatus == null ||
        _selectedImages.isEmpty ||
        _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final imageUrl = await CloudinaryService().uploadImage(
        _selectedImages.first,
      );

      await _storeAnalysis(
        userId: userId,
        plantId: targetPlant.id,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Save target plant analysis error: $e');

      _message('Could not save analysis. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Save analysis to a plant selected from My Plants.
  Future<void> _saveToExistingPlant() async {
    final userId = currentUserId();

    if (userId == null) {
      _message('Please sign in to save analyses.');
      return;
    }

    if (_scientificName == null ||
        _healthStatus == null ||
        _selectedImages.isEmpty ||
        _isSaving) {
      return;
    }

    try {
      final plants = await DatabaseService().getMyPlants(userId).first;

      if (!mounted) return;

      if (plants.isEmpty) {
        _message('You do not have any saved plants yet.');
        return;
      }

      final selectedPlant = await showDialog<MyPlant>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save to Existing Plant'),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: ListView.separated(
              itemCount: plants.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final plant = plants[index];

                return ListTile(
                  leading: plant.imageUrl != null && plant.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            plant.imageUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                const Icon(Icons.local_florist),
                          ),
                        )
                      : const Icon(Icons.local_florist),
                  title: Text(plant.displayName),
                  subtitle: Text(plant.scientificName),
                  onTap: () => Navigator.pop(dialogContext, plant),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedPlant == null || !mounted) return;

      setState(() => _isSaving = true);

      final imageUrl = await CloudinaryService().uploadImage(
        _selectedImages.first,
      );

      await _storeAnalysis(
        userId: userId,
        plantId: selectedPlant.id,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      _message('Analysis saved to ${selectedPlant.displayName}.');

      _resetAnalysis();

      setState(() {
        _recentAnalyses = _loadRecentAnalyses();
      });
    } catch (e) {
      debugPrint('Save existing analysis error: $e');
      _message('Could not save analysis. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _recentImagePlaceholder() {
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      color: _soft,
      child: Icon(Icons.local_florist, color: _accent, size: 30),
    );
  }

  String _formatRecentDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  // Recent analyses use colors that work in both themes.
  Widget _buildRecentAnalyses() {
    return FutureBuilder<List<_RecentAnalysisItem>>(
      future: _recentAnalyses,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: _accent),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Unable to load recent analyses.',
            style: TextStyle(color: _secondary),
          );
        }

        final analyses = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Recent Analyses'),
            const SizedBox(height: 6),
            Text(
              'Your latest saved plant health checks.',
              style: TextStyle(color: _secondary),
            ),
            const SizedBox(height: 14),

            if (analyses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.eco_outlined, size: 36, color: _accent),
                    const SizedBox(height: 8),
                    Text(
                      'No saved analyses yet.',
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analyze a plant to start tracking its health.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _secondary),
                    ),
                  ],
                ),
              )
            else
              ...analyses.map((analysis) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    color: _card,
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: _border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => openMyPlantDetails(context, analysis.plant),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child:
                                  analysis.imageUrl != null &&
                                      analysis.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      analysis.imageUrl!,
                                      width: 62,
                                      height: 62,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          _recentImagePlaceholder(),
                                    )
                                  : _recentImagePlaceholder(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    analysis.plantName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    analysis.healthStatus,
                                    style: TextStyle(
                                      color: analysis.healthStatus == 'Healthy'
                                          ? (_isDark
                                                ? PlantPalColors.darkAccent
                                                : const Color(0xFF3B7D44))
                                          : (_isDark
                                                ? Colors.orangeAccent
                                                : Colors.orange.shade800),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (analysis.analyzedAt != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatRecentDate(analysis.analyzedAt!),
                                      style: TextStyle(
                                        color: _secondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: _accent),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _heading(String title) {
    return Text(
      title,
      style: TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.bold),
    );
  }

  // Show selected images before analyzing.
  Widget _buildSelectedImages() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _imageBytesList.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
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
    );
  }

  Widget _buildResultImages() {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _imageBytesList.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
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
    );
  }

  Widget _buildIdentificationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scientificName!,
                  style: TextStyle(
                    color: _text,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_commonName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _commonName!,
                    style: TextStyle(color: _secondary, fontSize: 16),
                  ),
                ],
              ],
            ),
          ),
          if (_confidence != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '${(_confidence! * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: _text, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthStatus() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(
            _healthStatus == 'Healthy'
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            color: _healthStatus == 'Healthy'
                ? _accent
                : (_isDark ? Colors.orangeAccent : Colors.orange.shade800),
            size: 32,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _healthStatus!,
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_healthStatus != 'Healthy') ...[
                  const SizedBox(height: 3),
                  Text(
                    'Your plant shows signs of stress.',
                    style: TextStyle(color: _secondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIssues() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Detected Issues'),
        const SizedBox(height: 12),
        ..._healthIssues.map((issue) {
          final probability = (issue['probability'] as num).toDouble();

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _soft,
                  child: Icon(Icons.eco, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    issue['name'].toString(),
                    style: TextStyle(color: _text, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(probability * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecommendedCare() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Suggested Treatment'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: _recommendedCare.map((care) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, color: _accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        care,
                        style: TextStyle(
                          color: _text,
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
    );
  }

  // Save buttons for new plants, existing plants,
  // or a plant opened from My Plants.
  Widget _buildSaveButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Save Analysis'),
        const SizedBox(height: 5),
        Text(
          'Save this analysis to My Plants to track '
          'your plant\'s health over time.',
          style: TextStyle(color: _secondary, fontSize: 14),
        ),
        const SizedBox(height: 16),

        if (widget.targetPlant != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveToTargetPlant,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                'Save Analysis to ${widget.targetPlant!.displayName}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PlantPalColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          )
        else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _createNewPlant,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create New Plant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PlantPalColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _saveToExistingPlant,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save to Existing Plant'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 18),

        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            TextButton.icon(
              onPressed: _isSaving ? null : _resetAnalysis,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Discard'),
              style: TextButton.styleFrom(
                foregroundColor: _isDark
                    ? Colors.red.shade200
                    : Colors.red.shade700,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _resetAnalysis,
              icon: const Icon(Icons.refresh),
              label: const Text('Analyze Another'),
              style: OutlinedButton.styleFrom(foregroundColor: _accent),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _scientificName != null;

    return ColoredBox(
      color: _background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Plant Analysis',
            style: TextStyle(
              color: _text,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),

          if (!hasResults) ...[
            // Camera and gallery controls
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _openPlantCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take Picture'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload Picture'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),

            if (_imageBytesList.isEmpty) ...[
              const SizedBox(height: 28),
              _buildRecentAnalyses(),
            ],

            if (_imageBytesList.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${_imageBytesList.length} of $_maxImages photos selected',
                style: TextStyle(
                  color: _secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildSelectedImages(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzePlant,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.eco),
                  label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Plant'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],

          // Analysis errors
          if (_errorMessage != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF4B2929) : Colors.red.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: _isDark ? Colors.red.shade200 : Colors.red.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: _isDark
                            ? Colors.red.shade100
                            : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Analysis results
          if (hasResults) ...[
            if (_imageBytesList.isNotEmpty) _buildResultImages(),

            const SizedBox(height: 18),

            _buildIdentificationCard(),

            const SizedBox(height: 16),

            if (_healthStatus != null) _buildHealthStatus(),

            if (_healthIssues.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildHealthIssues(),
            ],

            if (_recommendedCare.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildRecommendedCare(),
            ],

            const SizedBox(height: 28),

            _buildSaveButtons(),

            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }
}

class _RecentAnalysisItem {
  const _RecentAnalysisItem({
    required this.plant,
    required this.plantName,
    required this.imageUrl,
    required this.healthStatus,
    required this.analyzedAt,
  });

  final MyPlant plant;
  final String plantName;
  final String? imageUrl;
  final String healthStatus;
  final DateTime? analyzedAt;
}
