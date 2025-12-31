import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/cctv.dart';
import '../services/api_service.dart';

class CctvPopup extends StatefulWidget {
  final Cctv cctv;
  final VoidCallback onClose;
  final VoidCallback onSelect;
  final bool isSelected;

  const CctvPopup({
    super.key,
    required this.cctv,
    required this.onClose,
    required this.onSelect,
    required this.isSelected,
  });

  @override
  State<CctvPopup> createState() => _CctvPopupState();
}

class _CctvPopupState extends State<CctvPopup> {
  bool _isLoading = true;
  bool _isStreamReady = false;
  String? _error;
  int? _wsPort;
  String _currentQuality = 'preview';
  String _viewId = '';

  @override
  void initState() {
    super.initState();
    if (widget.cctv.isOnline) {
      _startStream();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant CctvPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cctv.id != widget.cctv.id) {
      _stopStreamForCctv(oldWidget.cctv.id, _currentQuality);
      _currentQuality = 'preview';
      if (widget.cctv.isOnline) {
        _startStream();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
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

  bool _isRtspUrl(String url) => url.toLowerCase().startsWith('rtsp://');

  Future<void> _startStream() async {
    setState(() {
      _isLoading = true;
      _isStreamReady = false;
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

    if (_isRtspUrl(streamUrl)) {
      _startRtspStream();
    } else {
      _startHlsStream(streamUrl);
    }
  }

  // RTSP via backend proxy (JSMpeg)
  Future<void> _startRtspStream() async {
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
            _viewId = 'popup-stream-${widget.cctv.id}-$_currentQuality-${DateTime.now().millisecondsSinceEpoch}';
            _isLoading = false;
          });
          _initJsmpegPlayer();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isStreamReady) {
              setState(() => _isStreamReady = true);
            }
          });
        } else {
          throw Exception(data['error'] ?? 'Stream gagal dimulai');
        }
      } else {
        throw Exception('Gagal terhubung ke server');
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

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final canvas = html.CanvasElement()
          ..id = 'popup-canvas-$viewId'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = 'black'
          ..style.borderRadius = '12px';

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
            videoBufferSize: 512 * 1024,
            progressive: false,
            chunkSize: 32768,
          });
        }
      })();
    ''';

    final scriptElement = html.ScriptElement()..text = script;
    html.document.body?.append(scriptElement);
    Future.delayed(const Duration(milliseconds: 100), () => scriptElement.remove());
  }

  // HLS Stream (direct or via MediaMTX)
  void _startHlsStream(String streamUrl) {
    try {
      _viewId = 'popup-hls-${widget.cctv.id}-$_currentQuality-${DateTime.now().millisecondsSinceEpoch}';
      _registerHlsPlayer(streamUrl);
      setState(() {
        _isLoading = false;
        _isStreamReady = true;
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
            ..style.borderRadius = '12px'
            ..allow = 'autoplay; fullscreen'
            ..src = streamUrl;
          return iframe;
        }
        
        // For MediaMTX HLS URLs on port 8888, add index.m3u8 if not present
        String hlsUrl = streamUrl;
        if (streamUrl.contains(':8888/') && !streamUrl.contains('.m3u8')) {
          hlsUrl = streamUrl.endsWith('/') ? '${streamUrl}index.m3u8' : '$streamUrl/index.m3u8';
        }
        
        // Use HLS.js for HLS streams
        final iframe = html.IFrameElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..style.backgroundColor = 'black'
          ..style.borderRadius = '12px'
          ..srcdoc = '''
            <!DOCTYPE html>
            <html>
            <head>
              <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
              <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { background: black; display: flex; align-items: center; justify-content: center; height: 100vh; overflow: hidden; }
                video { width: 100%; height: 100%; object-fit: contain; }
                .error { color: #ff6b6b; text-align: center; font-family: sans-serif; }
              </style>
            </head>
            <body>
              <video id="video" autoplay muted playsinline></video>
              <script>
                var video = document.getElementById('video');
                var streamUrl = '$hlsUrl';
                
                function showError(msg) {
                  document.body.innerHTML = '<div class="error"><p>⚠️ ' + msg + '</p></div>';
                }
                
                if (Hls.isSupported()) {
                  var hls = new Hls({ 
                    enableWorker: true, 
                    lowLatencyMode: true,
                    maxBufferLength: 10,
                    maxMaxBufferLength: 30,
                  });
                  hls.loadSource(streamUrl);
                  hls.attachMedia(video);
                  hls.on(Hls.Events.MANIFEST_PARSED, function() { 
                    video.play().catch(function(e) { console.log('Autoplay blocked:', e); });
                  });
                  hls.on(Hls.Events.ERROR, function(event, data) {
                    if (data.fatal) {
                      switch(data.type) {
                        case Hls.ErrorTypes.NETWORK_ERROR:
                          hls.startLoad();
                          break;
                        case Hls.ErrorTypes.MEDIA_ERROR:
                          hls.recoverMediaError();
                          break;
                        default:
                          showError('Stream tidak tersedia');
                          hls.destroy();
                          break;
                      }
                    }
                  });
                } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
                  video.src = streamUrl;
                  video.addEventListener('loadedmetadata', function() { 
                    video.play().catch(function(e) { console.log('Autoplay blocked:', e); });
                  });
                } else {
                  showError('Browser tidak mendukung HLS');
                }
              </script>
            </body>
            </html>
          ''';
        return iframe;
      },
    );
  }

  Future<void> _stopStream() async {
    _stopStreamForCctv(widget.cctv.id, _currentQuality);
  }

  Future<void> _stopStreamForCctv(String cctvId, String quality) async {
    if (_wsPort != null) {
      try {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/streams/stop'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'cctvId': cctvId,
            'quality': quality,
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
      _startStream();
    }
  }

  void _toggleFullscreen() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video player - ignore pointer to allow overlay buttons to work
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: IgnorePointer(
                  ignoring: false,
                  child: Container(
                    color: Colors.black,
                    child: HtmlElementView(viewType: _viewId),
                  ),
                ),
              ),
            ),
            // Close button - absorb pointer to ensure it receives clicks
            Positioned(
              top: 40,
              right: 40,
              child: AbsorbPointer(
                absorbing: false,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // LIVE badge
            Positioned(
              top: 40,
              left: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFFF6B6B)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // CCTV Info
            Positioned(
              bottom: 40,
              left: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.cctv.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.cctv.owner,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Quality indicator
            Positioned(
              bottom: 40,
              right: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentQuality.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 640,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1E36).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    // Wrap video player with IgnorePointer to allow overlay buttons to work
                    IgnorePointer(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildStreamPlayer(),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: widget.cctv.isOnline
                              ? const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF6B6B)])
                              : null,
                          color: widget.cctv.isOnline ? null : Colors.grey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(widget.cctv.isOnline ? 'LIVE' : 'OFFLINE', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    // Fullscreen button
                    if (widget.cctv.isOnline && !_isLoading && _error == null)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _toggleFullscreen,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Quality indicator
                    if (widget.cctv.isOnline && !_isLoading && _error == null)
                      Positioned(
                        bottom: 10,
                        right: 58,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _currentQuality.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF00D4FF),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Close button - positioned last to be on top of all elements
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: widget.onClose,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.cctv.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(widget.cctv.owner, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                    const SizedBox(height: 10),
                    if (widget.cctv.isOnline)
                      Row(
                        children: [
                          Expanded(child: _buildQualityButton('preview', 'Preview')),
                          const SizedBox(width: 10),
                          Expanded(child: _buildQualityButton('main', 'HD')),
                        ],
                      ),
                    if (!widget.cctv.isOnline)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.signal_wifi_off, color: Colors.grey, size: 18),
                            SizedBox(width: 8),
                            Text('CCTV Offline', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamPlayer() {
    if (!widget.cctv.isOnline) {
      return Container(
        color: const Color(0xFF162544),
        child: const Center(child: Icon(Icons.videocam_off, size: 48, color: Colors.white24)),
      );
    }

    if (_isLoading) {
      return Container(
        color: const Color(0xFF162544),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00D4FF)),
              SizedBox(height: 16),
              Text('Menghubungkan ke stream...', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: const Color(0xFF162544),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              Text('Gagal memuat stream', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _startStream,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF00D4FF)),
              ),
            ],
          ),
        ),
      );
    }

    return HtmlElementView(viewType: _viewId);
  }

  Widget _buildQualityButton(String quality, String label) {
    final isActive = _currentQuality == quality;
    
    return GestureDetector(
      onTap: () => _switchQuality(quality),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive ? const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF6B6B)]) : null,
          color: isActive ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: isActive ? null : Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: isActive ? [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.3), blurRadius: 8)] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(quality == 'main' ? Icons.hd : Icons.sd, size: 18, color: isActive ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
