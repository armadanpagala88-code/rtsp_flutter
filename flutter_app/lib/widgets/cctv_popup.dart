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
  bool _isStreamReady = false; // Track if video frames are being received
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
    // If CCTV changed, stop old stream and start new one
    if (oldWidget.cctv.id != widget.cctv.id) {
      _stopStreamForCctv(oldWidget.cctv.id, _currentQuality);
      _currentQuality = 'preview'; // Reset to preview quality
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

  Future<void> _startStream() async {
    setState(() {
      _isLoading = true;
      _isStreamReady = false;
      _error = null;
    });

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
          // Mark stream as ready after JSMpeg connects (give it time to buffer)
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
    Future.delayed(const Duration(milliseconds: 100), () {
      scriptElement.remove();
    });
  }

  Future<void> _stopStream() async {
    _stopStreamForCctv(widget.cctv.id, _currentQuality);
  }

  Future<void> _stopStreamForCctv(String cctvId, String quality) async {
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
              // Video Player Area
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    // Stream Player
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildStreamPlayer(),
                    ),
                    // Close button - More prominent
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                    // Live badge
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
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.cctv.isOnline ? 'LIVE' : 'OFFLINE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Quality badge
                    if (widget.cctv.isOnline && !_isLoading && _error == null)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  ],
                ),
              ),
              // Content - Compact
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.cctv.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.cctv.owner,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    // Quality Toggle Buttons
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
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.signal_wifi_off, color: Colors.grey, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'CCTV Offline',
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
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
        child: const Center(
          child: Icon(Icons.videocam_off, size: 48, color: Colors.white24),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        color: const Color(0xFF162544),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated CCTV icon with pulse effect
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.2),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF00D4FF).withOpacity(0.3),
                            const Color(0xFF00D4FF).withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        size: 48,
                        color: Color(0xFF00D4FF),
                      ),
                    ),
                  );
                },
                onEnd: () {
                  // This creates the pulsing effect by rebuilding
                  if (mounted && _isLoading) {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 20),
              // Loading text with dots animation
              const _LoadingDotsText(),
              const SizedBox(height: 16),
              // Progress bar animation
              SizedBox(
                width: 120,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return LinearProgressIndicator(
                      value: null,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Menghubungkan ke $_currentQuality stream...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
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
              Text(
                'Gagal memuat stream',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
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

    // Show video view with loading overlay until stream is fully ready
    return Stack(
      children: [
        // Video canvas (always rendered but may be black initially)
        HtmlElementView(viewType: _viewId),
        // Loading overlay - shows until stream is ready
        if (!_isStreamReady)
          Container(
            color: const Color(0xFF162544),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated connecting icon
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(seconds: 2),
                    builder: (context, value, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating circle
                          Transform.rotate(
                            angle: value * 6.28,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                                  width: 3,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00D4FF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Center icon
                          const Icon(
                            Icons.videocam_rounded,
                            size: 32,
                            color: Color(0xFF00D4FF),
                          ),
                        ],
                      );
                    },
                    onEnd: () {
                      if (mounted && !_isStreamReady) setState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  // Loading text
                  const Text(
                    'Menghubungkan ke RTSP...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  SizedBox(
                    width: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: null,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Buffering ${_currentQuality.toUpperCase()} stream...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQualityButton(String quality, String label) {
    final isActive = _currentQuality == quality;
    
    return GestureDetector(
      onTap: () => _switchQuality(quality),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF6B6B)])
              : null,
          color: isActive ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: isActive ? null : Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: isActive
              ? [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.3), blurRadius: 8)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              quality == 'main' ? Icons.hd : Icons.sd,
              size: 18,
              color: isActive ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated loading text with dots
class _LoadingDotsText extends StatefulWidget {
  const _LoadingDotsText();

  @override
  State<_LoadingDotsText> createState() => _LoadingDotsTextState();
}

class _LoadingDotsTextState extends State<_LoadingDotsText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _dotCount = (_dotCount + 1) % 4;
          });
          _controller.reset();
          _controller.forward();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Memuat stream RTSP',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            dots,
            style: const TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
