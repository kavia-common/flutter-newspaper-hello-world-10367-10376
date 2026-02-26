import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/news_article.dart';
import '../../state/news_app_state.dart';

class ReadArticleArgs {
  const ReadArticleArgs({required this.article});

  final NewsArticle article;
}

class ReadArticleScreen extends StatefulWidget {
  const ReadArticleScreen({super.key, required this.args});

  static const routeName = '/read';

  final ReadArticleArgs args;

  @override
  State<ReadArticleScreen> createState() => _ReadArticleScreenState();
}

class _ReadArticleScreenState extends State<ReadArticleScreen> {
  late final WebViewController _controller;
  late final FlutterTts _tts;

  double _speechRate = 1.0;
  int _voiceIndex = 0;

  @override
  void initState() {
    super.initState();

    _tts = FlutterTts();
    _configureTts();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (_) {},
        ),
      );

    final url = widget.args.article.url;
    if (url != null && url.trim().isNotEmpty) {
      _controller.loadRequest(Uri.parse(url));
    }
  }

  Future<void> _configureTts() async {
    // Do not use BuildContext after awaits; this is isolated.
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
  }

  @override
  void dispose() {
    _tts.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read News'),
        actions: [
          _ListenMenuButton(
            onPlay: _play,
            onStop: _stop,
            onSetSpeed: (rate) {
              setState(() => _speechRate = rate);
              _applyRateAndPlay();
            },
            onSetVoice: (index) {
              setState(() => _voiceIndex = index);
              _applyVoiceAndPlay();
            },
          ),
          PopupMenuButton<_MoreAction>(
            tooltip: 'More',
            onSelected: (action) => _handleMoreAction(context, action),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _MoreAction.browse, child: Text('Browse')),
              PopupMenuItem(value: _MoreAction.share, child: Text('Share')),
              PopupMenuItem(value: _MoreAction.save, child: Text('Save')),
            ],
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  Future<void> _handleMoreAction(BuildContext context, _MoreAction action) async {
    final article = widget.args.article;
    final url = article.url;

    // Capture anything derived from BuildContext BEFORE awaiting.
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<NewsAppState>();

    switch (action) {
      case _MoreAction.share:
        if (url == null || url.isEmpty) return;
        await Share.share('Hey, checkout this news : $url');
        break;
      case _MoreAction.save:
        await state.saveArticle(article);
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('News saved!')));
        break;
      case _MoreAction.browse:
        if (url == null || url.isEmpty) return;
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        break;
    }
  }

  String _ttsText() {
    final content = widget.args.article.content ?? '';
    // Kotlin app appended a paywall message; keep parity.
    return '$content. get paid version to hear full news. ';
  }

  Future<void> _play() async {
    await _tts.speak(_ttsText());
  }

  Future<void> _stop() async {
    await _tts.stop();
  }

  Future<void> _applyRateAndPlay() async {
    await _tts.stop();
    await _tts.setSpeechRate(_speechRate);
    await _tts.speak(_ttsText());
  }

  Future<void> _applyVoiceAndPlay() async {
    await _tts.stop();

    // flutter_tts voice list differs by platform. We emulate "voice1/voice2" by picking first two available voices.
    final voices = await _tts.getVoices;
    if (voices is List && voices.isNotEmpty) {
      final idx = _voiceIndex.clamp(0, voices.length - 1);
      final v = voices[idx];
      if (v is Map) {
        final name = v['name']?.toString();
        final locale = v['locale']?.toString();
        if (name != null && locale != null) {
          await _tts.setVoice(<String, String>{'name': name, 'locale': locale});
        }
      }
    }

    await _tts.speak(_ttsText());
  }
}

enum _MoreAction { browse, share, save }

class _ListenMenuButton extends StatelessWidget {
  const _ListenMenuButton({
    required this.onPlay,
    required this.onStop,
    required this.onSetSpeed,
    required this.onSetVoice,
  });

  final VoidCallback onPlay;
  final VoidCallback onStop;
  final ValueChanged<double> onSetSpeed;
  final ValueChanged<int> onSetVoice;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ListenAction>(
      tooltip: 'Listen',
      icon: const Icon(Icons.play_circle_outline),
      onSelected: (action) {
        switch (action) {
          case _ListenAction.play:
            onPlay();
            break;
          case _ListenAction.stop:
            onStop();
            break;
          case _ListenAction.speed075:
            onSetSpeed(0.75);
            break;
          case _ListenAction.speed1:
            onSetSpeed(1.0);
            break;
          case _ListenAction.speed2:
            onSetSpeed(2.0);
            break;
          case _ListenAction.voice1:
            onSetVoice(0);
            break;
          case _ListenAction.voice2:
            onSetVoice(1);
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: _ListenAction.play, child: Text('Play')),
        PopupMenuItem(value: _ListenAction.stop, child: Text('Stop')),
        PopupMenuDivider(),
        PopupMenuItem(value: _ListenAction.speed075, child: Text('0.75x')),
        PopupMenuItem(value: _ListenAction.speed1, child: Text('1x')),
        PopupMenuItem(value: _ListenAction.speed2, child: Text('2x')),
        PopupMenuDivider(),
        PopupMenuItem(value: _ListenAction.voice1, child: Text('voice1')),
        PopupMenuItem(value: _ListenAction.voice2, child: Text('voice2')),
      ],
    );
  }
}

enum _ListenAction {
  play,
  stop,
  speed075,
  speed1,
  speed2,
  voice1,
  voice2,
}
