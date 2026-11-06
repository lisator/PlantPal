
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/my_plant.dart';
import '../screens/notifications_screen.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

// Display a notification bell with an unread count.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  // PlantPal green.
  static const Color _forest = Color(0xFF315F43);

  @override
  Widget build(BuildContext context) {
    // Only show the bell when Firebase is ready
    // and someone is signed in.
    final uid = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    // Listen for new Community notifications.
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService().watchNotifications(uid),
      builder: (context, activitySnapshot) {
        // Count notifications that have not been read.
        final activityCount = activitySnapshot.data
                ?.where((notification) => !notification.isRead)
                .length ??
            0;

        // Also check whether any plants need watering.
        return StreamBuilder<List<MyPlant>>(
          stream: DatabaseService().getMyPlants(uid),
          builder: (context, plantSnapshot) {
            final wateringCount = plantSnapshot.data
                    ?.where((plant) {
                      final days = plant.daysUntilWatering();

                      return days != null && days <= 0;
                    })
                    .length ??
                0;

            // Combine unread activity and watering reminders.
            final total = activityCount + wateringCount;

            return IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const NotificationsScreen(),
                  ),
                );
              },
              icon: Badge(
                isLabelVisible: total > 0,
                label: Text(
                  total > 99 ? '99+' : '$total',
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: _forest,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
