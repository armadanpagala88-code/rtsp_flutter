import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/cctv.dart';
import '../services/api_service.dart';

class StreamScreen extends StatefulWidget {
  final Cctv cctv;

  const StreamScreen({super.key, required this.cctv});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  bool _isLoading = true;
  String? _error;
  String _currentQuality = 'preview';
  String _viewId = '';
  int? _wsPort; // For RTSP via JSMpeg

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final streamUrl = _getStreamUrl();
    
    if (streamUrl == null || streamUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Stream URL tidak tersedia';
      });
      return;
    }

    // Detect stream type and initialize appropriate player
    if (_isRtspUrl(streamUrl)) {
      _initRtspStream();
    } else {
      _initHlsStream(streamUrl);
    }
  }

  bool _isRtspUrl(String url) {
    return url.toLowerCase().startsWith('rtsp://');
  }

  bool _isHlsUrl(String url) {
    return url.contains('.m3u8') || 
           url.contains('m3u8') || 
           url.contains(':8888/') ||
           url.contains(':8889/');
  }

  String? _getStreamUrl() {
    if (widget.cctv.streams.isEmpty) return null;
    
    if (_currentQuality == 'main') {
      final hdStream = widget.cctv.streams.firstWhere(
        (s) => s.quality == 'main',
        orElse: () => widget.cctv.streams[0],
      );
      return hdStream.url;
    } else {
      final previewStream = widget.cctv.streams.firstWhere(
        (s) => s.quality == 'preview',
        orElse: () => widget.cctv.streams[0],
      );
      return previewStream.url;
    }
  }

  // Initialize RTSP stream via backend proxy (JSMpeg)
  Future<void> _initRtspStream() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/streams/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cctvId': widget.cctv.id,
          'quality': _currentQuality,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _wsPort = data['data']['wsPort'];
            _viewId = 'jsmpeg-player-${widget.cctv.id}-$_currentQuality-${DateTime.now().millisecondsSinceEpoch}';
            _isLoading = false;
          });
          _registerJsmpegPlayer();
        } else {
          throw Exception(data['error'] ?? 'Failed to start stream');
        }
      } else {
        throw Exception('Failed to connect to server');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _registerJsmpegPlayer() {
    if (_wsPort == null) return;

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final canvas = html.CanvasElement()
          ..id = 'stream-canvas-$viewId'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = 'black';

        html.window.requestAnimationFrame((_) {
          _createJsmpegPlayer(canvas.id!);
        });

        return canvas;
      },
    );
  }

  void _createJsmpegPlayer(String canvasId) {
    final wsUrl = 'ws://localhost:$_wsPort';
    
    final script = '''
      (function() {
        var canvas = document.getElementById('$canvasId');
        if (canvas && typeof JSMpeg !== 'undefined') {
          new JSMpeg.Player('$wsUrl', {
            canvas: canvas,
            autoplay: true,
            loop: false,
            audio: false,
            videoBufferSize: 1024 * 1024,
            progressive: false,
            chunkSize: 65536
          });
        }
      })();
    ''';

    final scriptElement = html.ScriptElement()..text = script;
    html.document.body?.append(scriptElement);
    Future.delayed(const Duration(milliseconds: 100), () => scriptElement.remove());
  }

  // Initialize HLS stream
  void _initHlsStream(String streamUrl) {
    try {
      _viewId = 'hls-player-${widget.cctv.id}-$_currentQuality-${DateTime.now().millisecondsSinceEpoch}';
      _registerHlsPlayer(streamUrl);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _registerHlsPlayer(String streamUrl) {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        // WebRTC URLs (port 8889) - embed directly as iframe
        if (streamUrl.contains(':8889/')) {
          final iframe = html.IFrameElement()
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.border = 'none'
            ..style.backgroundColor = 'black'
            ..allow = 'autoplay; fullscreen'
            ..src = streamUrl;
          return iframe;
        }
        
        // For MediaMTX HLS URLs on port 8888, add index.m3u8 if not present
        String hlsUrl = streamUrl;
        if (streamUrl.contains(':8888/') && !streamUrl.contains('.m3u8')) {
          hlsUrl = streamUrl.endsWith('/') ? '${streamUrl}index.m3u8' : '$streamUrl/index.m3u8';
        }
        
        // Check if it's an HLS URL that needs hls.js
        final needsHlsJs = hlsUrl.contains('.m3u8') || streamUrl.contains(':8888/');
        
        if (needsHlsJs) {
          // Use iframe with hls.js for .m3u8 streams
          final iframe = html.IFrameElement()
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.border = 'none'
            ..style.backgroundColor = 'black'
            ..srcdoc = '''
              <!DOCTYPE html>
              <html>
              <head>
                <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
                <style>
                  * { margin: 0; padding: 0; }
                  body { background: black; display: flex; align-items: center; justify-content: center; height: 100vh; }
                  video { width: 100%; height: 100%; object-fit: contain; }
                </style>
              </head>
              <body>
                <video id="video" controls autoplay muted playsinline></video>
                <script>
                  var video = document.getElementById('video');
                  var streamUrl = '$hlsUrl';
                  
                  if (Hls.isSupported()) {
                    var hls = new Hls({ enableWorker: true, lowLatencyMode: true });
                    hls.loadSource(streamUrl);
                    hls.attachMedia(video);
                    hls.on(Hls.Events.MANIFEST_PARSED, function() { video.play(); });
                  } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
                    video.src = streamUrl;
                    video.addEventListener('loadedmetadata', function() { video.play(); });
                  }
                </script>
              </body>
              </html>
            ''';
          return iframe;
        } else {
          // Direct iframe for other streams
          final iframe = html.IFrameElement()
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.border = 'none'
            ..style.backgroundColor = 'black'
            ..allow = 'autoplay; fullscreen'
            ..src = streamUrl;
          return iframe;
        }
      },
    );
  }

  Future<void> _stopStream() async {
    if (_wsPort != null) {
      try {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/streams/stop'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'cctvId': widget.cctv.id,
            'quality': _currentQuality,
          }),
        );
      } catch (e) {
        debugPrint('Error stopping stream: $e');
      }
    }
  }

  void _switchQuality(String quality) {
    if (quality != _currentQuality) {
      _stopStream();
      setState(() {
        _currentQuality = quality;
      });
      _initStream();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.cctv.name, style: const TextStyle(fontSize: 16)),
            Text(
              widget.cctv.owner,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.cctv.isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.cctv.isOnline ? Colors.green : Colors.red),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: widget.cctv.isOnline ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.cctv.isOnline ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    color: widget.cctv.isOnline ? Colors.green : Colors.red,
                    fontSize: 12, fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video player with fixed 16:9 aspect ratio
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildVideoPlayer(),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.cctv.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.cctv.owner, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildInfoChip(icon: Icons.location_on, label: 'Lat: ${widget.cctv.location.lat.toStringAsFixed(4)}'),
                      const SizedBox(width: 12),
                      _buildInfoChip(icon: Icons.location_on, label: 'Lng: ${widget.cctv.location.lng.toStringAsFixed(4)}'),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(child: _buildQualityButton('Preview', _currentQuality == 'preview')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQualityButton('HD', _currentQuality == 'main')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Menghubungkan ke stream...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Gagal streaming', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!, style: TextStyle(color: Colors.white.withOpacity(0.5)), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: _initStream, icon: const Icon(Icons.refresh), label: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_viewId.isNotEmpty) {
      return HtmlElementView(viewType: _viewId);
    }

    return const Center(child: Text('Stream tidak tersedia', style: TextStyle(color: Colors.white70)));
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildQualityButton(String label, bool isActive) {
    return ElevatedButton(
      onPressed: () => _switchQuality(label == 'HD' ? 'main' : 'preview'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
        foregroundColor: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label),
    );
  }
}
