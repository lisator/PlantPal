import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  bool _isPosting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final String title =
        _titleController.text.trim();

    final String description =
        _descriptionController.text.trim();

    if (title.isEmpty ||
        description.isEmpty) {
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

    final User? user =
        FirebaseAuth.instance.currentUser;

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
      await _databaseService.addPost(
        userId: user.uid,
        userEmail: user.email ?? '',
        title: title,
        description: description,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Post created successfully!',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
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
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Post Title',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller:
                  _titleController,
              maxLength: 100,
              decoration:
                  const InputDecoration(
                hintText:
                    'Enter a title',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller:
                  _descriptionController,
              maxLines: 5,
              maxLength: 1000,
              decoration:
                  const InputDecoration(
                hintText:
                    'Tell everyone about your plant...',
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed:
                    _isPosting
                        ? null
                        : _createPost,
                icon:
                    const Icon(
                  Icons.send,
                ),
                label: Text(
                  _isPosting
                      ? 'Posting...'
                      : 'Post',
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: TextButton(
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
            ),
          ],
        ),
      ),
    );
  }
}