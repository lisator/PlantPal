import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/my_plant.dart';
import '../services/database_service.dart';
import 'reusable_widgets.dart';

/// Short watering status, e.g. "Water today" or "2 days overdue".
String wateringStatus(MyPlant plant) {
  final days = plant.daysUntilWatering();
  if (days == null) return 'No watering schedule';
  if (days < -1) return 'Water ${-days} days overdue';
  if (days == -1) return 'Water 1 day overdue';
  if (days == 0) return 'Water today';
  if (days == 1) return 'Water tomorrow';
  return 'Water in $days days';
}

/// Marks [plant] watered now, with an Undo in case it was a mis-tap.
Future<void> markPlantWatered(
  BuildContext context, {
  required String userId,
  required MyPlant plant,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final previous = plant.lastWateredAt ?? plant.addedAt;
  try {
    await DatabaseService().setLastWatered(
      userId: userId,
      plantId: plant.id,
    );
  } catch (e) {
    debugPrint('Watering error: $e');
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not save. Try again.')),
    );
    return;
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('${plant.displayName} watered'),
      action: previous == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              onPressed: () => DatabaseService()
                  .setLastWatered(
                    userId: userId,
                    plantId: plant.id,
                    at: previous,
                  )
                  .catchError((Object e) => debugPrint('Undo error: $e')),
            ),
    ));
}

/// Lets the user set or clear how often [plant] is watered.
Future<void> editWateringSchedule(
  BuildContext context, {
  required String userId,
  required MyPlant plant,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final suggested = suggestedWaterEveryDays(
    benchmark: plant.wateringBenchmark,
    watering: plant.watering,
  );

  final result = await showDialog<({int? days})>(
    context: context,
    builder: (context) => _WateringScheduleDialog(
      plant: plant,
      suggested: suggested,
    ),
  );
  if (result == null) return;

  try {
    await DatabaseService().setWaterEveryDays(
      userId: userId,
      plantId: plant.id,
      days: result.days,
    );
  } catch (e) {
    debugPrint('Watering error: $e');
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not save. Try again.')),
    );
  }
}

class _WateringScheduleDialog extends StatefulWidget {
  const _WateringScheduleDialog({required this.plant, this.suggested});

  final MyPlant plant;
  final int? suggested;

  @override
  State<_WateringScheduleDialog> createState() =>
      _WateringScheduleDialogState();
}

class _WateringScheduleDialogState extends State<_WateringScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _days = TextEditingController(
    text: '${widget.plant.waterEveryDays ?? widget.suggested ?? ''}',
  );

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (days: parseWaterEveryDays(_days.text)));
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.plant.wateringSummary;
    return AlertDialog(
      title: Text('Watering for ${widget.plant.displayName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WaterEveryDaysField(
              controller: _days,
              autofocus: true,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 12),
            Text(
              summary != null
                  ? 'Perenual suggests: $summary'
                  : 'Perenual has no watering schedule for this plant. '
                      'Check its care page for guidance.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

/// The number in a [WaterEveryDaysField], or null when it's blank.
int? parseWaterEveryDays(String text) => int.tryParse(text.trim());

/// "Water every __ days" input. Blank is allowed and means no reminders.
class WaterEveryDaysField extends StatelessWidget {
  const WaterEveryDaysField({
    super.key,
    required this.controller,
    this.helperText,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? helperText;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: 'Water every',
        suffixText: 'days',
        hintText: 'Leave blank for no reminders',
        helperText: helperText,
        helperMaxLines: 3,
      ),
      validator: (text) {
        if (text == null || text.trim().isEmpty) return null;
        final days = parseWaterEveryDays(text);
        if (days == null || days < 1 || days > maxWaterEveryDays) {
          return 'Enter 1 to $maxWaterEveryDays days';
        }
        return null;
      },
    );
  }
}

/// Dashboard card listing saved plants that need water today or are overdue,
/// plus plants that still need a watering schedule.
class WateringRemindersCard extends StatelessWidget {
  const WateringRemindersCard({
    super.key,
    required this.userId,
    required this.plants,
  });

  final String userId;
  final List<MyPlant> plants;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final scheduled = plants.where((p) => p.waterEveryDays != null).toList()
      ..sort((a, b) =>
          a.daysUntilWatering()!.compareTo(b.daysUntilWatering()!));
    final due = scheduled.where((p) => p.daysUntilWatering()! <= 0).toList();
    final upcoming = scheduled.where((p) => p.daysUntilWatering()! > 0);
    final unscheduled = plants.where((p) => p.waterEveryDays == null);

    final children = <Widget>[
      if (plants.isEmpty)
        const Text('Save a plant to get watering reminders.')
      else if (due.isEmpty)
        const Text('All caught up. Nothing needs water today.'),
      for (final plant in due)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ReminderCard(
            message: '${wateringStatus(plant)}: ${plant.displayName}'
                '${plant.nickname != null ? ' (${plant.commonName})' : ''}',
            onChanged: (checked) {
              if (checked == true) {
                markPlantWatered(context, userId: userId, plant: plant);
              }
            },
          ),
        ),
      if (upcoming.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Next: ${upcoming.first.displayName} - '
            '${wateringStatus(upcoming.first).replaceFirst('Water ', '')}',
            style: textTheme.bodyMedium,
          ),
        ),
      for (final plant in unscheduled)
        Row(
          children: [
            Expanded(
              child: Text(
                'Set a watering schedule for ${plant.displayName}',
                style: textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => editWateringSchedule(
                context,
                userId: userId,
                plant: plant,
              ),
              child: const Text('Set'),
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
