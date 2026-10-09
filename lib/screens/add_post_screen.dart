import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../services/database_service.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() =>
      _AddPostScreenState();
}

class _AddPostScreenState
    extends State<AddPostScreen> {
  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController
      _descriptionController =
      TextEditingController();

  final DatabaseService _databaseService =
      DatabaseService();

  final CloudinaryService _cloudinaryService =
      CloudinaryService();

  final ImagePicker _imagePicker =
      ImagePicker();

  XFile? _selectedImage;

  bool _isPosting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to select image: $e',
          ),
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Camera capture should be tested on the mobile app. Chrome may open the file picker instead.',
          ),
        ),
      );

      return;
    }

    try {
      final XFile? image =
          await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open camera: $e',
          ),
        ),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _createPost() async {
    final String title =
        _titleController.text.trim();

    final String description =
        _descriptionController.text.trim();

    if (title.isEmpty ||
        description.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a title and description.',
          ),
        ),
      );

      return;
    }

    if (title.length > 100) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Title cannot be longer than 100 characters.',
          ),
        ),
      );

      return;
    }

    if (description.length > 1000) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Description cannot be longer than 1000 characters.',
          ),
        ),
      );

      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
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

      if (_selectedImage != null) {
        imageUrl =
            await _cloudinaryService
                .uploadImage(
          _selectedImage!,
        );
      }

      await _databaseService.addPost(
        userId: user.uid,
        userEmail:
            user.email ?? '',
        title: title,
        description: description,
        imageUrl: imageUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Post created successfully!',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to create post: $e',
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Create Post'),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller:
                  _titleController,
              maxLength: 100,
              decoration:
                  const InputDecoration(
                labelText:
                    'Post Title',
                hintText:
                    'Example: Help with my plant',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            TextField(
              controller:
                  _descriptionController,
              maxLength: 1000,
              maxLines: 5,
              decoration:
                  const InputDecoration(
                labelText:
                    'Description',
                hintText:
                    'Tell the community about your plant...',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'Plant Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            if (_selectedImage != null)
              FutureBuilder<Uint8List>(
                future:
                    _selectedImage!
                        .readAsBytes(),
                builder: (
                  context,
                  snapshot,
                ) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child:
                            CircularProgressIndicator(),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                        child: Container(
                          width:
                              double.infinity,
                          constraints:
                              const BoxConstraints(
                            maxHeight:
                                400,
                          ),
                          child:
                              Image.memory(
                            snapshot.data!,
                            width:
                                double.infinity,
                            fit:
                                BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      TextButton.icon(
                        onPressed:
                            _removeImage,
                        icon:
                            const Icon(
                          Icons
                              .delete_outline,
                        ),
                        label:
                            const Text(
                          'Remove Photo',
                        ),
                      ),
                    ],
                  );
                },
              ),

            if (_selectedImage == null)
              Container(
                height: 180,
                decoration:
                    BoxDecoration(
                  border:
                      Border.all(
                    color:
                        Colors.grey,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
                child:
                    const Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: [
                      Icon(
                        Icons
                            .local_florist,
                        size: 50,
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      Text(
                        'No plant photo selected',
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(
              height: 15,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton
                          .icon(
                    onPressed:
                        _isPosting
                            ? null
                            : _pickImageFromGallery,
                    icon:
                        const Icon(
                      Icons
                          .photo_library,
                    ),
                    label:
                        const Text(
                      'Gallery',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      OutlinedButton
                          .icon(
                    onPressed:
                        _isPosting
                            ? null
                            : _takePhoto,
                    icon:
                        const Icon(
                      Icons
                          .camera_alt,
                    ),
                    label:
                        const Text(
                      'Camera',
                    ),
                  ),
                ),
              ],
            ),

            if (kIsWeb) ...[
              const SizedBox(
                height: 8,
              ),
              const Text(
                'Camera capture is available when PlantPal is run on a mobile device.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Colors.grey,
                ),
              ),
            ],

            const SizedBox(
              height: 30,
            ),

            ElevatedButton(
              onPressed:
                  _isPosting
                      ? null
                      : _createPost,
              child: _isPosting
                  ? const Padding(
                      padding:
                          EdgeInsets.all(
                        8,
                      ),
                      child:
                          CircularProgressIndicator(),
                    )
                  : const Text(
                      'Post',
                    ),
            ),

            const SizedBox(
              height: 12,
            ),

            OutlinedButton(
              onPressed:
                  _isPosting
                      ? null
                      : () {
                          Navigator.pop(
                            context,
                          );
                        },
              child:
                  const Text(
                'Cancel',
              ),
            ),
          ],
        ),
      ),
    );
  }
}