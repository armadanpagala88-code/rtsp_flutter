import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../services/api_service.dart';

class GeoJsonAdminScreen extends StatefulWidget {
  const GeoJsonAdminScreen({super.key});

  @override
  State<GeoJsonAdminScreen> createState() => _GeoJsonAdminScreenState();
}

class _GeoJsonAdminScreenState extends State<GeoJsonAdminScreen> {
  List<Map<String, dynamic>> _kecamatanList = [];
  List<Map<String, dynamic>> _kelurahanList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final kecamatan = await ApiService.getKecamatanList();
      final kelurahan = await ApiService.getKelurahanList();
      setState(() {
        _kecamatanList = kecamatan;
        _kelurahanList = kelurahan;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddKecamatanDialog() async {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;
    double lineWidth = 2.0;
    double fillOpacity = 0.4;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_city, color: Colors.blue),
              SizedBox(width: 8),
              Text('Tambah Kecamatan'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kecamatan *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.text_fields),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Warna Area:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ColorPicker(
                  color: selectedColor,
                  onColorChanged: (color) => setDialogState(() => selectedColor = color),
                  pickersEnabled: const {
                    ColorPickerType.wheel: true,
                    ColorPickerType.accent: false,
                  },
                  width: 40,
                  height: 40,
                  borderRadius: 4,
                  heading: const SizedBox(),
                  subheading: const SizedBox(),
                ),
                const SizedBox(height: 16),
                const Text('Ketebalan Garis:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: lineWidth,
                        min: 1.0,
                        max: 5.0,
                        divisions: 8,
                        label: '${lineWidth.toStringAsFixed(1)} px',
                        onChanged: (value) => setDialogState(() => lineWidth = value),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text('${lineWidth.toStringAsFixed(1)} px', textAlign: TextAlign.center),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Opacity Fill:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: fillOpacity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(fillOpacity * 100).toInt()}%',
                        onChanged: (value) => setDialogState(() => fillOpacity = value),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text('${(fillOpacity * 100).toInt()}%', textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama kecamatan wajib diisi')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'name': nameController.text,
                  'color': '#${selectedColor.value.toRadixString(16).substring(2)}',
                  'lineWidth': lineWidth,
                  'fillOpacity': fillOpacity,
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Lanjut Upload File'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      _uploadKecamatanFile(result['name'], result['color']);
    }
  }

  Future<void> _uploadKecamatanFile(String name, String color) async {
    final uploadInput = html.FileUploadInputElement()..accept = '.geojson,.json';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final file = files[0];
      final reader = html.FileReader();
      
      reader.onLoadEnd.listen((event) async {
        final result = reader.result;
        if (result is String) {
          final bytes = Uint8List.fromList(result.codeUnits);
          
          setState(() => _isLoading = true);
          
          final response = await ApiService.uploadKecamatan(
            name,
            color,
            bytes,
            file.name,
          );

          if (mounted) {
            setState(() => _isLoading = false);
            if (response['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Kecamatan "$name" berhasil ditambahkan')),
              );
              _loadData();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(response['error'] ?? 'Gagal upload')),
              );
            }
          }
        }
      });
      
      reader.readAsText(file);
    });
  }

  Future<void> _showAddKelurahanDialog() async {
    if (_kecamatanList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan kecamatan terlebih dahulu')),
      );
      return;
    }

    final nameController = TextEditingController();
    String? selectedKecamatanId = _kecamatanList.first['id'];
    Color selectedColor = Colors.green;
    double lineWidth = 2.0;
    double fillOpacity = 0.3;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.holiday_village, color: Colors.green),
              SizedBox(width: 8),
              Text('Tambah Kelurahan/Desa'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kelurahan/Desa *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.text_fields),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedKecamatanId,
                  decoration: const InputDecoration(
                    labelText: 'Kecamatan *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  items: _kecamatanList.map<DropdownMenuItem<String>>((kec) {
                    return DropdownMenuItem<String>(
                      value: kec['id'] as String,
                      child: Text(kec['name'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) => setDialogState(() => selectedKecamatanId = value),
                ),
                const SizedBox(height: 16),
                const Text('Warna Area:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ColorPicker(
                  color: selectedColor,
                  onColorChanged: (color) => setDialogState(() => selectedColor = color),
                  pickersEnabled: const {
                    ColorPickerType.wheel: true,
                    ColorPickerType.accent: false,
                  },
                  width: 40,
                  height: 40,
                  borderRadius: 4,
                  heading: const SizedBox(),
                  subheading: const SizedBox(),
                ),
                const SizedBox(height: 16),
                const Text('Ketebalan Garis:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: lineWidth,
                        min: 1.0,
                        max: 5.0,
                        divisions: 8,
                        label: '${lineWidth.toStringAsFixed(1)} px',
                        onChanged: (value) => setDialogState(() => lineWidth = value),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text('${lineWidth.toStringAsFixed(1)} px', textAlign: TextAlign.center),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Opacity Fill:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: fillOpacity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(fillOpacity * 100).toInt()}%',
                        onChanged: (value) => setDialogState(() => fillOpacity = value),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text('${(fillOpacity * 100).toInt()}%', textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty || selectedKecamatanId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mohon lengkapi semua field')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'name': nameController.text,
                  'kecamatanId': selectedKecamatanId,
                  'color': '#${selectedColor.value.toRadixString(16).substring(2)}',
                  'lineWidth': lineWidth,
                  'fillOpacity': fillOpacity,
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Lanjut Upload File'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      _uploadKelurahanFile(result['name'], result['kecamatanId'], result['color']);
    }
  }

  Future<void> _uploadKelurahanFile(String name, String kecamatanId, String color) async {
    final uploadInput = html.FileUploadInputElement()..accept = '.geojson,.json';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      final file = files[0];
      final reader = html.FileReader();
      
      reader.onLoadEnd.listen((event) async {
        final result = reader.result;
        if (result is String) {
          final bytes = Uint8List.fromList(result.codeUnits);
          
          setState(() => _isLoading = true);
          
          final response = await ApiService.uploadKelurahan(
            name,
            kecamatanId,
            color,
            bytes,
            file.name,
          );

          if (mounted) {
            setState(() => _isLoading = false);
            if (response['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Kelurahan "$name" berhasil ditambahkan')),
              );
              _loadData();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(response['error'] ?? 'Gagal upload')),
              );
            }
          }
        }
      });
      
      reader.readAsText(file);
    });
  }

  Future<void> _deleteKecamatan(Map<String, dynamic> kecamatan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kecamatan'),
        content: Text(
          'Hapus "${kecamatan['name']}"?\n\nKelurahan terkait juga akan dihapus.',
          style: const TextStyle(fontSize: 14),
        ),
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
      final response = await ApiService.deleteKecamatan(kecamatan['id']);
      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kecamatan berhasil dihapus')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['error'] ?? 'Gagal hapus')),
          );
        }
      }
    }
  }

  Future<void> _deleteKelurahan(Map<String, dynamic> kelurahan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kelurahan'),
        content: Text('Hapus "${kelurahan['name']}"?'),
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
      final response = await ApiService.deleteKelurahan(kelurahan['id']);
      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kelurahan berhasil dihapus')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['error'] ?? 'Gagal hapus')),
          );
        }
      }
    }
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.map),
            SizedBox(width: 10),
            Text('Kelola Layer GeoJSON'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kecamatan Section
                  Row(
                    children: [
                      const Icon(Icons.location_city, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Kecamatan',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showAddKecamatanDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_kecamatanList.isEmpty)
                    _buildEmptyState('Belum ada kecamatan')
                  else
                    ..._kecamatanList.map((kec) => _buildKecamatanCard(kec)),
                  
                  const SizedBox(height: 32),
                  
                  // Kelurahan Section
                  Row(
                    children: [
                      const Icon(Icons.holiday_village, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Kelurahan/Desa',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _showAddKelurahanDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_kelurahanList.isEmpty)
                    _buildEmptyState('Belum ada kelurahan/desa')
                  else
                    ..._kelurahanList.map((kel) => _buildKelurahanCard(kel)),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKecamatanCard(Map<String, dynamic> kecamatan) {
    final color = _parseColor(kecamatan['color'] ?? '#0000FF');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kecamatan['name'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_kelurahanList.where((k) => k['kecamatanId'] == kecamatan['id']).length} kelurahan',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteKecamatan(kecamatan),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKelurahanCard(Map<String, dynamic> kelurahan) {
    final color = _parseColor(kelurahan['color'] ?? '#00FF00');
    final kecamatan = _kecamatanList.firstWhere(
      (k) => k['id'] == kelurahan['kecamatanId'],
      orElse: () => {'name': 'Unknown'},
    );
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kelurahan['name'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_city, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        kecamatan['name'] ?? 'Unknown',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteKelurahan(kelurahan),
            ),
          ],
        ),
      ),
    );
  }
}
