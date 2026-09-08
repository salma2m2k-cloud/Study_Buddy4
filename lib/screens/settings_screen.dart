import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../providers/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  Future<void> _refreshPermissionStatus() async {
    final AppState app = context.read<AppState>();
    final bool enabled = await app.notifications.hasPermission();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  static const List<int> _leadOptions = [5, 10, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('Appearance'),
          _SettingsCard(
            child: Column(
              children: AppThemeMode.values.map((mode) {
                final String label = switch (mode) {
                  AppThemeMode.system => 'System',
                  AppThemeMode.light => 'Light',
                  AppThemeMode.dark => 'Dark',
                };
                return RadioListTile<AppThemeMode>(
                  title: Text(label),
                  value: mode,
                  groupValue: app.settings.themeMode,
                  onChanged: (v) {
                    if (v == null) return;
                    app.updateSettings((s) => s.copyWith(themeMode: v));
                  },
                );
              }).toList(),
            ),
          ),

          const _SectionHeader('Reminder defaults'),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Applied to new tasks and classes. You can always override it per item.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _leadOptions.map((m) {
                      final bool selected = m == app.settings.defaultReminderLeadMinutes;
                      return ChoiceChip(
                        label: Text('$m min'),
                        selected: selected,
                        onSelected: (_) => app.updateSettings(
                            (s) => s.copyWith(defaultReminderLeadMinutes: m)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const _SectionHeader('Notifications'),
          _SettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _notificationsEnabled == true
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    color: _notificationsEnabled == true ? Colors.green : Colors.orange,
                  ),
                  title: const Text('Permission status'),
                  subtitle: Text(_notificationsEnabled == null
                      ? 'Checking…'
                      : (_notificationsEnabled! ? 'Enabled' : 'Not enabled')),
                  trailing: TextButton(
                    onPressed: () async {
                      await app.notifications.requestPermissions();
                      await _refreshPermissionStatus();
                    },
                    child: const Text('Request'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.send_rounded),
                  title: const Text('Test notification'),
                  subtitle: const Text('Shows an immediate notification'),
                  trailing: FilledButton(
                    onPressed: () async {
                      await app.notifications.showTestNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test notification sent')),
                        );
                      }
                    },
                    child: const Text('Send'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pending_actions_rounded),
                  title: const Text('Pending reminders'),
                  subtitle: FutureBuilder(
                    future: app.notifications.pending(),
                    builder: (context, snapshot) {
                      final int count = snapshot.data?.length ?? 0;
                      return Text('$count scheduled right now');
                    },
                  ),
                ),
              ],
            ),
          ),

          const _SectionHeader('Data'),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: const Text('Clear all data'),
              subtitle: const Text('Deletes tasks, classes, sessions, and notes'),
              onTap: () => _confirmClearData(context, app),
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Study Buddy · local-first, no account needed',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmClearData(BuildContext context, AppState app) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes all tasks, classes, study sessions, and notes on this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await app.clearAllData();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(child: child),
    );
  }
}
