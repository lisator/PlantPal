import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';
import 'widgets/reusable_widgets.dart';
import 'services/plant_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform != TargetPlatform.linux) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const PlantPalApp());
}

class PlantPalApp extends StatelessWidget {
  const PlantPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantPal',
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    MyPlantsScreen(),
    UploadScreen(),
    PlantSearch(),
    CommunityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlantPal'),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (value) {
          setState(() {
            _selectedIndex = value;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist),
            label: 'My Plants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Plant Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Community',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Dashboard'),
        SizedBox(height: 16),
        Text('PlantPal home page'),
        SizedBox(height: 16),
        Text('Stats go here'),
      ],
    );
  }
}

class MyPlantsScreen extends StatelessWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('My Plants'),
        SizedBox(height: 16),
        Text('Plant 1'),
        Text('Plant 2'),
        Text('Plant 3'),
      ],
    );
  }
}

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

class PlantSearch extends StatelessWidget {
  const PlantSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Plant Search'),
        SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Search for a plant',
            border: OutlineInputBorder(),
          ),
          child: TextField(),
        ),
      ],
    );
  }
}

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Community'),
        SizedBox(height: 16),
        Text('Post 1'),
        Text('Post 2'),
        Text('Post 3'),
      ],
    );
  }
}