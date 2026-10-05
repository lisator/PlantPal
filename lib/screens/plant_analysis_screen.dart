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

      setState(() {
        _result =
            '$plantName - ${(probability * 100).toStringAsFixed(1)}%';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
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
      ],
    );
  }
}