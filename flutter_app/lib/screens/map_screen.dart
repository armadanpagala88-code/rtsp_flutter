import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/cctv.dart';
import '../models/category.dart';
import '../providers/cctv_provider.dart';
import '../widgets/cctv_popup_export.dart';
import '../widgets/map_layer_selector.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  
  // Default center: Kabupaten Konawe, Indonesia
  static const LatLng _defaultCenter = LatLng(-3.8513609, 122.0338782);
  static const double _defaultZoom = 14.0;

  Cctv? _selectedCctv;
  bool _showLayerSelector = false;
  
  // Trash bin overlay
  List<Map<String, dynamic>> _trashBins = [];
  bool _showTrashBins = true;
  Map<String, dynamic>? _selectedTrashBin;

  // GeoJSON layers - multi-entity support
  List<Map<String, dynamic>> _kecamatanEntities = [];
  List<Map<String, dynamic>> _kelurahanEntities = [];
  Map<String, Map<String, dynamic>> _kecamatanData = {};
  Map<String, Map<String, dynamic>> _kelurahanData = {};
  Map<String, bool> _kecamatanVisibility = {};
  Map<String, bool> _kelurahanVisibility = {};
  bool _showLayerControls = false;

  @override
  void initState() {
    super.initState();
    _loadTrashBins();
    _loadGeoJsonLayers();
  }

  Future<void> _loadGeoJsonLayers() async {
    try {
      // Load metadata
      final kecamatanList = await ApiService.getKecamatanList();
      final kelurahanList = await ApiService.getKelurahanList();
      
      setState(() {
        _kecamatanEntities = kecamatanList;
        _kelurahanEntities = kelurahanList;
        // Initialize visibility (all visible by default)
        for (var kec in kecamatanList) {
          _kecamatanVisibility[kec['id']] = true;
        }
        for (var kel in kelurahanList) {
          _kelurahanVisibility[kel['id']] = true;
        }
      });
      
      // Load GeoJSON data for each entity
      for (var kec in kecamatanList) {
        final data = await ApiService.getKecamatanData(kec['id']);
        if (data != null) {
          setState(() => _kecamatanData[kec['id']] = data);
        }
      }
      
      for (var kel in kelurahanList) {
        final data = await ApiService.getKelurahanData(kel['id']);
        if (data != null) {
          setState(() => _kelurahanData[kel['id']] = data);
        }
      }
    } catch (e) {
      print('Error loading GeoJSON layers: $e');
    }
  }


  Future<void> _loadTrashBins() async {
    try {
      final list = await ApiService.getTrashBins();
      setState(() => _trashBins = list);
    } catch (e) {
      print('Error loading trash bins: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CctvProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final cctvList = provider.filteredCctvList;

        return Stack(
          children: [
            // Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: _defaultZoom,
                minZoom: 5,
                maxZoom: 18,
                onMapReady: () {
                  _mapController.move(_defaultCenter, _defaultZoom);
                },
                onTap: (_, __) {
                  setState(() => _selectedCctv = null);
                },
              ),
              children: [
                // Tile Layer (Dynamic from Provider)
                TileLayer(
                  urlTemplate: provider.selectedTileUrl,
                  userAgentPackageName: 'com.rtsp.cctv_streaming',
                ),
                // GeoJSON Kecamatan Layers (render each entity)
                ..._kecamatanEntities.where((kec) => 
                  _kecamatanVisibility[kec['id']] == true &&
                  _kecamatanData.containsKey(kec['id'])
                ).map((kec) {
                  final color = _parseColor(kec['color'] ?? '#0000FF');
                  return PolygonLayer(
                    polygons: _buildPolygonsFromGeoJson(
                      _kecamatanData[kec['id']]!,
                      color.withOpacity(0.4), // Fill color with 40% opacity
                      color,
                    ),
                  );
                }),
                // GeoJSON Kelurahan Layers (render each entity)
                ..._kelurahanEntities.where((kel) => 
                  _kelurahanVisibility[kel['id']] == true &&
                  _kelurahanData.containsKey(kel['id'])
                ).map((kel) {
                  final color = _parseColor(kel['color'] ?? '#00FF00');
                  return PolygonLayer(
                    polygons: _buildPolygonsFromGeoJson(
                      _kelurahanData[kel['id']]!,
                      color.withOpacity(0.3), // Fill color with 30% opacity
                      color,
                    ),
                  );
                }),
                // Polygon Labels - Kecamatan names
                MarkerLayer(
                  markers: _kecamatanEntities.where((kec) => 
                    _kecamatanVisibility[kec['id']] == true &&
                    _kecamatanData.containsKey(kec['id'])
                  ).map((kec) {
                    final centroid = _calculatePolygonCentroid(_kecamatanData[kec['id']]!);
                    if (centroid == null) return null;
                    return Marker(
                      point: centroid,
                      width: 150,
                      height: 40,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _parseColor(kec['color'] ?? '#0000FF'), width: 1.5),
                          ),
                          child: Text(
                            kec['name'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _parseColor(kec['color'] ?? '#0000FF'),
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
                ),
                // Polygon Labels - Kelurahan names
                MarkerLayer(
                  markers: _kelurahanEntities.where((kel) => 
                    _kelurahanVisibility[kel['id']] == true &&
                    _kelurahanData.containsKey(kel['id'])
                  ).map((kel) {
                    final centroid = _calculatePolygonCentroid(_kelurahanData[kel['id']]!);
                    if (centroid == null) return null;
                    return Marker(
                      point: centroid,
                      width: 150,
                      height: 40,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _parseColor(kel['color'] ?? '#00FF00'), width: 1.5),
                          ),
                          child: Text(
                            kel['name'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _parseColor(kel['color'] ?? '#00FF00'),
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
                ),
                // Trash Bin Markers Layer (rendered first, so it appears behind CCTV)
                if (_showTrashBins)
                  MarkerLayer(
                    markers: _trashBins.map((tb) => _buildTrashBinMarker(tb)).toList(),
                  ),
                // CCTV Markers Layer (rendered last, so it appears on top)
                MarkerLayer(
                  markers: cctvList.map((cctv) => _buildMarker(cctv, provider)).toList(),
                ),
              ],
            ),
            // Selected CCTV Popup - Centered on screen
            if (_selectedCctv != null)
              Positioned.fill(
                child: Center(
                  child: CctvPopup(
                    cctv: _selectedCctv!,
                    onClose: () => setState(() => _selectedCctv = null),
                    onSelect: () {
                      if (provider.isSelected(_selectedCctv!)) {
                        provider.removeFromSelection(_selectedCctv!);
                      } else {
                        provider.addToSelection(_selectedCctv!);
                      }
                    },
                    isSelected: provider.isSelected(_selectedCctv!),
                  ),
                ),
              ),
            // Category filter indicator
            if (provider.selectedCategory != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        provider.getCategoryById(provider.selectedCategory!)?.iconData ??
                            Icons.category,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Filter: ${provider.getCategoryById(provider.selectedCategory!)?.name ?? provider.selectedCategory}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${cctvList.length} CCTV',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => provider.clearCategoryFilter(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Zoom controls
            Positioned(
              right: 16,
              bottom: _selectedCctv != null ? 200 : 100,
              child: Column(
                children: [
                  _buildZoomButton(
                    icon: Icons.add,
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        currentZoom + 1,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildZoomButton(
                    icon: Icons.remove,
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        currentZoom - 1,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildZoomButton(
                    icon: Icons.my_location,
                    onTap: () {
                      _mapController.move(_defaultCenter, _defaultZoom);
                    },
                  ),
                ],
              ),
            ),
            
            // Map Layer Toggle Button
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'layer_toggle',
                    onPressed: () => setState(() => _showLayerSelector = !_showLayerSelector),
                    backgroundColor: Theme.of(context).cardColor,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.layers),
                  ),
                  if (_showLayerSelector)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: MapLayerSelector(),
                    ),
                ],
              ),
            ),
            // GeoJSON Layer Controls
            Positioned(
              top: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Layer control toggle button
                  FloatingActionButton.small(
                    heroTag: 'geojson_toggle',
                    onPressed: () => setState(() => _showLayerControls = !_showLayerControls),
                    backgroundColor: Theme.of(context).cardColor,
                    foregroundColor: Colors.blue,
                    child: const Icon(Icons.map_outlined),
                  ),
                  // Layer controls panel
                  if (_showLayerControls)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 400, maxWidth: 250),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with "Semua" toggle
                            Row(
                              children: [
                                const Text(
                                  'Batas Wilayah',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                // Toggle ALL kecamatan
                                SizedBox(
                                  height: 14,
                                  child: Transform.scale(
                                    scale: 0.5,
                                    child: Switch(
                                      value: _kecamatanVisibility.values.every((v) => v),
                                      onChanged: (value) {
                                        setState(() {
                                          for (var key in _kecamatanVisibility.keys) {
                                            _kecamatanVisibility[key] = value;
                                          }
                                        });
                                      },
                                      activeColor: Colors.blue,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            
                            // Kecamatan with grouped Kelurahan
                            if (_kecamatanEntities.isNotEmpty)
                              ..._kecamatanEntities.map((kec) {
                                final kecColor = _parseColor(kec['color'] ?? '#0000FF');
                                final kecId = kec['id'];
                                final kecName = kec['name'] ?? 'Unknown';
                                
                                // Get kelurahan for this kecamatan
                                final kelurahanInKec = _kelurahanEntities
                                    .where((kel) => kel['kecamatanId'] == kecId)
                                    .toList();
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Kecamatan header with toggle
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: kecColor.withOpacity(0.5),
                                            border: Border.all(color: kecColor, width: 1.5),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            kecName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        SizedBox(
                                          height: 14,
                                          child: Transform.scale(
                                            scale: 0.5,
                                            child: Switch(
                                              value: _kecamatanVisibility[kecId] == true,
                                              onChanged: (value) => setState(() => _kecamatanVisibility[kecId] = value),
                                              activeColor: kecColor,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Kelurahan items under this kecamatan
                                    if (kelurahanInKec.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 20, top: 4, bottom: 8),
                                        child: Column(
                                          children: kelurahanInKec.map((kel) {
                                            final kelColor = _parseColor(kel['color'] ?? '#00FF00');
                                            final kelId = kel['id'];
                                            final kelName = kel['name'] ?? 'Unknown';
                                            
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 3),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: kelColor.withOpacity(0.5),
                                                      border: Border.all(color: kelColor, width: 1.5),
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      kelName,
                                                      style: const TextStyle(fontSize: 10),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  SizedBox(
                                                    height: 14,
                                                    child: Transform.scale(
                                                      scale: 0.5,
                                                      child: Switch(
                                                        value: _kelurahanVisibility[kelId] == true,
                                                        onChanged: (value) => setState(() => _kelurahanVisibility[kelId] = value),
                                                        activeColor: kelColor,
                                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                  ],
                                );
                              }),
                            
                            // Empty state
                            if (_kecamatanEntities.isEmpty && _kelurahanEntities.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'Belum ada layer.\nUpload via Admin Panel.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Marker _buildMarker(Cctv cctv, CctvProvider provider) {
    final category = Categories.getById(cctv.category);
    final isSelected = provider.isSelected(cctv);
    final isActive = _selectedCctv?.id == cctv.id;

    return Marker(
      point: LatLng(cctv.location.lat, cctv.location.lng),
      width: isActive ? 50 : 40,
      height: isActive ? 50 : 40,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCctv = cctv);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.green
                : (category?.color ?? const Color(0xFFE53935)),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isActive ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSelected
                        ? Colors.green
                        : (category?.color ?? const Color(0xFFE53935)))
                    .withOpacity(0.5),
                blurRadius: isActive ? 15 : 8,
                spreadRadius: isActive ? 3 : 1,
              ),
            ],
          ),
          child: Icon(
            cctv.isOnline ? Icons.videocam : Icons.videocam_off,
            color: Colors.white,
            size: isActive ? 24 : 20,
          ),
        ),
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, size: 24),
      ),
    );
  }

  Marker _buildTrashBinMarker(Map<String, dynamic> trashBin) {
    final location = trashBin['location'] ?? {};
    final lat = (location['lat'] ?? 0).toDouble();
    final lng = (location['lng'] ?? 0).toDouble();
    final isActive = _selectedTrashBin?['id'] == trashBin['id'];

    return Marker(
      point: LatLng(lat, lng),
      width: isActive ? 50 : 40,
      height: isActive ? 50 : 40,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTrashBin = trashBin);
          _showTrashBinPopup(trashBin);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isActive ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.5),
                blurRadius: isActive ? 15 : 8,
                spreadRadius: isActive ? 3 : 1,
              ),
            ],
          ),
          child: Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: isActive ? 24 : 20,
          ),
        ),
      ),
    );
  }

  void _showTrashBinPopup(Map<String, dynamic> trashBin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                trashBin['name'] ?? 'Bak Sampah',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trashBin['photoUrl'] != null)
              Container(
                height: 150,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage('http://localhost:3000${trashBin['photoUrl']}'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Text(
              'Lokasi:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lat: ${trashBin['location']?['lat']?.toStringAsFixed(6) ?? 'N/A'}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Lng: ${trashBin['location']?['lng']?.toStringAsFixed(6) ?? 'N/A'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedTrashBin = null);
            },
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  /// Build polygons from GeoJSON data
  List<Polygon> _buildPolygonsFromGeoJson(
    Map<String, dynamic> geojson,
    Color fillColor,
    Color borderColor,
  ) {
    final polygons = <Polygon>[];
    
    try {
      final features = geojson['features'] as List<dynamic>? ?? [];
      
      for (final feature in features) {
        final geometry = feature['geometry'];
        if (geometry == null) continue;
        
        final type = geometry['type'] as String?;
        final coordinates = geometry['coordinates'];
        
        if (type == 'Polygon' && coordinates != null) {
          final points = _parsePolygonCoordinates(coordinates[0]);
          if (points.isNotEmpty) {
            polygons.add(Polygon(
              points: points,
              color: fillColor,
              borderColor: borderColor,
              borderStrokeWidth: 2,
            ));
          }
        } else if (type == 'MultiPolygon' && coordinates != null) {
          for (final polygon in coordinates) {
            final points = _parsePolygonCoordinates(polygon[0]);
            if (points.isNotEmpty) {
              polygons.add(Polygon(
                points: points,
                color: fillColor,
                borderColor: borderColor,
                borderStrokeWidth: 2,
              ));
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing GeoJSON: $e');
    }
    
    return polygons;
  }

  List<LatLng> _parsePolygonCoordinates(List<dynamic> coords) {
    return coords.map((coord) {
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      return LatLng(lat, lng);
    }).toList();
  }

  LatLng? _calculatePolygonCentroid(Map<String, dynamic> geojson) {
    try {
      final features = geojson['features'] as List<dynamic>? ?? [];
      if (features.isEmpty) return null;

      // Get first feature's geometry
      final firstFeature = features.first;
      final geometry = firstFeature['geometry'];
      if (geometry == null) return null;

      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];
      
      List<LatLng> points = [];
      
      if (type == 'Polygon' && coordinates != null) {
        points = _parsePolygonCoordinates(coordinates[0]);
      } else if (type == 'MultiPolygon' && coordinates != null && coordinates.isNotEmpty) {
        // Use first polygon of multipolygon
        points = _parsePolygonCoordinates(coordinates[0][0]);
      }

      if (points.isEmpty) return null;

      // Calculate centroid (average of all points)
      double totalLat = 0;
      double totalLng = 0;
      for (var point in points) {
        totalLat += point.latitude;
        totalLng += point.longitude;
      }

      return LatLng(totalLat / points.length, totalLng / points.length);
    } catch (e) {
      print('Error calculating centroid: $e');
      return null;
    }
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  Widget _buildEntityToggle(
    String label,
    bool value,
    Color color,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.5),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 16,
          child: Transform.scale(
            scale: 0.7,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLayerToggle(
    String label,
    bool value,
    Color color,
    bool hasData,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: hasData ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
            border: Border.all(color: hasData ? color : Colors.grey, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: hasData ? null : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 24,
          child: Switch(
            value: value && hasData,
            onChanged: hasData ? onChanged : null,
            activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

