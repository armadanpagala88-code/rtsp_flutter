import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';

/// Platform-agnostic HLS Video Player
/// Uses WebView on mobile, falls back to simple video display
class HlsVideoPlayer extends StatefulWidget {
  final String hlsUrl;
  final bool autoPlay;
  final VoidCallback? onError;

  const HlsVideoPlayer({
    super.key,
    required this.hlsUrl,
    this.autoPlay = true,
    this.onError,
  });

  @override
  State<HlsVideoPlayer> createState() => _HlsVideoPlayerState();
}

class _HlsVideoPlayerState extends State<HlsVideoPlayer> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final hlsUrl = _normalizeHlsUrl(widget.hlsUrl);
    
    // Create HTML page with HLS.js player
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #000; width: 100vw; height: 100vh; display: flex; align-items: center; justify-content: center; }
    video { width: 100%; height: 100%; object-fit: contain; }
    .error { color: #fff; text-align: center; padding: 20px; }
  </style>
</head>
<body>
  <video id="video" controls ${widget.autoPlay ? 'autoplay muted playsinline' : 'playsinline'}></video>
  <script>
    var video = document.getElementById('video');
    var hlsUrl = '$hlsUrl';
    
    if (Hls.isSupported()) {
      var hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
      });
      hls.loadSource(hlsUrl);
      hls.attachMedia(video);
      hls.on(Hls.Events.MANIFEST_PARSED, function() {
        ${widget.autoPlay ? 'video.play();' : ''}
      });
      hls.on(Hls.Events.ERROR, function(event, data) {
        console.error('HLS Error:', data);
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = hlsUrl;
      ${widget.autoPlay ? 'video.play();' : ''}
    }
  </script>
</body>
</html>
''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _error = 'Failed to load stream: ${error.description}';
                _isLoading = false;
              });
              widget.onError?.call();
            }
          },
        ),
      )
      ..loadHtmlString(htmlContent);
  }

  String _normalizeHlsUrl(String url) {
    // Auto-add index.m3u8 if needed for MediaMTX
    if (url.contains(':8888/') || url.contains(':8889/')) {
      if (!url.endsWith('.m3u8') && !url.contains('.m3u8')) {
        if (!url.endsWith('/')) {
          url += '/';
        }
        url += 'index.m3u8';
      }
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // On web, show placeholder (web version uses HtmlElementView)
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Video Player (Web)',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _initWebView();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
