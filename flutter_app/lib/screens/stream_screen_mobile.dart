import 'package:flutter/material.dart';
import '../models/cctv.dart';
import '../widgets/hls_video_player.dart';

/// Mobile-compatible Stream Screen
/// Uses HlsVideoPlayer instead of dart:html iframes
class StreamScreen extends StatefulWidget {
  final Cctv cctv;

  const StreamScreen({super.key, required this.cctv});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  String _currentQuality = 'preview';

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

  @override
  Widget build(BuildContext context) {
    final streamUrl = _getStreamUrl();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.cctv.name),
        actions: [
          _buildQualityButton('Preview', 'preview'),
          _buildQualityButton('HD', 'main'),
          const SizedBox(width: 8),
        ],
      ),
      body: streamUrl != null && widget.cctv.isOnline
          ? HlsVideoPlayer(hlsUrl: streamUrl, autoPlay: true)
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.cctv.isOnline ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white.withOpacity(0.5),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.cctv.isOnline ? 'Loading stream...' : 'Camera Offline',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildQualityButton(String label, String quality) {
    final isSelected = _currentQuality == quality;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () => setState(() => _currentQuality = quality),
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFFE53935) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
