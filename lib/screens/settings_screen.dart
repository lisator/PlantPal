import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isSaving = false;

  static const Map<String, dynamic> _defaults = {
    'communityNotifications': true,
    'wateringReminders': true,
    'progressReminders': true,
    'progressIntervalDays': 14,
    'themeMode': 'system',
  };

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Map<String, dynamic> _readSettings(Map<String, dynamic>? userData) {
    final settings = userData?['settings'];

    if (settings is Map) {
      return Map<String, dynamic>.from(settings);
    }

    return {};
  }

  bool _settingEnabled(Map<String, dynamic> settings, String key) {
    final value = settings[key];
    return value is bool ? value : true;
  }

  Future<void> _saveSetting(String field, Object value) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please sign in to update your settings.');
      return;
    }

    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await _db.collection('users').doc(user.uid).update({
        'settings.$field': value,
      });
    } catch (e) {
      _showMessage('Unable to save setting: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _resetSettings() async {
    final user = _auth.currentUser;
    if (user == null || _isSaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Preferences?'),
          content: const Text(
            'This will restore your notification, '
            'reminder, and appearance settings '
            'to their defaults.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      await _db.collection('users').doc(user.uid).update({
        'settings': Map<String, dynamic>.from(_defaults),
      });

      _showMessage('Preferences restored.');
    } catch (e) {
      _showMessage('Unable to reset preferences: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'PlantPal',
      applicationLegalese:
          'PlantPal helps users manage plant care '
          'and connect with other plant owners.',
    );
  }

  Widget _sectionHeading(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(children: children),
      ),
    );
  }

  Widget _notificationSwitch({
    required Map<String, dynamic> settings,
    required String field,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description),
      value: _settingEnabled(settings, field),
      onChanged: _isSaving
          ? null
          : (enabled) {
              _saveSetting(field, enabled);
            },
    );
  }

  Widget _appearanceOption({
    required String title,
    required String description,
    required String value,
    required String selected,
    required IconData icon,
  }) {
    final isSelected = value == selected;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      selected: isSelected,
      onTap: _isSaving ? null : () => _saveSetting('themeMode', value),
    );
  }

  Widget _buildSettings(Map<String, dynamic> settings) {
    final scheme = Theme.of(context).colorScheme;

    final savedInterval = settings['progressIntervalDays'];

    final intervalDays =
        savedInterval is int && [7, 14, 30].contains(savedInterval)
        ? savedInterval
        : 14;

    final savedTheme = settings['themeMode'];

    final themeMode =
        savedTheme is String && ['system', 'light', 'dark'].contains(savedTheme)
        ? savedTheme
        : 'system';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune, color: scheme.onPrimaryContainer, size: 35),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personalize PlantPal',
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Manage your appearance, '
                          'notifications, and plant care reminders.',
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            _sectionHeading(
              'Appearance',
              'Choose how PlantPal looks on your device.',
            ),

            _settingsCard([
              _appearanceOption(
                title: 'Use Device Setting',
                description: 'Match your device appearance.',
                value: 'system',
                selected: themeMode,
                icon: Icons.brightness_auto_outlined,
              ),
              const Divider(),
              _appearanceOption(
                title: 'Light Mode',
                description: 'Use the light PlantPal appearance.',
                value: 'light',
                selected: themeMode,
                icon: Icons.light_mode_outlined,
              ),
              const Divider(),
              _appearanceOption(
                title: 'Dark Mode',
                description: 'Use a darker appearance.',
                value: 'dark',
                selected: themeMode,
                icon: Icons.dark_mode_outlined,
              ),
            ]),

            const SizedBox(height: 25),

            _sectionHeading(
              'Notifications',
              'Choose which in-app notifications appear.',
            ),

            _settingsCard([
              _notificationSwitch(
                settings: settings,
                field: 'communityNotifications',
                title: 'Community Notifications',
                description: 'Likes, comments, replies, and new followers.',
                icon: Icons.people_outline,
              ),
              const Divider(),
              _notificationSwitch(
                settings: settings,
                field: 'wateringReminders',
                title: 'Watering Reminders',
                description: 'Reminders when your plants need watering.',
                icon: Icons.water_drop_outlined,
              ),
              const Divider(),
              _notificationSwitch(
                settings: settings,
                field: 'progressReminders',
                title: 'Plant Progress Reminders',
                description: 'Reminders to take another progress picture.',
                icon: Icons.camera_alt_outlined,
              ),
            ]),

            const SizedBox(height: 25),

            _sectionHeading(
              'Plant Care',
              'Customize your progress reminder schedule.',
            ),

            _settingsCard([
              const ListTile(
                leading: Icon(Icons.calendar_month_outlined),
                title: Text('Progress Reminder Frequency'),
                subtitle: Text(
                  'Choose how often you want to '
                  'take another progress picture.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: DropdownButtonFormField<int>(
                  key: ValueKey(intervalDays),
                  initialValue: intervalDays,
                  decoration: const InputDecoration(
                    labelText: 'Remind Me Every',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 days')),
                    DropdownMenuItem(value: 14, child: Text('14 days')),
                    DropdownMenuItem(value: 30, child: Text('30 days')),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (days) {
                          if (days != null) {
                            _saveSetting('progressIntervalDays', days);
                          }
                        },
                ),
              ),
            ]),

            const SizedBox(height: 25),

            _sectionHeading('General', 'Manage your application preferences.'),

            _settingsCard([
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Reset to Defaults'),
                subtitle: const Text(
                  'Restore notification, reminder, '
                  'and appearance settings.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isSaving ? null : _resetSettings,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About PlantPal'),
                subtitle: const Text('Learn more about the application.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showAbout,
              ),
            ]),

            if (_isSaving) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],

            const SizedBox(height: 18),

            Text(
              'Your preferences are saved '
              'to your PlantPal account in Firebase.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.primary, fontSize: 12),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your settings.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load your settings.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(
              child: Text('Your user profile was not found.'),
            );
          }

          final settings = _readSettings(snapshot.data!.data());

          return _buildSettings(settings);
        },
      ),
    );
  }
}
