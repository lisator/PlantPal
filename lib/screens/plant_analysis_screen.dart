import 'package:flutter/material.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Image Upload'),
        SizedBox(height: 16),
        Text('Add plant image here'),
        SizedBox(height: 16),
        Text('Image preview will go here'),
      ],
    );
  }
}
