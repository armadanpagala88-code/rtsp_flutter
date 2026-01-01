import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cctv.dart';
import '../providers/cctv_provider.dart';
import '../widgets/hls_video_player.dart';

/// Mobile-optimized Multi Stream Screen
/// Uses WebView-based HLS player instead of dart:html iframes
class MultiStreamScreen extends StatefulWidget {
  final VoidCallback onNavigateToMap;
  
  const MultiStreamScreen({super.key, required this.onNavigateToMap});

  @override
  State<MultiStreamScreen> createState() => _MultiStreamScreenState();
}

class _MultiStreamScreenState extends State<MultiStreamScreen> {
  int _gridSize = 2;

  @override
  Widget build(BuildContext context) {
    return Consumer<CctvProvider>(
      builder: (context, provider, _) {
        final selectedCctvs = provider.selectedCctvs;

        if (selectedCctvs.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: [
            _buildToolbar(selectedCctvs.length),
            Expanded(child: _buildStreamGrid(selectedCctvs, provider)),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('$count CCTV dipilih', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          _buildGridSizeButton(1, '1'),
          const SizedBox(width: 8),
          _buildGridSizeButton(2, '2x2'),
          const SizedBox(width: 8),
          _buildGridSizeButton(3, '3x3'),
        ],
      ),
    );
  }

  Widget _buildGridSizeButton(int size, String label) {
    final isSelected = _gridSize == size;
    return GestureDetector(
      onTap: () => setState(() => _gridSize = size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE53935) : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
      ),
    );
  }

  Widget _buildStreamGrid(List<Cctv> cctvs, CctvProvider provider) {
    final crossAxisCount = _gridSize;
    final displayCount = crossAxisCount * crossAxisCount;
    final displayCctvs = cctvs.take(displayCount).toList();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: displayCctvs.length,
      itemBuilder: (context, index) {
        return _StreamTile(
          cctv: displayCctvs[index],
          onRemove: () => provider.removeFromSelection(displayCctvs[index]),
          onExpand: () => _showFullscreenStream(displayCctvs[index]),
        );
      },
    );
  }

  void _showFullscreenStream(Cctv cctv) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenStreamPage(cctv: cctv),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Tidak ada CCTV dipilih',
            style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih kamera dari peta untuk melihat streaming',
            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onNavigateToMap,
            icon: const Icon(Icons.map),
            label: const Text('Buka Peta'),
          ),
        ],
      ),
    );
  }
}

class _StreamTile extends StatelessWidget {
  final Cctv cctv;
  final VoidCallback onRemove;
  final VoidCallback onExpand;

  const _StreamTile({
    required this.cctv,
    required this.onRemove,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final streamUrl = _getStreamUrl();
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          if (streamUrl != null && cctv.isOnline)
            HlsVideoPlayer(hlsUrl: streamUrl, autoPlay: true)
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cctv.isOnline ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white.withOpacity(0.5),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cctv.isOnline ? 'Loading...' : 'Offline',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            ),
          
          // Header overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cctv.isOnline ? Colors.red : Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cctv.isOnline ? 'LIVE' : 'OFFLINE',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cctv.name,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Control buttons overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildButton(Icons.fullscreen, onExpand),
                  const SizedBox(width: 8),
                  _buildButton(Icons.close, onRemove, color: Colors.red),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getStreamUrl() {
    if (cctv.streams.isEmpty) return null;
    final stream = cctv.streams.firstWhere(
      (s) => s.quality == 'preview',
      orElse: () => cctv.streams[0],
    );
    return stream.url;
  }

  Widget _buildButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 18),
      ),
    );
  }
}

class _FullscreenStreamPage extends StatelessWidget {
  final Cctv cctv;

  const _FullscreenStreamPage({required this.cctv});

  @override
  Widget build(BuildContext context) {
    final streamUrl = cctv.streams.isNotEmpty ? cctv.streams[0].url : null;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(cctv.name),
      ),
      body: streamUrl != null
          ? HlsVideoPlayer(hlsUrl: streamUrl, autoPlay: true)
          : const Center(
              child: Text('No stream available', style: TextStyle(color: Colors.white)),
            ),
    );
  }
}
