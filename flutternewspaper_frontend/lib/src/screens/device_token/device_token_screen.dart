import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/firebase_messaging_service.dart';

class DeviceTokenScreen extends StatefulWidget {
  const DeviceTokenScreen({super.key});

  static const routeName = '/device-token';

  @override
  State<DeviceTokenScreen> createState() => _DeviceTokenScreenState();
}

class _DeviceTokenScreenState extends State<DeviceTokenScreen> {
  bool _isLoading = true;
  String? _token;
  String? _errorMessage;

  /// Used to trigger a one-frame snackbar in build() without calling context
  /// after awaits.
  String? _pendingSnackBarMessage;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    // IMPORTANT: no BuildContext usage after awaits (project rule).
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _token = null;
    });

    String? nextToken;
    String? nextError;

    try {
      await FirebaseMessagingService.ensureInitialized();

      // Best-effort permission request; some environments may not show dialogs.
      await FirebaseMessagingService.requestPermission();

      nextToken = await FirebaseMessagingService.getDeviceToken();
      if (nextToken == null || nextToken.trim().isEmpty) {
        nextError =
            'Unable to retrieve an FCM device token.\n\n'
            'Tips:\n'
            '- Ensure Firebase is configured for this app.\n'
            '- Run on a real device (emulators/sandboxes can suppress token generation).\n'
            '- Verify notification permissions are enabled.';
      }
    } catch (e) {
      nextError = 'Failed to load device token: $e';
    }

    setState(() {
      _isLoading = false;
      _token = nextToken;
      _errorMessage = nextError;
    });
  }

  void _copyToken() {
    final token = _token;
    if (token == null || token.trim().isEmpty) return;

    Clipboard.setData(ClipboardData(text: token));

    setState(() {
      _pendingSnackBarMessage = 'Token copied to clipboard';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingSnackBarMessage;
    if (pending != null) {
      // Clear first so rebuilds don't re-show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pending)));
      });

      _pendingSnackBarMessage = null;
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Token'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadToken,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FCM Device Token',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use this token to test push notifications to this device/install.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withAlpha(0x33)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withAlpha(0x33)),
                    ),
                    child: SelectableText(
                      _token ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: (_isLoading || (_token == null) || (_token!.trim().isEmpty)) ? null : _copyToken,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _loadToken,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
