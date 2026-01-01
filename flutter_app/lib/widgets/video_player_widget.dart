import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Platform-agnostic video player widget
/// For web: uses HLS/RTSP streaming
/// For mobile: shows placeholder with instructions
class PlatformVideoPlayer extends StatelessWidget {
  final String streamUrl;
  final bool isOnline;
  final String cctvName;

  const PlatformVideoPlayer({
    super.key,
    required this.streamUrl,
    required this.isOnline,
    required this.cctvName,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web platform - actual streaming will be handled by parent widget
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      // Mobile platform - show message
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.videocam : Icons.videocam_off,
                size: 48,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                cctvName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isOnline
                    ? 'Streaming CCTV hanya tersedia di versi web.\nBuka aplikasi di browser untuk menonton live stream.'
                    : 'CCTV sedang offline',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              if (isOnline) ...[
                const SizedBox(height: 16),
                Text(
                  streamUrl,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
}
