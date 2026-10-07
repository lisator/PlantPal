import 'package:flutter/material.dart';
import 'plantpal_app_bar.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController =
      TextEditingController();

  bool hasImage = false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void createPost() {
    String title = titleController.text.trim();
    String description = descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title.'),
        ),
      );

      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description.'),
        ),
      );

      return;
    }

    // Send the post information back to CommunityScreen.
    Navigator.pop(
      context,
      {
        'title': title,
        'description': description,
        'hasImage': hasImage,
      },
    );
  }

  void choosePicture() {
    // Actual gallery access will be added later.

    setState(() {
      hasImage = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Picture selected. Gallery access will be connected later.',
        ),
      ),
    );
  }

  void takePicture() {
    // Actual camera access will be added later.

    setState(() {
      hasImage = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Picture added. Camera access will be connected later.',
        ),
      ),
    );
  }

  void removePicture() {
    setState(() {
      hasImage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PlantPalAppBar(
        title: 'Create Post',
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE
            const Text(
              'Post Title',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Enter a title for your post',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            // DESCRIPTION
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: descriptionController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Tell everyone about your plant...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            // PICTURE SECTION
            const Text(
              'Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // IMAGE PREVIEW PLACEHOLDER
            if (hasImage)
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image,
                      size: 70,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Picture Preview',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            if (hasImage)
              const SizedBox(height: 12),

            // UPLOAD PICTURE
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: choosePicture,
                icon: const Icon(Icons.photo_library),
                label: const Text('Upload Picture'),
              ),
            ),

            const SizedBox(height: 10),

            // TAKE PICTURE
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Picture'),
              ),
            ),

            // REMOVE PICTURE
            if (hasImage)
              Column(
                children: [
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: removePicture,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove Picture'),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 30),

            // POST BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: createPost,
                icon: const Icon(Icons.send),
                label: const Text('Post'),
              ),
            ),

            const SizedBox(height: 10),

            // CANCEL
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}