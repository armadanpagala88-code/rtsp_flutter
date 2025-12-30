import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cctv.dart';
import '../models/category.dart';
import '../providers/cctv_provider.dart';
import '../services/api_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'category_admin_screen.dart';
import 'trash_bin_admin_screen.dart';
import 'user_admin_screen.dart';
import 'geojson_admin_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Cctv> _cctvList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCctvList();
  }

  Future<void> _loadCctvList() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getAllCctv();
      setState(() {
        _cctvList = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddEditDialog({Cctv? cctv}) {
    showDialog(
      context: context,
      builder: (context) => CctvFormDialog(
        cctv: cctv,
        onSave: () {
          _loadCctvList();
          // Refresh provider data too
          Provider.of<CctvProvider>(context, listen: false).fetchCctvList();
        },
      ),
    );
  }

  Future<void> _deleteCctv(Cctv cctv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus CCTV'),
        content: Text('Apakah Anda yakin ingin menghapus "${cctv.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteCctv(cctv.id);
        _loadCctvList();
        Provider.of<CctvProvider>(context, listen: false).fetchCctvList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${cctv.name} berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Custom App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings),
                    const SizedBox(width: 10),
                    const Text(
                      'Admin - Kelola CCTV',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Navigate to User Admin
                    IconButton(
                      icon: const Icon(Icons.people),
                      tooltip: 'Kelola User',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UserAdminScreen()),
                        );
                      },
                    ),
                    // Navigate to Category Admin
                    IconButton(
                      icon: const Icon(Icons.category),
                      tooltip: 'Kelola Kategori',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CategoryAdminScreen()),
                        );
                      },
                    ),
                    // Navigate to Trash Bin Admin
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Kelola Bak Sampah',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TrashBinAdminScreen()),
                        );
                      },
                    ),
                    // Navigate to GeoJSON Admin
                    IconButton(
                      icon: const Icon(Icons.map),
                      tooltip: 'Kelola Layer GeoJSON',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GeoJsonAdminScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadCctvList,
                    ),
                  ],
                ),
              ),
            ),
            // Body content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _cctvList.isEmpty
                      ? _buildEmptyState()
                      : _buildCctvList(),
            ),
          ],
        ),
        // Floating Action Button
        Positioned(
          right: 16,
          bottom: 180, // Much higher to avoid bottom nav bar
          child: FloatingActionButton.extended(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah CCTV'),
            backgroundColor: const Color(0xFFE53935),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada CCTV',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text('Klik tombol + untuk menambah CCTV baru'),
        ],
      ),
    );
  }

  Widget _buildCctvList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cctvList.length,
      itemBuilder: (context, index) {
        final cctv = _cctvList[index];
        final category = Categories.getById(cctv.category);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: (category?.color ?? Colors.red).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                cctv.isOnline ? Icons.videocam : Icons.videocam_off,
                color: category?.color ?? Colors.red,
              ),
            ),
            title: Text(
              cctv.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  cctv.owner,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (category?.color ?? Colors.red).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category?.name ?? cctv.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: category?.color ?? Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cctv.isOnline
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cctv.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          color: cctv.isOnline ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'RTSP: ${cctv.streams.isNotEmpty ? cctv.streams[0].url : "N/A"}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showAddEditDialog(cctv: cctv),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteCctv(cctv),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CctvFormDialog extends StatefulWidget {
  final Cctv? cctv;
  final VoidCallback onSave;

  const CctvFormDialog({
    super.key,
    this.cctv,
    required this.onSave,
  });

  @override
  State<CctvFormDialog> createState() => _CctvFormDialogState();
}

class _CctvFormDialogState extends State<CctvFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _rtspUrlController = TextEditingController();
  final _rtspUrlHdController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  String _selectedCategory = 'PANTAU_LALIN';
  String _selectedStatus = 'online';
  bool _isSaving = false;
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(-3.8513609, 122.0338782);

  bool get isEditing => widget.cctv != null;

  @override
  void initState() {
    super.initState();
    if (widget.cctv != null) {
      final cctv = widget.cctv!;
      _nameController.text = cctv.name;
      _ownerController.text = cctv.owner;
      _selectedCategory = cctv.category;
      _selectedStatus = cctv.status;
      _latController.text = cctv.location.lat.toString();
      _lngController.text = cctv.location.lng.toString();
      if (cctv.streams.isNotEmpty) {
        _rtspUrlController.text = cctv.streams[0].url;
        if (cctv.streams.length > 1) {
          _rtspUrlHdController.text = cctv.streams[1].url;
        }
      }
    } else {
      // Default values for new CCTV - Kendari coordinates
      _latController.text = '-3.8513609';
      _lngController.text = '122.0338782';
      _currentLocation = const LatLng(-3.8513609, 122.0338782);
    }

    // Listen to manual changes
    _latController.addListener(_onManualCoordChange);
    _lngController.addListener(_onManualCoordChange);
  }

  void _onManualCoordChange() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat != null && lng != null) {
      final newLoc = LatLng(lat, lng);
      if (newLoc != _currentLocation) {
        setState(() {
          _currentLocation = newLoc;
        });
        _mapController.move(newLoc, _mapController.camera.zoom);
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _currentLocation = latLng;
      // Temporarily remove listeners to avoid infinite loop
      _latController.removeListener(_onManualCoordChange);
      _lngController.removeListener(_onManualCoordChange);
      
      _latController.text = latLng.latitude.toStringAsFixed(7);
      _lngController.text = latLng.longitude.toStringAsFixed(7);
      
      _latController.addListener(_onManualCoordChange);
      _lngController.addListener(_onManualCoordChange);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _rtspUrlController.dispose();
    _rtspUrlHdController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'name': _nameController.text,
        'owner': _ownerController.text,
        'category': _selectedCategory,
        'status': _selectedStatus,
        'lat': double.tryParse(_latController.text) ?? -3.8513609,
        'lng': double.tryParse(_lngController.text) ?? 122.0338782,
        'rtspUrl': _rtspUrlController.text,
        'rtspUrlHd': _rtspUrlHdController.text.isNotEmpty
            ? _rtspUrlHdController.text
            : _rtspUrlController.text,
      };

      if (isEditing) {
        await ApiService.updateCctv(widget.cctv!.id, data);
      } else {
        await ApiService.createCctv(data);
      }

      widget.onSave();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'CCTV berhasil diperbarui'
                  : 'CCTV berhasil ditambahkan',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = Categories.getAll();

    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit CCTV' : 'Tambah CCTV Baru',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama CCTV *',
                          hintText: 'Contoh: SRIWIJAYA 01',
                          prefixIcon: Icon(Icons.label),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // Owner
                      TextFormField(
                        controller: _ownerController,
                        decoration: const InputDecoration(
                          labelText: 'Pemilik',
                          hintText: 'Contoh: DISKOMINFO KOTA SEMARANG',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // RTSP URL
                      TextFormField(
                        controller: _rtspUrlController,
                        decoration: const InputDecoration(
                          labelText: 'RTSP URL (Preview) *',
                          hintText: 'rtsp://user:pass@ip:port/stream',
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'RTSP URL wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),

                      // RTSP URL HD
                      TextFormField(
                        controller: _rtspUrlHdController,
                        decoration: const InputDecoration(
                          labelText: 'RTSP URL (HD/Main)',
                          hintText: 'Kosongkan jika sama dengan preview',
                          prefixIcon: Icon(Icons.hd),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Category & Status Row - Changed to Column to avoid overflow on small widths
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat.id,
                            child: Row(
                              children: [
                                Icon(cat.iconData,
                                    size: 18, color: cat.color),
                                const SizedBox(width: 8),
                                Text(cat.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedCategory = v);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // Status
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'online',
                            child: Row(
                              children: [
                                Icon(Icons.circle,
                                    size: 12, color: Colors.green),
                                const SizedBox(width: 8),
                                Text('Online'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'offline',
                            child: Row(
                              children: [
                                Icon(Icons.circle,
                                    size: 12, color: Colors.red),
                                const SizedBox(width: 8),
                                Text('Offline'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedStatus = v);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Location Row - Changed to Column to avoid overflow
                      TextFormField(
                        controller: _latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: '-3.8513609',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: '122.0338782',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      
                      // Map Picker
                      const Text(
                        'Pilih Lokasi dari Peta:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _currentLocation,
                              initialZoom: 13.0,
                              onTap: _onMapTap,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: context.read<CctvProvider>().selectedTileUrl,
                                userAgentPackageName: 'com.example.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _currentLocation,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '* Klik pada peta untuk memindahkan titik lokasi',
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(isEditing ? 'Simpan' : 'Tambah'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
