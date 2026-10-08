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
  String? _result;
  String? _healthStatus;
  List<String> _healthIssues = [];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    setState(() {
      _imageBytes = bytes;
      _fileName = image.name;
      _result = null;
      _healthStatus = null;
      _healthIssues = [];
    });
  }

  Future<void> _analyzePlant() async {
    if (_imageBytes == null) {
      return;
    }

    const apiKey = String.fromEnvironment('PLANT_API_KEY');

    if (apiKey.isEmpty) {
      setState(() {
        _result = 'API key was not provided.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
      _healthStatus = null;
      _healthIssues = [];
    });

    try {
      final plantApi = PlantApiService();

      final response = await plantApi.identifyPlant(
        apiKey: apiKey,
        imageBytes: _imageBytes!,
      );

      final suggestions =
          response['result']['classification']['suggestions'];

      final firstSuggestion = suggestions[0];

      final plantName = firstSuggestion['name'];
      final probability = firstSuggestion['probability'];

      final isHealthy =
          response['result']['is_healthy']['binary'];

      final diseaseSuggestions =
          (response['result']['disease']['suggestions'] as List?) ?? [];

      final healthIssues = diseaseSuggestions.take(3).map((issue) {
        final name = issue['name'];
        final probability = issue['probability'];

        return '$name - ${(probability * 100).toStringAsFixed(1)}%';
      }).toList();

      setState(() {
        _result =
          '$plantName - ${(probability * 100).toStringAsFixed(1)}%';

        _healthStatus =
          isHealthy ? 'Healthy' : 'Possible health issue';

        _healthIssues = healthIssues;
      });

    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _healthStatus = null;
        _healthIssues = [];
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Image Upload',
          style: TextStyle(fontSize: 24),
        ),

        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: _pickImage,
          child: const Text('Choose Plant Image'),
        ),

        const SizedBox(height: 16),

        if (_fileName != null)
          Text('Selected image: $_fileName'),

        const SizedBox(height: 16),

        if (_imageBytes != null)
          Image.memory(
            _imageBytes!,
            height: 300,
            fit: BoxFit.contain,
          ),

        const SizedBox(height: 16),

        if (_imageBytes != null)
          ElevatedButton(
            onPressed: _isAnalyzing ? null : _analyzePlant,
            child: Text(
              _isAnalyzing
                  ? 'Analyzing...'
                  : 'Analyze Plant',
            ),
          ),

        const SizedBox(height: 16),

        if (_result != null)
          Text(
            _result!,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

        const SizedBox(height: 16),

        if (_healthStatus != null)
          Text(
            'Health Status: $_healthStatus',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

        const SizedBox(height: 8),

        if (_healthIssues.isNotEmpty)
          ..._healthIssues.map(
            (issue) => Text(
              '• $issue',
              style: const TextStyle(fontSize: 16),
            ),
          ),
      ],
    );
  }
}