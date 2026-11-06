
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

  // Store up to five selected pictures.
  final List<XFile> _selectedImages = [];

  bool _isPosting = false;
  bool _isSelectingImage = false;

  static const int _maxPhotos = 5;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  // PlantPal colors.
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

  // Show a message to the user.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Check that a picture is not too large.
  Future<bool> _validateImage(XFile image) async {
    try {
      final size = await image.length();

      if (size == 0) {
        _showMessage('This picture is empty.');
        return false;
      }

      if (size > _maxImageBytes) {
        _showMessage(
          'Each picture must be 10 MB or smaller.',
        );
        return false;
      }

      final extension =
          image.name.split('.').last.toLowerCase();

      const allowed = {
        'jpg',
        'jpeg',
        'png',
        'heic',
        'heif',
        'webp',
      };

      if (!allowed.contains(extension)) {
        _showMessage(
          'Please choose a JPG, PNG, HEIC, HEIF, or WebP picture.',
        );
        return false;
      }

      return true;
    } catch (e) {
      _showMessage('Unable to check the selected picture.');
      return false;
    }
  }

  // Add selected pictures without exceeding five.
  Future<void> _addSelectedImages(List<XFile> images) async {
    int added = 0;
    int skipped = 0;

    for (final image in images) {
      if (!mounted) return;

      if (_selectedImages.length >= _maxPhotos) {
        skipped++;
        continue;
      }

      // Avoid adding the same selected file twice.
      final alreadySelected = _selectedImages.any(
        (selected) => selected.path == image.path,
      );

      if (alreadySelected) {
        skipped++;
        continue;
      }

      final valid = await _validateImage(image);

      if (!valid || !mounted) {
        skipped++;
        continue;
      }

      setState(() {
        _selectedImages.add(image);
      });

      added++;
    }

    if (skipped > 0) {
      _showMessage(
        'Added $added photo(s). Some pictures were skipped. '
        'You can add up to 5 valid pictures.',
      );
    }
  }

  // Select multiple pictures from the gallery.
  Future<void> _pickImageFromGallery() async {
    if (_isPosting || _isSelectingImage) return;

    if (_selectedImages.length >= _maxPhotos) {
      _showMessage('You can add up to 5 pictures per post.');
      return;
    }

    setState(() {
      _isSelectingImage = true;
    });

    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (!mounted || images.isEmpty) return;

      await _addSelectedImages(images);
    } catch (e) {
      _showMessage('Unable to select pictures: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingImage = false;
        });
      }
    }
  }

  // Take one picture using the device camera.
  Future<void> _takePhoto() async {
    if (_isPosting || _isSelectingImage) return;

    if (_selectedImages.length >= _maxPhotos) {
      _showMessage('You can add up to 5 pictures per post.');
      return;
    }

    if (kIsWeb) {
      _showMessage(
        'Camera capture should be tested on the mobile app.',
      );
      return;
    }

    setState(() {
      _isSelectingImage = true;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null || !mounted) return;

      await _addSelectedImages([image]);
    } catch (e) {
      _showMessage('Unable to open camera: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingImage = false;
        });
      }
    }
  }

  // Remove one picture from the selection.
  void _removeImage(int index) {
    if (_isPosting || _isSelectingImage) return;

    if (index < 0 || index >= _selectedImages.length) {
      return;
    }

    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Upload all pictures and save the post.
  Future<void> _createPost() async {
    if (_isPosting || _isSelectingImage) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      _showMessage('Please enter a title and description.');
      return;
    }

    if (title.length > 100) {
      _showMessage(
        'Title cannot be longer than 100 characters.',
      );
      return;
    }

    if (description.length > 1000) {
      _showMessage(
        'Description cannot be longer than 1000 characters.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('You must be logged in to create a post.');
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      // Store the uploaded Cloudinary URLs.
      final imageUrls = <String>[];

      // Upload one picture at a time.
      for (final image in _selectedImages) {
        final valid = await _validateImage(image);

        if (!valid) return;

        final imageUrl =
            await _cloudinaryService.uploadImage(image);

        if (imageUrl.trim().isEmpty) {
          throw StateError('A picture could not be uploaded.');
        }

        imageUrls.add(imageUrl);
      }

      // Save every picture with the post.
      await _databaseService.addPost(
        userId: user.uid,
        userEmail: user.email ?? '',
        title: title,
        description: description,
        imageUrl: imageUrls.isNotEmpty
            ? imageUrls.first
            : '',
        imageUrls: imageUrls,
      );

      if (!mounted) return;

      _showMessage('Post created successfully!');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Unable to create post: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  // Show one selected picture with a remove button.
  Widget _selectedPhotoCard(int index) {
    final image = _selectedImages[index];

    return Container(
      key: ValueKey(image.path),
      width: 145,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _pale,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _mint),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FutureBuilder<Uint8List>(
                future: image.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _sage,
                        size: 36,
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _forest,
                      ),
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Photo ${index + 1}',
            style: const TextStyle(
              color: _forest,
              fontWeight: FontWeight.w600,
            ),
          ),

          TextButton.icon(
            onPressed: _isPosting || _isSelectingImage
                ? null
                : () => _removeImage(index),
            icon: const Icon(
              Icons.close,
              size: 16,
              color: _forest,
            ),
            label: const Text(
              'Remove',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Preview all selected pictures.
  Widget _imagePreview() {
    if (_selectedImages.isEmpty) {
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
              'Add up to 5 pictures of your plants',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _forest,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Choose pictures from your gallery or camera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedImages.length} of $_maxPhotos pictures selected',
          style: const TextStyle(
            color: _forest,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 215,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return _selectedPhotoCard(index);
            },
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Swipe sideways to preview your selected pictures.',
          style: TextStyle(
            color: _ink,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Photo selection section.
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
                'Plant Photos',
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
            'Share up to 5 pictures with the PlantPal Community.',
            style: TextStyle(
              color: _ink,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 16),

          _imagePreview(),

          const SizedBox(height: 12),

          const Text(
            'Maximum: 5 pictures, 10 MB each.',
            style: TextStyle(
              color: _ink,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPosting || _isSelectingImage
                      ? null
                      : _pickImageFromGallery,
                  icon: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _forest,
                    side: const BorderSide(color: _sage),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPosting || _isSelectingImage
                      ? null
                      : _takePhoto,
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _forest,
                    side: const BorderSide(color: _sage),
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_isSelectingImage) ...[
            const SizedBox(height: 12),
            const Center(
              child: CircularProgressIndicator(
                color: _forest,
              ),
            ),
          ],

          if (kIsWeb) ...[
            const SizedBox(height: 10),
            const Text(
              'Camera capture is available on mobile devices.',
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
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(
            color: _forest,
          ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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

                        TextField(
                          controller: _titleController,
                          enabled: !_isPosting,
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

                        TextField(
                          controller: _descriptionController,
                          enabled: !_isPosting,
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

                  // Select and preview pictures.
                  _photoSection(),

                  const SizedBox(height: 22),

                  if (_isPosting) ...[
                    const Center(
                      child: CircularProgressIndicator(
                        color: _forest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Uploading pictures and sharing your post...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _forest),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Share Post button.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isPosting || _isSelectingImage
                          ? null
                          : _createPost,
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
                        _isPosting ? 'Posting...' : 'Share Post',
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
                    onPressed: _isPosting || _isSelectingImage
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _forest,
                      side: const BorderSide(color: _sage),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
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
