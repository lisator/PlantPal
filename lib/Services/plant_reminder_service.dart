import '../models/my_plant.dart';
import 'notification_service.dart';

class PlantProgressReminder {
  const PlantProgressReminder({
    required this.plant,
    required this.dueDate,
    required this.daysUntilDue,
  });

  final MyPlant plant;
  final DateTime dueDate;
  final int daysUntilDue;

  bool get isDue => daysUntilDue <= 0;

  String get title => 'Time for a plant update!';

  String get message {
    final name = plant.displayName;

    if (daysUntilDue < 0) {
      final overdue = -daysUntilDue;

      return 'Your $name progress update is '
          '$overdue ${overdue == 1 ? 'day' : 'days'} '
          'overdue. Share another picture!';
    }

    if (daysUntilDue == 0) {
      return 'Time to take a new picture of $name '
          'and see how it has grown!';
    }

    return 'Your next $name update is due in '
        '$daysUntilDue '
        '${daysUntilDue == 1 ? 'day' : 'days'}.';
  }
}

// A plant reminder that can be selected and dismissed.
class PlantCareReminder {
  const PlantCareReminder({
    required this.plant,
    required this.type,
    required this.dueDate,
    required this.message,
  });

  final MyPlant plant;
  final String type;
  final DateTime dueDate;
  final String message;

  String get id => NotificationService.reminderId(type, plant.id);

  String get selectionKey => 'reminder|$id';

  PlantReminderSelection get selection {
    return PlantReminderSelection(
      type: type,
      plantId: plant.id,
      dueDate: dueDate,
    );
  }
}

class PlantReminderService {
  static const int defaultIntervalDays = 14;

  static const List<int> allowedIntervals = [7, 14, 30];

  bool isValidInterval(int days) => allowedIntervals.contains(days);

  // True when this specific reminder cycle was dismissed.
  bool isDismissed({
    required String reminderId,
    required DateTime dueDate,
    required Map<String, String> dismissed,
  }) {
    return dismissed[reminderId] == NotificationService.cycleKey(dueDate);
  }

  // Watering reminders currently due.
  List<PlantCareReminder> getWateringReminders(
    List<MyPlant> plants, {
    Map<String, String> dismissed = const {},
    DateTime? now,
  }) {
    final reminders = <PlantCareReminder>[];

    for (final plant in plants) {
      final dueDate = plant.nextWateringAt;
      final days = plant.daysUntilWatering(now);

      if (dueDate == null || days == null || days > 0) {
        continue;
      }

      final id = NotificationService.reminderId('watering', plant.id);

      if (isDismissed(reminderId: id, dueDate: dueDate, dismissed: dismissed)) {
        continue;
      }

      final message = days == 0
          ? '${plant.displayName} needs watering today.'
          : '${plant.displayName} is ${-days} '
                '${-days == 1 ? 'day' : 'days'} overdue '
                'for watering.';

      reminders.add(
        PlantCareReminder(
          plant: plant,
          type: 'watering',
          dueDate: dueDate,
          message: message,
        ),
      );
    }

    reminders.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return reminders;
  }

  // Progress photo reminders currently due.
  List<PlantCareReminder> getProgressReminders(
    List<MyPlant> plants, {
    int intervalDays = defaultIntervalDays,
    Map<String, String> dismissed = const {},
    DateTime? now,
  }) {
    if (!isValidInterval(intervalDays)) {
      throw ArgumentError('Reminder interval must be 7, 14, or 30 days.');
    }

    final reminders = <PlantCareReminder>[];

    for (final plant in plants) {
      final dueDate = plant.nextProgressUpdateAt(intervalDays: intervalDays);

      final days = plant.daysUntilProgressUpdate(
        intervalDays: intervalDays,
        now: now,
      );

      if (dueDate == null || days == null || days > 0) {
        continue;
      }

      final id = NotificationService.reminderId('progress', plant.id);

      if (isDismissed(reminderId: id, dueDate: dueDate, dismissed: dismissed)) {
        continue;
      }

      final message = days == 0
          ? 'Time for a new progress picture of '
                '${plant.displayName}!'
          : '${plant.displayName} needs a progress '
                'update (${(-days)} '
                '${-days == 1 ? 'day' : 'days'} overdue).';

      reminders.add(
        PlantCareReminder(
          plant: plant,
          type: 'progress',
          dueDate: dueDate,
          message: message,
        ),
      );
    }

    reminders.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return reminders;
  }

  // Compatibility with the earlier progress service.
  List<PlantProgressReminder> getDueReminders(
    List<MyPlant> plants, {
    int intervalDays = defaultIntervalDays,
    DateTime? now,
  }) {
    return getProgressReminders(
      plants,
      intervalDays: intervalDays,
      now: now,
    ).map((reminder) {
      return PlantProgressReminder(
        plant: reminder.plant,
        dueDate: reminder.dueDate,
        daysUntilDue: reminder.plant.daysUntilProgressUpdate(
          intervalDays: intervalDays,
          now: now,
        )!,
      );
    }).toList();
  }

  List<PlantProgressReminder> getUpcomingReminders(
    List<MyPlant> plants, {
    int intervalDays = defaultIntervalDays,
    int withinDays = 3,
    DateTime? now,
  }) {
    if (!isValidInterval(intervalDays)) {
      throw ArgumentError('Reminder interval must be 7, 14, or 30 days.');
    }

    final reminders = <PlantProgressReminder>[];

    for (final plant in plants) {
      final dueDate = plant.nextProgressUpdateAt(intervalDays: intervalDays);

      final days = plant.daysUntilProgressUpdate(
        intervalDays: intervalDays,
        now: now,
      );

      if (dueDate == null || days == null || days < 0 || days > withinDays) {
        continue;
      }

      reminders.add(
        PlantProgressReminder(
          plant: plant,
          dueDate: dueDate,
          daysUntilDue: days,
        ),
      );
    }

    reminders.sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));

    return reminders;
  }

  int countDueReminders(
    List<MyPlant> plants, {
    int intervalDays = defaultIntervalDays,
    DateTime? now,
  }) {
    return getDueReminders(plants, intervalDays: intervalDays, now: now).length;
  }
}
