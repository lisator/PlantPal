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
      appBar: const PlantPalAppBar(
        title: 'Community',
      ),

      body: Column(
        children: [
          // ADD POST BUTTON
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: openAddPostScreen,
                icon: const Icon(Icons.add),
                label: const Text('Add Post'),
              ),
            ),
          ),

          // FEED
          Expanded(
            child: posts.isEmpty
                ? buildEmptyFeed()
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 20,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return buildPostCard(index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // EMPTY FEED
  Widget buildEmptyFeed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              'Follow some plant friends or create a post to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: () {
                // Find Plant Friends screen
                // can be connected later.
              },
              child: const Text(
                'Find Plant Friends',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // POST CARD
  Widget buildPostCard(int index) {
    final post = posts[index];

    return Card(
      margin: const EdgeInsets.only(
        bottom: 20,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // USER INFORMATION
            const Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    Icons.person,
                  ),
                ),

                SizedBox(width: 10),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PlantPal User',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    Text(
                      'Just now',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 15),

            // TITLE
            Text(
              post['title'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // DESCRIPTION
            Text(
              post['description'],
              style: const TextStyle(
                fontSize: 16,
              ),
            ),

            // PICTURE
            if (post['hasImage'])
              Column(
                children: [
                  const SizedBox(height: 15),

                  Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image,
                          size: 80,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Post Picture',
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 10),

            const Divider(),

            // LIKE / COMMENT / SAVE
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    toggleLike(index);
                  },
                  icon: Icon(
                    post['liked']
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                ),

                Text(
                  '${post['likes']}',
                ),

                const SizedBox(width: 10),

                IconButton(
                  onPressed: () {
                    showCommentBox(index);
                  },
                  icon: const Icon(
                    Icons.comment_outlined,
                  ),
                ),

                const Spacer(),

                IconButton(
                  onPressed: () {
                    toggleSave(index);
                  },
                  icon: Icon(
                    post['saved']
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}