
import 'package:flutter/material.dart';

class PostPhotoGallery extends StatefulWidget {
  final List<String> imageUrls;

  const PostPhotoGallery({
    super.key,
    required this.imageUrls,
  });

  @override
  State<PostPhotoGallery> createState() =>
      _PostPhotoGalleryState();
}

class _PostPhotoGalleryState extends State<PostPhotoGallery> {
  static const Color _forest = Color(0xFF315F43);
  static const Color _mint = Color(0xFFE0EBDD);

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.imageUrls
        .where((url) => url.trim().isNotEmpty)
        .toList();

    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 12),

        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: double.infinity,
            height: 250,
            child: PageView.builder(
              itemCount: images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FullScreenPhotoViewer(
                          images: images,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    color: _mint,
                    child: Image.network(
                      images[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;

                        return const Center(
                          child: CircularProgressIndicator(
                            color: _forest,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: _forest,
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        if (images.length > 1) ...[
          const SizedBox(height: 10),

          Text(
            '${_currentIndex + 1} of ${images.length}',
            style: const TextStyle(
              color: _forest,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

// Opens a picture in full screen.
// Users can swipe, zoom in, zoom out, and close it.
class FullScreenPhotoViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenPhotoViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenPhotoViewer> createState() =>
      _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState
    extends State<FullScreenPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;

    _pageController = PageController(
      initialPage: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} of ${widget.images.length}',
        ),
        actions: [
          IconButton(
            tooltip: 'Close picture',
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;

                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      'Unable to load picture.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// Supports older posts that store only imageUrl,
// and newer posts that store an imageUrls list.
List<String> postImageUrls(Map<String, dynamic> data) {
  final rawImages = data['imageUrls'];

  if (rawImages is List) {
    final urls = rawImages
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList();

    if (urls.isNotEmpty) return urls;
  }

  final oldImageUrl = data['imageUrl'];

  if (oldImageUrl is String && oldImageUrl.isNotEmpty) {
    return [oldImageUrl];
  }

  return [];
}
