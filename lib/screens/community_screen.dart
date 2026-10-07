import 'package:flutter/material.dart';
import 'add_post_screen.dart';
import 'plantpal_app_bar.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final List<Map<String, dynamic>> posts = [];

  Future<void> openAddPostScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPostScreen(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        posts.insert(
          0,
          {
            'title': result['title'],
            'description': result['description'],
            'hasImage': result['hasImage'] ?? false,
            'liked': false,
            'saved': false,
            'likes': 0,
          },
        );
      });
    }
  }

  void toggleLike(int index) {
    setState(() {
      bool currentlyLiked = posts[index]['liked'];

      posts[index]['liked'] = !currentlyLiked;

      if (currentlyLiked) {
        posts[index]['likes']--;
      } else {
        posts[index]['likes']++;
      }
    });
  }

  void toggleSave(int index) {
    setState(() {
      posts[index]['saved'] = !posts[index]['saved'];
    });
  }

  void showCommentBox(int index) {
    final TextEditingController commentController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Comment'),

          content: TextField(
            controller: commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write a comment...',
              border: OutlineInputBorder(),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                String comment =
                    commentController.text.trim();

                if (comment.isNotEmpty) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Comment added!'),
                    ),
                  );
                }
              },
              child: const Text('Comment'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // Community menu will be added later.
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Add Post button
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Add Post screen will be connected next.
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Post'),
              ),
            ),

            const SizedBox(height: 20),

            // Empty feed message
            const Icon(
              Icons.local_florist,
              size: 70,
            ),

          const SizedBox(height: 15),

          const Text(
            'Your feed is empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

            const Text(
              'Follow some plant friends to see their posts!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
              ),
            ),

          const SizedBox(height: 25),

            ElevatedButton(
              onPressed: () {
                // Find Plant Friends will be added later.
              },
              child: const Text('Find Plant Friends'),
            ),
          ],
        ),
      ),
    );
  }
}
