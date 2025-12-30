import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/cctv.dart';
import '../providers/cctv_provider.dart';
import '../services/api_service.dart';
import 'stream_screen.dart';

class MultiStreamScreen extends StatefulWidget {
  const MultiStreamScreen({super.key});

  @override
  State<MultiStreamScreen> createState() => _MultiStreamScreenState();
}

class _MultiStreamScreenState extends State<MultiStreamScreen> {
  int _gridSize = 2; // 2x2 grid

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
            // Grid size selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${selectedCctvs.length} CCTV dipilih',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Grid size buttons
                  _buildGridSizeButton(1, '1'),
                  const SizedBox(width: 8),
                  _buildGridSizeButton(2, '2x2'),
                  const SizedBox(width: 8),
                  _buildGridSizeButton(3, '3x3'),
                ],
              ),
            ),
            // Grid view
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GridView.builder(
                  key: ValueKey('grid-${selectedCctvs.length}-$_gridSize'),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridSize,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 16 / 10,
                  ),
                  itemCount: selectedCctvs.length,
                  itemBuilder: (context, index) {
                    final cctv = selectedCctvs[index];
                    return _StreamTile(
                      key: ValueKey('tile-${cctv.id}'),
                      cctv: cctv,
                      onRemove: () {
                        provider.removeFromSelection(cctv);
                      },
                      onExpand: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StreamScreen(
                              cctv: cctv,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Consumer<CctvProvider>(
      builder: (context, provider, _) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.grid_view,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Multi Stream',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih beberapa CCTV dari peta\nuntuk menampilkan multi-stream',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to map is handled by bottom nav in HomeScreen
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Buka Peta'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCctvDialog(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah CCTV'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCctvDialog(BuildContext context, CctvProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.videocam, color: Colors.red),
              SizedBox(width: 8),
              Text('Pilih CCTV'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: provider.allCctvList.length,
              itemBuilder: (context, index) {
                final cctv = provider.allCctvList[index];
                final isSelected = provider.isSelected(cctv);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cctv.isOnline ? Colors.green : Colors.grey,
                    child: Icon(
                      cctv.isOnline ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    cctv.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(cctv.owner),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      if (value == true) {
                        provider.addToSelection(cctv);
                      } else {
                        provider.removeFromSelection(cctv);
                      }
                      // Rebuild dialog
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  onTap: () {
                    if (isSelected) {
                      provider.removeFromSelection(cctv);
                    } else {
                      provider.addToSelection(cctv);
                    }
                    // Rebuild dialog
                    (context as Element).markNeedsBuild();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check),
              label: Text('Lihat ${provider.selectedCctvs.length} CCTV'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridSizeButton(int size, String label) {
    final isActive = _gridSize == size;
    return GestureDetector(
      onTap: () => setState(() => _gridSize = size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
              color: isActive ? Colors.white : null,
              fontWeight: isActive ? FontWeight.bold : null,
            )),
      ),
    );
  }
}

class _StreamTile extends StatefulWidget {
  final Cctv cctv;
  final VoidCallback onRemove;
  final VoidCallback onExpand;

  const _StreamTile({
    super.key,
    required this.cctv,
    required this.onRemove,
    required this.onExpand,
  });

  @override
  State<_StreamTile> createState() => _StreamTileState();
}

class _StreamTileState extends State<_StreamTile> {
  bool _isLoading = true;
  String? _error;
  int? _wsPort;
  String? _viewId;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  Future<void> _startStream() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/streams/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cctvId': widget.cctv.id,
          'quality': 'preview',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (!mounted) return;
          final wsPort = data['data']['wsPort'];
          final viewId = 'jsmpeg-multi-${widget.cctv.id}-${DateTime.now().millisecondsSinceEpoch}';
          
          setState(() {
            _wsPort = wsPort;
            _viewId = viewId;
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _initJsmpegPlayer() {
    if (_wsPort == null || _viewId == null) return;

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId!,
      (int viewId) {
        final canvasId = 'canvas-multi-${widget.cctv.id}-${DateTime.now().millisecondsSinceEpoch}';
        final canvas = html.CanvasElement()
          ..id = canvasId
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = 'black';

        // Delay player creation to ensure canvas is in DOM
        Future.delayed(const Duration(milliseconds: 300), () {
          _createJsmpegPlayer(canvasId);
        });

        return canvas;
      },
    );
  }

  void _createJsmpegPlayer(String canvasId) {
    final wsUrl = 'ws://localhost:$_wsPort';
    
    final script = '''
      (function() {
        console.log('MultiStream: Attempting to create player for canvas: $canvasId');
        var canvas = document.getElementById('$canvasId');
        
        if (!canvas) {
          console.error('MultiStream: Canvas not found: $canvasId');
          return;
        }
        
        if (typeof JSMpeg === 'undefined') {
          console.error('MultiStream: JSMpeg library not loaded');
          return;
        }
        
        console.log('MultiStream: Creating JSMpeg player for $wsUrl');
        var player = new JSMpeg.Player('$wsUrl', {
          canvas: canvas,
          autoplay: true,
          loop: false,
          audio: false,
          videoBufferSize: 512 * 1024,
          progressive: false,
          chunkSize: 32768,
          onPlay: function() { 
            console.log('MultiStream: Playing $canvasId'); 
          },
          onStalled: function() {
            console.warn('MultiStream: Stalled $canvasId');
          }
        });
        
        console.log('MultiStream: Player created for $canvasId', player);
      })();
    ''';

    final scriptElement = html.ScriptElement()..text = script;
    html.document.body?.append(scriptElement);
    Future.delayed(const Duration(milliseconds: 200), () => scriptElement.remove());
  }

  Future<void> _stopStream() async {
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/streams/stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cctvId': widget.cctv.id,
          'quality': 'preview',
        }),
      );
    } catch (e) {
      debugPrint('Error stopping stream: $e');
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Content
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _buildContent(),
            ),
          ),
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),
          // Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 24),
              const SizedBox(height: 4),
              Text('Gagal muat', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
            ],
          ),
        ),
      );
    }
    if (_viewId != null) {
      return HtmlElementView(viewType: _viewId!);
    }
    return Container();
  }

  Widget _buildHeader() {
    return Container(
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
              color: widget.cctv.isOnline ? Colors.red : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.cctv.isOnline ? 'LIVE' : 'OFFLINE',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.cctv.name,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
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
          _buildControlButton(icon: Icons.fullscreen, onTap: widget.onExpand),
          const SizedBox(width: 8),
          _buildControlButton(icon: Icons.close, onTap: widget.onRemove, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onTap, Color? color}) {
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
