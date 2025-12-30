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
  int? _wsPort;
  String _currentQuality = 'preview';
  String _viewId = '';

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  Future<void> _startStream() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Request stream start from backend
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
          _initJsmpegPlayer();
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

  void _initJsmpegPlayer() {
    if (_wsPort == null) return;

    // Register a view factory for this stream
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final canvas = html.CanvasElement()
          ..id = 'stream-canvas-$viewId'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = 'black';

        // Initialize JSMpeg player after canvas is added to DOM
        html.window.requestAnimationFrame((_) {
          _createJsmpegPlayer(canvas.id);
        });

        return canvas;
      },
    );
  }

  void _createJsmpegPlayer(String canvasId) {
    final wsUrl = 'ws://localhost:$_wsPort';
    
    // Use JavaScript to create JSMpeg player
    html.window.console.log('Creating JSMpeg player for: $wsUrl');
    
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
            chunkSize: 65536,
            onPlay: function() {
              console.log('JSMpeg: Stream started');
            },
            onStalled: function() {
              console.log('JSMpeg: Stream stalled');
            },
            onEnded: function() {
              console.log('JSMpeg: Stream ended');
            }
          });
          console.log('JSMpeg player created successfully');
        } else {
          console.error('Canvas not found or JSMpeg not loaded');
        }
      })();
    ''';

    final scriptElement = html.ScriptElement()..text = script;
    html.document.body?.append(scriptElement);
    
    // Remove script element after execution
    Future.delayed(const Duration(milliseconds: 100), () {
      scriptElement.remove();
    });
  }

  Future<void> _stopStream() async {
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

  void _switchQuality(String quality) {
    if (quality != _currentQuality) {
      _stopStream();
      setState(() {
        _currentQuality = quality;
      });
      _startStream();
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
            Text(
              widget.cctv.name,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.cctv.owner,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          // Status indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.cctv.isOnline
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.cctv.isOnline ? Colors.green : Colors.red,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video Player
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              child: _buildVideoPlayer(),
            ),
          ),
          // Info Section
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.cctv.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.cctv.owner,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Location info
                  Row(
                    children: [
                      _buildInfoChip(
                        icon: Icons.location_on,
                        label: 'Lat: ${widget.cctv.location.lat.toStringAsFixed(4)}',
                      ),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        icon: Icons.location_on,
                        label: 'Lng: ${widget.cctv.location.lng.toStringAsFixed(4)}',
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Quality selector
                  Row(
                    children: [
                      Expanded(
                        child: _buildQualityButton('Preview', _currentQuality == 'preview'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQualityButton('HD', _currentQuality == 'main'),
                      ),
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
            Text(
              'Menghubungkan ke stream...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal streaming RTSP',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startStream,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_wsPort != null && _viewId.isNotEmpty) {
      return HtmlElementView(viewType: _viewId);
    }

    return const Center(
      child: Text(
        'Stream tidak tersedia',
        style: TextStyle(color: Colors.white70),
      ),
    );
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityButton(String label, bool isActive) {
    return ElevatedButton(
      onPressed: () {
        _switchQuality(label == 'HD' ? 'main' : 'preview');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).cardColor,
        foregroundColor: isActive
            ? Colors.white
            : Theme.of(context).textTheme.bodyMedium?.color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(label),
    );
  }
}
