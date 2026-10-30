
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';
import '../services/database_service.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  final DatabaseService _databaseService = DatabaseService();

  final CloudinaryService _cloudinaryService =
      CloudinaryService();

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedImage;

  bool _isPosting = false;

  // PlantPal colors.
  // These colors only affect the Create Post screen.
  static const Color _forest = Color(0xFF315F43);
  static const Color _sage = Color(0xFF83AD8A);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Select a plant picture from the gallery.
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to select image: $e'),
        ),
      );
    }
  }

  // Take a picture using the device camera.
  Future<void> _takePhoto() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera capture should be tested on the mobile app. '
            'Chrome may open the file picker instead.',
          ),
        ),
      );

      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open camera: $e'),
        ),
      );
    }
  }

  // Remove the selected plant picture.
  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  // Upload the picture and create a Community post.
  Future<void> _createPost() async {
    final String title = _titleController.text.trim();

    final String description =
        _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a title and description.',
          ),
        ),
      );

      return;
    }

    if (title.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Title cannot be longer than 100 characters.',
          ),
        ),
      );

      return;
    }

    if (description.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Description cannot be longer than 1000 characters.',
          ),
        ),
      );

      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must be logged in to create a post.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      String imageUrl = '';

      // Upload the selected picture to Cloudinary.
      if (_selectedImage != null) {
        imageUrl = await _cloudinaryService.uploadImage(
          _selectedImage!,
        );
      }

      // Save the Community post and image URL in Firestore.
      await _databaseService.addPost(
        userId: user.uid,
        userEmail: user.email ?? '',
        title: title,
        description: description,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post created successfully!'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create post: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  // Display a preview of the picture before uploading it.
  Widget _imagePreview() {
    if (_selectedImage == null) {
      return Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _pale,
          border: Border.all(
            color: _sage,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: _forest,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'Add a photo of your plant',
              style: TextStyle(
                color: _forest,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Choose from your gallery or use your camera.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _selectedImage!.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            height: 180,
            alignment: Alignment.center,
            child: const Text(
              'Unable to preview the selected picture.',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                color: _forest,
              ),
            ),
          );
        }

        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  maxHeight: 360,
                ),
                color: _pale,
                child: Image.memory(
                  snapshot.data!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 10),

            TextButton.icon(
              onPressed: _isPosting ? null : _removeImage,
              icon: const Icon(
                Icons.delete_outline,
                color: _forest,
              ),
              label: const Text('Remove Photo'),
            ),
          ],
        );
      },
    );
  }

  // Display the photo selection area.
  Widget _photoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _mint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_florist_outlined,
                color: _forest,
              ),
              SizedBox(width: 8),
              Text(
                'Plant Photo',
                style: TextStyle(
                  color: _forest,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'Share a picture with the PlantPal Community.',
            style: TextStyle(
              color: _ink,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 16),

          _imagePreview(),

          const SizedBox(height: 16),

          // Gallery and Camera options.
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _forest,
                    side: const BorderSide(color: _sage),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isPosting
                      ? null
                      : _pickImageFromGallery,
                  icon: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  label: const Text('Gallery'),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _forest,
                    side: const BorderSide(color: _sage),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isPosting
                      ? null
                      : _takePhoto,
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),

          if (kIsWeb) ...[
            const SizedBox(height: 10),
            const Text(
              'Camera capture is available when PlantPal '
              'is run on a mobile device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _ink,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Apply the green PlantPal theme to this screen only.
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: _forest),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _sage),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _mint),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: _forest,
              width: 2,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _forest,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _pale,
        appBar: AppBar(
          title: const Text(
            'Create Post',
            style: TextStyle(
              color: _forest,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: _pale,
          surfaceTintColor: _pale,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                16, 18, 16, 30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome section.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _mint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.spa_outlined,
                          color: _forest,
                          size: 30,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Share with PlantPal!',
                                style: TextStyle(
                                  color: _forest,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Show off your plants, share a growing '
                                'tip, or ask the community a question.',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Post details.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _mint),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Post Details',
                          style: TextStyle(
                            color: _forest,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Post title.
                        TextField(
                          controller: _titleController,
                          maxLength: 100,
                          textCapitalization:
                              TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Post Title',
                            hintText:
                                'Example: Help with my Monstera',
                            prefixIcon: Icon(
                              Icons.edit_note_outlined,
                              color: _forest,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Post description.
                        TextField(
                          controller: _descriptionController,
                          maxLength: 1000,
                          maxLines: 5,
                          textCapitalization:
                              TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText:
                                'Tell the community about your plant...',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Plant picture section.
                  _photoSection(),

                  const SizedBox(height: 22),

                  // Loading message.
                  if (_isPosting) ...[
                    const Center(
                      child: CircularProgressIndicator(
                        color: _forest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sharing your post...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _forest),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Create Post button.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _forest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed:
                          _isPosting ? null : _createPost,
                      icon: _isPosting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(
                        _isPosting
                            ? 'Posting...'
                            : 'Share Post',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cancel button.
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _forest,
                      side: const BorderSide(color: _sage),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isPosting
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
