import 'package:flutter/material.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.message,
    this.isChecked = false,
    this.onChanged,
  });

  final String message;
  final bool isChecked;
  final ValueChanged<bool?>? onChanged;

  

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.local_florist),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Checkbox(
              value: isChecked,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
