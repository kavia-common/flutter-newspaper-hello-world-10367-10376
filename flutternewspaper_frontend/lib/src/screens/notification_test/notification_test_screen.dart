import 'package:flutter/material.dart';

import '../../core/local_notifications.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  static const routeName = '/notification-test';

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  bool _isLoading = false;

  bool? _notificationsEnabled;
  bool? _permissionGranted;

  String? _platform;
  String? _details;
  String? _lastDiagnostic;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    // IMPORTANT (project rule): no BuildContext usage after awaits.
    setState(() {
      _isLoading = true;
      _details = null;
    });

    final status = await LocalNotifications.getDiagnostics();
    final lastDiag = LocalNotifications.lastDiagnostic;

    setState(() {
      _isLoading = false;
      _notificationsEnabled = status.notificationsEnabled;
      _permissionGranted = status.permissionGranted;
      _platform = status.platform;
      _details = status.details;
      _lastDiagnostic = lastDiag;
    });
  }

  Future<void> _sendTest() async {
    // IMPORTANT (project rule): no BuildContext usage after awaits.
    setState(() {
      _isLoading = true;
    });

    final result = await LocalNotifications.showTestNotification();
    final status = await LocalNotifications.getDiagnostics();
    final lastDiag = LocalNotifications.lastDiagnostic;

    setState(() {
      _isLoading = false;
      _notificationsEnabled = status.notificationsEnabled;
      _permissionGranted = status.permissionGranted;
      _platform = status.platform;
      _details = status.details;
      _lastDiagnostic = lastDiag ?? result.diagnostic;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _kvRow('Platform', _platform ?? 'Unknown'),
                  _kvRow(
                    'Notifications enabled',
                    _notificationsEnabled == null ? 'Unknown' : (_notificationsEnabled! ? 'Yes' : 'No'),
                    valueColor: _notificationsEnabled == null
                        ? scheme.onSurface
                        : (_notificationsEnabled! ? Colors.green.shade700 : Colors.red.shade700),
                  ),
                  _kvRow(
                    'Permission granted',
                    _permissionGranted == null ? 'Unknown' : (_permissionGranted! ? 'Yes' : 'No'),
                    valueColor: _permissionGranted == null
                        ? scheme.onSurface
                        : (_permissionGranted! ? Colors.green.shade700 : Colors.red.shade700),
                  ),
                  if ((_details ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _details!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface.withAlpha(0xAA)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap the button below to trigger a local notification. '
                    'If nothing appears (common in some preview/emulator environments), '
                    'use the diagnostic message shown under “Last diagnostic”.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _sendTest,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                      label: const Text('Send test notification'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last diagnostic',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (_lastDiagnostic ?? '').trim().isEmpty ? 'None' : _lastDiagnostic!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(String key, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(0xAA),
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
