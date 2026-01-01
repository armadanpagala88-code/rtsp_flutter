import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

/// Mobile-compatible GeoJSON Admin Screen
/// Uses file_picker instead of dart:html FileUploadInputElement
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoJSON Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKecamatanSection(),
                    const SizedBox(height: 24),
                    _buildKelurahanSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKecamatanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kecamatan Layers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _showAddKecamatanDialog,
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_kecamatanList.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada layer kecamatan'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _kecamatanList.length,
            itemBuilder: (context, index) {
              final item = _kecamatanList[index];
              return Card(
                child: ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _parseColor(item['color']),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(item['name'] ?? 'Unknown'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteKecamatan(item['id']),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildKelurahanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kelurahan Layers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _showAddKelurahanDialog,
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_kelurahanList.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada layer kelurahan'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _kelurahanList.length,
            itemBuilder: (context, index) {
              final item = _kelurahanList[index];
              return Card(
                child: ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _parseColor(item['color']),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(item['name'] ?? 'Unknown'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteKelurahan(item['id']),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null) return Colors.grey;
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  Future<void> _showAddKecamatanDialog() async {
    String name = '';
    Color selectedColor = Colors.blue;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tambah Kecamatan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Nama Kecamatan'),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 16),
                const Text('Warna Layer:'),
                ColorPicker(
                  color: selectedColor,
                  onColorChanged: (c) => setState(() => selectedColor = c),
                  pickersEnabled: const {ColorPickerType.primary: true},
                  width: 40,
                  height: 40,
                  borderRadius: 4,
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
              onPressed: () => Navigator.pop(context, {
                'name': name,
                'color': '#${selectedColor.value.toRadixString(16).substring(2)}',
              }),
              child: const Text('Pilih File'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['name'].isNotEmpty) {
      await _uploadKecamatanFile(result['name'], result['color']);
    }
  }

  Future<void> _uploadKecamatanFile(String name, String color) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'geojson'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes;
      
      if (bytes != null) {
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
    }
  }

  Future<void> _showAddKelurahanDialog() async {
    String name = '';
    String? selectedKecamatanId;
    Color selectedColor = Colors.green;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tambah Kelurahan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Nama Kelurahan'),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Pilih Kecamatan'),
                  value: selectedKecamatanId,
                  items: _kecamatanList.map((k) => DropdownMenuItem(
                    value: k['id'] as String,
                    child: Text(k['name'] ?? 'Unknown'),
                  )).toList(),
                  onChanged: (v) => setState(() => selectedKecamatanId = v),
                ),
                const SizedBox(height: 16),
                const Text('Warna Layer:'),
                ColorPicker(
                  color: selectedColor,
                  onColorChanged: (c) => setState(() => selectedColor = c),
                  pickersEnabled: const {ColorPickerType.primary: true},
                  width: 40,
                  height: 40,
                  borderRadius: 4,
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
              onPressed: selectedKecamatanId == null ? null : () => Navigator.pop(context, {
                'name': name,
                'kecamatanId': selectedKecamatanId,
                'color': '#${selectedColor.value.toRadixString(16).substring(2)}',
              }),
              child: const Text('Pilih File'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['name'].isNotEmpty && result['kecamatanId'] != null) {
      await _uploadKelurahanFile(result['name'], result['kecamatanId'], result['color']);
    }
  }

  Future<void> _uploadKelurahanFile(String name, String kecamatanId, String color) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'geojson'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final bytes = file.bytes;
      
      if (bytes != null) {
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
    }
  }

  Future<void> _deleteKecamatan(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kecamatan'),
        content: const Text('Yakin ingin menghapus layer ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await ApiService.deleteKecamatan(id);
      _loadData();
    }
  }

  Future<void> _deleteKelurahan(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kelurahan'),
        content: const Text('Yakin ingin menghapus layer ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await ApiService.deleteKelurahan(id);
      _loadData();
    }
  }
}
