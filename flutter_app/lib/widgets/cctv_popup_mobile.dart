import 'package:flutter/material.dart';
import '../models/cctv.dart';
import 'hls_video_player.dart';

/// Mobile-compatible CCTV Popup
/// Uses HlsVideoPlayer instead of dart:html iframes
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
  bool _showStream = false;
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
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF162544),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          _buildVideoSection(),
          _buildInfo(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1E36),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.cctv.isOnline ? Colors.red : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.cctv.isOnline ? 'LIVE' : 'OFFLINE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.cctv.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    final streamUrl = _getStreamUrl();
    
    return Container(
      height: 180,
      color: Colors.black,
      child: _showStream && streamUrl != null && widget.cctv.isOnline
          ? Stack(
              children: [
                HlsVideoPlayer(hlsUrl: streamUrl, autoPlay: true),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildQualitySelector(),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.cctv.isOnline ? Icons.play_circle_filled : Icons.videocam_off,
                    color: Colors.white.withOpacity(0.5),
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  if (widget.cctv.isOnline)
                    ElevatedButton(
                      onPressed: () => setState(() => _showStream = true),
                      child: const Text('Play Stream'),
                    )
                  else
                    Text(
                      'Camera Offline',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildQualitySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQualityButton('Preview', 'preview'),
          const SizedBox(width: 4),
          _buildQualityButton('HD', 'main'),
        ],
      ),
    );
  }

  Widget _buildQualityButton(String label, String quality) {
    final isSelected = _currentQuality == quality;
    return GestureDetector(
      onTap: () => setState(() => _currentQuality = quality),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE53935) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.cctv.owner,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.category, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.cctv.category,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onSelect,
              icon: Icon(widget.isSelected ? Icons.check : Icons.add),
              label: Text(widget.isSelected ? 'Dipilih' : 'Pilih'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isSelected ? Colors.green : const Color(0xFFE53935),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
