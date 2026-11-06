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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _databaseService = DatabaseService();
  final _cloudinaryService = CloudinaryService();
  final _imagePicker = ImagePicker();

  final List<XFile> _selectedImages = [];

  bool _isPosting = false;
  bool _isSelectingImage = false;
  bool _showPhotoTips = true;

  static const int _maxPhotos = 5;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  static const Color _forest = Color(0xFF315F43);
  static const Color _sage = Color(0xFF83AD8A);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

  bool get _busy => _isPosting || _isSelectingImage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // Check file size and basic image format.
  // We never reject a photo for its lighting or subject.
  Future<bool> _validateImage(XFile image) async {
    try {
      final size = await image.length();

      if (size == 0 || size > _maxImageBytes) {
        _showMessage(
          'Each picture must be larger than 0 bytes '
          'and no more than 10 MB.',
        );
        return false;
      }

      final extension = image.name.split('.').last.toLowerCase();

      const allowed = {'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp'};

      if (!allowed.contains(extension)) {
        _showMessage('Choose a JPG, PNG, HEIC, HEIF, or WebP picture.');
        return false;
      }

      return true;
    } catch (e) {
      _showMessage('Unable to check this picture: $e');
      return false;
    }
  }

  // Add photos to the existing selection.
  Future<void> _addSelectedImages(List<XFile> images) async {
    var added = 0;
    var skipped = 0;

    for (final image in images) {
      if (!mounted) return;

      if (_selectedImages.length >= _maxPhotos) {
        skipped++;
        continue;
      }

      if (_selectedImages.any((selected) => selected.path == image.path)) {
        skipped++;
        continue;
      }

      if (!await _validateImage(image)) {
        skipped++;
        continue;
      }

      if (!mounted) return;

      setState(() {
        _selectedImages.add(image);
      });

      added++;
    }

    if (skipped > 0) {
      _showMessage(
        'Added $added picture(s). Some were skipped. '
        'You can use up to 5 pictures.',
      );
    }
  }

  // Choose multiple photos from the gallery.
  Future<void> _pickImageFromGallery() async {
    if (_busy) return;

    if (_selectedImages.length >= _maxPhotos) {
      _showMessage('You already have 5 pictures.');
      return;
    }

    setState(() => _isSelectingImage = true);

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
        setState(() => _isSelectingImage = false);
      }
    }
  }

  // Show a preview after taking a photo.
  // The user can accept it, retake it, or cancel.
  Future<String?> _reviewCapturedPhoto(XFile image) async {
    final bytes = await image.readAsBytes();

    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('How does your picture look?'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) {
                        return const Text('Unable to display the preview.');
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can use this picture even if '
                  'the lighting is not perfect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _ink, fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'retake'),
              icon: const Icon(Icons.refresh),
              label: const Text('Retake'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'use'),
              icon: const Icon(Icons.check),
              label: const Text('Use Photo'),
            ),
          ],
        );
      },
    );
  }

  // Take photos using the Community camera flow.
  Future<void> _takePhoto() async {
    if (_busy) return;

    if (_selectedImages.length >= _maxPhotos) {
      _showMessage('You can add up to 5 pictures per post.');
      return;
    }

    setState(() => _isSelectingImage = true);

    try {
      bool takingPhoto = true;

      while (takingPhoto && mounted) {
        // Mobile opens the native camera.
        // Web support depends on the browser/device.
        final image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1600,
        );

        if (!mounted || image == null) break;

        if (!await _validateImage(image)) break;
        if (!mounted) break;

        final decision = await _reviewCapturedPhoto(image);

        if (!mounted) break;

        if (decision == 'use') {
          await _addSelectedImages([image]);
          takingPhoto = false;
        } else if (decision == 'retake') {
          // Open the camera again.
          takingPhoto = true;
        } else {
          takingPhoto = false;
        }
      }
    } catch (e) {
      _showMessage(
        'Could not open the camera. '
        'Check camera permissions or use Gallery. $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isSelectingImage = false);
      }
    }
  }

  void _removeImage(int index) {
    if (_busy) return;

    if (index < 0 || index >= _selectedImages.length) {
      return;
    }

    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Open a selected picture larger for inspection.
  Future<void> _openPhotoPreview(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(dialogContext).height * 0.75,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showMessage('Could not open picture: $e');
    }
  }

  // Upload photos to Cloudinary and save the post.
  Future<void> _createPost() async {
    if (_busy) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      _showMessage('Please enter a title and description.');
      return;
    }

    if (title.length > 100) {
      _showMessage('Title cannot exceed 100 characters.');
      return;
    }

    if (description.length > 1000) {
      _showMessage('Description cannot exceed 1000 characters.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please sign in to create a post.');
      return;
    }

    setState(() => _isPosting = true);

    try {
      final imageUrls = <String>[];

      for (final image in _selectedImages) {
        if (!await _validateImage(image)) {
          return;
        }

        final imageUrl = await _cloudinaryService.uploadImage(image);

        if (imageUrl.trim().isEmpty) {
          throw StateError('An image upload failed.');
        }

        imageUrls.add(imageUrl);
      }

      await _databaseService.addPost(
        userId: user.uid,
        userEmail: user.email ?? '',
        title: title,
        description: description,
        imageUrl: imageUrls.isEmpty ? '' : imageUrls.first,
        imageUrls: imageUrls,
      );

      if (!mounted) return;

      _showMessage('Post created successfully!');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Unable to create post: $e');
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  // Preview one selected photo.
  Widget _selectedPhotoCard(int index) {
    final image = _selectedImages[index];

    return Container(
      key: ValueKey(image.path),
      width: 150,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _pale,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _mint),
      ),
      child: Column(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openPhotoPreview(image),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FutureBuilder<Uint8List>(
                  future: image.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Icon(Icons.broken_image_outlined, color: _sage),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: _forest),
                      );
                    }

                    return Image.memory(
                      snapshot.data!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Photo ${index + 1}',
            style: const TextStyle(color: _forest, fontWeight: FontWeight.bold),
          ),
          TextButton.icon(
            onPressed: _busy ? null : () => _removeImage(index),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // Photo previews.
  Widget _imagePreview() {
    if (_selectedImages.isEmpty) {
      return Container(
        height: 170,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _pale,
          border: Border.all(color: _sage),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: _forest, size: 48),
            SizedBox(height: 10),
            Text(
              'Add up to 5 pictures',
              style: TextStyle(color: _forest, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Take a photo or select from your gallery.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedImages.length} of 5 photos selected',
          style: const TextStyle(color: _forest, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 215,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) => _selectedPhotoCard(index),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Tap a photo to enlarge it. Swipe to see more.',
          style: TextStyle(fontSize: 12, color: _ink),
        ),
      ],
    );
  }

  // Optional tips; nothing is automatically rejected.
  Widget _photoTips() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _pale,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _mint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: _forest),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Optional Photo Tips',
                  style: TextStyle(color: _forest, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Hide photo tips',
                onPressed: () {
                  setState(() => _showPhotoTips = false);
                },
                icon: const Icon(Icons.close, size: 19),
              ),
            ],
          ),
          const Text(
            '• Try moving closer to a window for more light.\n'
            '• Hold the camera steady for a clearer picture.\n'
            '• Tap the screen to focus if your camera supports it.\n'
            '• You can post any picture you like, even '
            'if the lighting is not perfect.',
            style: TextStyle(color: _ink, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _photoSection() {
    return Container(
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
              Icon(Icons.camera_alt_outlined, color: _forest),
              SizedBox(width: 8),
              Text(
                'Community Photos',
                style: TextStyle(
                  color: _forest,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Share your plants, your garden, or anything '
            'you want to show the Community.',
            style: TextStyle(color: _ink),
          ),
          const SizedBox(height: 16),

          if (_showPhotoTips) ...[
            _photoTips(),
            const SizedBox(height: 16),
          ] else ...[
            TextButton.icon(
              onPressed: () {
                setState(() => _showPhotoTips = true);
              },
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Show Photo Tips'),
            ),
          ],

          _imagePreview(),
          const SizedBox(height: 12),

          const Text(
            'Up to 5 pictures, 10 MB each. Photos are optional.',
            style: TextStyle(fontSize: 12, color: _ink),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _takePhoto,
                  style: FilledButton.styleFrom(
                    backgroundColor: _forest,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),

          if (kIsWeb) ...[
            const SizedBox(height: 10),
            const Text(
              'On Chrome, the Camera button may open a '
              'file picker depending on browser support.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _ink),
            ),
          ],

          if (_isSelectingImage) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator(color: _forest)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: _forest),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: _forest),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _mint),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _forest, width: 2),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _pale,
        appBar: AppBar(
          title: const Text(
            'Create Post',
            style: TextStyle(color: _forest, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: _pale,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _mint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.spa_outlined, color: _forest, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                'Share a picture, a growing tip, '
                                'or a question with the Community.',
                                style: TextStyle(color: _ink),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

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
                        const SizedBox(height: 14),
                        TextField(
                          controller: _titleController,
                          enabled: !_isPosting,
                          maxLength: 100,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Post Title',
                            hintText: 'What would you like to share?',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descriptionController,
                          enabled: !_isPosting,
                          maxLength: 1000,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Tell the Community about your post...',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  _photoSection(),
                  const SizedBox(height: 20),

                  if (_isPosting) ...[
                    const Center(
                      child: CircularProgressIndicator(color: _forest),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Uploading photos and sharing your post...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _forest),
                    ),
                    const SizedBox(height: 12),
                  ],

                  FilledButton.icon(
                    onPressed: _busy ? null : _createPost,
                    style: FilledButton.styleFrom(
                      backgroundColor: _forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      _isPosting ? 'Posting...' : 'Share Post',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
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
