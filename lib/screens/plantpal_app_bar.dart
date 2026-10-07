import 'package:flutter/material.dart';

class PlantPalAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const PlantPalAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,

      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () {
                Navigator.pop(context);
              },
            )
          : null,

      title: Text(title),

      centerTitle: true,

      actions: [
        IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () {
            // Your navigation menu can be connected here later.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Menu will be added here.'),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}