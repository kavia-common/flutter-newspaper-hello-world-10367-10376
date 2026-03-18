import 'package:flutter/material.dart';

import '../device_token/device_token_screen.dart';
import '../notification_test/notification_test_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notification Test'),
                  subtitle: const Text('Send a local test notification and view diagnostics'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(NotificationTestScreen.routeName),
                ),
                Divider(height: 1, color: Colors.grey.withAlpha(0x22)),
                ListTile(
                  leading: const Icon(Icons.phonelink_setup_outlined),
                  title: const Text('Device Token'),
                  subtitle: const Text('View and copy the FCM device token'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(DeviceTokenScreen.routeName),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
