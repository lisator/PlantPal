import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/my_plant.dart';
import '../screens/notifications_screen.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/plant_reminder_service.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  static const Color _forest = Color(0xFF315F43);

  @override
  Widget build(BuildContext context) {
    final uid = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    final database = DatabaseService();
    final notificationService = NotificationService();
    final reminderService = PlantReminderService();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, settingsSnapshot) {
        final userData = settingsSnapshot.data?.data();
        final rawSettings = userData?['settings'];

        final settings = rawSettings is Map ? rawSettings : const {};

        final communityEnabled = settings['communityNotifications'] != false;

        final wateringEnabled = settings['wateringReminders'] != false;

        final progressEnabled = settings['progressReminders'] != false;

        final savedInterval = settings['progressIntervalDays'];

        final intervalDays =
            savedInterval is int && [7, 14, 30].contains(savedInterval)
            ? savedInterval
            : 14;

        return StreamBuilder<List<AppNotification>>(
          stream: notificationService.watchNotifications(uid),
          builder: (context, activitySnapshot) {
            final unreadCount = communityEnabled
                ? activitySnapshot.data
                          ?.where((notification) => !notification.isRead)
                          .length ??
                      0
                : 0;

            return StreamBuilder<List<MyPlant>>(
              stream: database.getMyPlants(uid),
              builder: (context, plantSnapshot) {
                return StreamBuilder<Map<String, String>>(
                  stream: notificationService.watchDismissedReminders(uid),
                  builder: (context, dismissedSnapshot) {
                    final plants = plantSnapshot.data ?? <MyPlant>[];

                    final dismissed =
                        dismissedSnapshot.data ?? <String, String>{};

                    final wateringCount = wateringEnabled
                        ? reminderService
                              .getWateringReminders(
                                plants,
                                dismissed: dismissed,
                              )
                              .length
                        : 0;

                    final progressCount = progressEnabled
                        ? reminderService
                              .getProgressReminders(
                                plants,
                                intervalDays: intervalDays,
                                dismissed: dismissed,
                              )
                              .length
                        : 0;

                    final total = unreadCount + wateringCount + progressCount;

                    return IconButton(
                      tooltip: 'Notifications',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                      icon: Badge(
                        isLabelVisible: total > 0,
                        label: Text(total > 99 ? '99+' : '$total'),
                        child: Icon(
                          Icons.notifications_outlined,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.primary
                              : _forest,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
