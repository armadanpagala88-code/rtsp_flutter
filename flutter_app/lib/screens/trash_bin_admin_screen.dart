import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/cctv_provider.dart';

class TrashBinAdminScreen extends StatefulWidget {
  const TrashBinAdminScreen({super.key});

  @override
  State<TrashBinAdminScreen> createState() => _TrashBinAdminScreenState();
}

class _TrashBinAdminScreenState extends State<TrashBinAdminScreen> {
  List<Map<String, dynamic>> _trashBins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrashBins();
  }

  Future<void> _loadTrashBins() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getTrashBins();
      setState(() {
        _trashBins = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? trashBin}) {
    showDialog(
      context: context,
      builder: (context) => TrashBinFormDialog(
        trashBin: trashBin,
        onSave: _loadTrashBins,
      ),
    );
  }

  Future<void> _deleteTrashBin(Map<String, dynamic> trashBin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Bak Sampah'),
        content: Text('Apakah Anda yakin ingin menghapus "${trashBin['name']}"?'),
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
        await ApiService.deleteTrashBin(trashBin['id']);
        _loadTrashBins();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${trashBin['name']} berhasil dihapus')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.delete_outline),
            SizedBox(width: 10),
            Text('Kelola Bak Sampah'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrashBins,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trashBins.isEmpty
              ? _buildEmptyState()
              : _buildTrashBinList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Bak Sampah'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Belum ada Bak Sampah',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          const Text('Klik tombol + untuk menambah bak sampah baru'),
        ],
      ),
    );
  }

  Widget _buildTrashBinList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trashBins.length,
      itemBuilder: (context, index) {
        final trashBin = _trashBins[index];
        final location = trashBin['location'] ?? {};

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.green),
            ),
            title: Text(
              trashBin['name'] ?? 'Tanpa Nama',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Lat: ${location['lat']?.toStringAsFixed(6) ?? 'N/A'}, Lng: ${location['lng']?.toStringAsFixed(6) ?? 'N/A'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (trashBin['photoUrl'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      height: 60,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage('http://localhost:3000${trashBin['photoUrl']}'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showAddEditDialog(trashBin: trashBin),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTrashBin(trashBin),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TrashBinFormDialog extends StatefulWidget {
  final Map<String, dynamic>? trashBin;
  final VoidCallback onSave;

  const TrashBinFormDialog({
    super.key,
    this.trashBin,
    required this.onSave,
  });

  @override
  State<TrashBinFormDialog> createState() => _TrashBinFormDialogState();
}

class _TrashBinFormDialogState extends State<TrashBinFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(-3.8513609, 122.0338782);
  bool _isSaving = false;

  bool get isEditing => widget.trashBin != null;

  @override
  void initState() {
    super.initState();
    if (widget.trashBin != null) {
      final tb = widget.trashBin!;
      _nameController.text = tb['name'] ?? '';
      final location = tb['location'] ?? {};
      _latController.text = (location['lat'] ?? -3.8513609).toString();
      _lngController.text = (location['lng'] ?? 122.0338782).toString();
      _currentLocation = LatLng(
        location['lat'] ?? -3.8513609,
        location['lng'] ?? 122.0338782,
      );
    } else {
      _latController.text = '-3.8513609';
      _lngController.text = '122.0338782';
    }

    _latController.addListener(_onManualCoordChange);
    _lngController.addListener(_onManualCoordChange);
  }

  void _onManualCoordChange() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat != null && lng != null) {
      final newLoc = LatLng(lat, lng);
      if (newLoc != _currentLocation) {
        setState(() => _currentLocation = newLoc);
        _mapController.move(newLoc, _mapController.camera.zoom);
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _currentLocation = latLng;
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
        'lat': double.tryParse(_latController.text) ?? -3.8513609,
        'lng': double.tryParse(_lngController.text) ?? 122.0338782,
      };

      bool success;
      if (isEditing) {
        success = await ApiService.updateTrashBin(widget.trashBin!['id'], data);
      } else {
        success = await ApiService.createTrashBin(data);
      }

      if (success) {
        widget.onSave();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? 'Bak sampah berhasil diperbarui'
                    : 'Bak sampah berhasil ditambahkan',
              ),
            ),
          );
        }
      } else {
        throw Exception('Gagal menyimpan');
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
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Bak Sampah' : 'Tambah Bak Sampah Baru',
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
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Bak Sampah *',
                          hintText: 'Contoh: Bak Sampah Jl. Merdeka',
                          prefixIcon: Icon(Icons.label),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latController,
                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lngController,
                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                                      Icons.delete_outline,
                                      color: Colors.green,
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
                        '* Klik pada peta untuk memindahkan lokasi bak sampah',
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
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
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
