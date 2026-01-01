import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cctv.dart';
import '../models/category.dart';

class ApiService {
  // Backend URL - Coolify VPS
  static const String baseUrl = 'http://hwg88ckg8k0cgss0ww00kcok.72.61.213.95.sslip.io/api';
  
  // Localhost alternatives (for development):
  // static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:3000/api'; // Web / iOS simulator

  // JWT Token storage
  static String? _authToken;

  // Set auth token after login
  static void setAuthToken(String token) {
    _authToken = token;
  }

  // Clear auth token on logout
  static void clearAuthToken() {
    _authToken = null;
  }

  // Get headers with auth token
  static Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Get all CCTV cameras
  static Future<List<Cctv>> getAllCctv({String? category, String? status}) async {
    try {
      String url = '$baseUrl/cctv';
      final queryParams = <String, String>{};
      
      if (category != null) queryParams['category'] = category;
      if (status != null) queryParams['status'] = status;
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      }

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((item) => Cctv.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching CCTV: $e');
      return [];
    }
  }

  /// Get CCTV by ID
  static Future<Cctv?> getCctvById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cctv/$id'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Cctv.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching CCTV: $e');
      return null;
    }
  }

  /// Get CCTV by category
  static Future<List<Cctv>> getCctvByCategory(String categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cctv/category/$categoryId'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((item) => Cctv.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching CCTV by category: $e');
      return [];
    }
  }

  /// Get all categories
  static Future<List<Category>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cctv/categories'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((item) => Category.fromJson(item))
              .toList();
        }
      }
      // Return default categories if API fails
      return Categories.getAll();
    } catch (e) {
      print('Error fetching categories: $e');
      return Categories.getAll();
    }
  }

  /// Get stream info for a CCTV
  static Future<Map<String, dynamic>?> getStreamInfo(String cctvId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/stream/$cctvId'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching stream info: $e');
      return null;
    }
  }

  /// Get statistics
  static Future<Map<String, dynamic>?> getStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cctv/stats/overview'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching stats: $e');
      return null;
    }
  }

  /// Health check
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ========== ADMIN CRUD OPERATIONS ==========

  /// Create new CCTV
  static Future<bool> createCctv(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/cctv'),
        headers: _getHeaders(),
        body: json.encode(data),
      );
      
      if (response.statusCode == 201) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error creating CCTV: $e');
      return false;
    }
  }

  /// Update CCTV
  static Future<bool> updateCctv(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/cctv/$id'),
        headers: _getHeaders(),
        body: json.encode(data),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error updating CCTV: $e');
      return false;
    }
  }

  /// Delete CCTV
  static Future<bool> deleteCctv(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/cctv/$id'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleting CCTV: $e');
      return false;
    }
  }

  /// Login admin
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );
      
      final result = json.decode(response.body);
      
      // Save token if login successful
      if (result['success'] == true && result['data']?['token'] != null) {
        setAuthToken(result['data']['token']);
      }
      
      return result;
    } catch (e) {
      print('Error logging in: $e');
      return {
        'success': false,
        'error': 'Gagal terhubung ke server',
      };
    }
  }

  // ========== CATEGORY CRUD OPERATIONS ==========

  /// Get categories from server
  static Future<List<Map<String, dynamic>>> getCategoriesFromServer() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/categories'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  /// Create new category
  static Future<bool> createCategory(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/categories'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error creating category: $e');
      return false;
    }
  }

  /// Update category
  static Future<bool> updateCategory(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/categories/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error updating category: $e');
      return false;
    }
  }

  /// Delete category
  static Future<bool> deleteCategory(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/categories/$id'));
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }

  // ========== TRASH BIN CRUD OPERATIONS ==========

  /// Get all trash bins
  static Future<List<Map<String, dynamic>>> getTrashBins() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/trash-bins'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching trash bins: $e');
      return [];
    }
  }

  /// Create new trash bin
  static Future<bool> createTrashBin(Map<String, dynamic> data) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/trash-bins'),
      );
      
      request.fields['name'] = data['name'] ?? '';
      request.fields['lat'] = data['lat'].toString();
      request.fields['lng'] = data['lng'].toString();
      
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('Error creating trash bin: $e');
      return false;
    }
  }

  /// Update trash bin
  static Future<bool> updateTrashBin(String id, Map<String, dynamic> data) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/trash-bins/$id'),
      );
      
      request.fields['name'] = data['name'] ?? '';
      request.fields['lat'] = data['lat'].toString();
      request.fields['lng'] = data['lng'].toString();
      
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating trash bin: $e');
      return false;
    }
  }

  /// Delete trash bin
  static Future<bool> deleteTrashBin(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/trash-bins/$id'));
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleting trash bin: $e');
      return false;
    }
  }

  // ========== USER CRUD OPERATIONS ==========

  /// Get all users
  static Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/users'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  /// Create new user
  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      
      return json.decode(response.body);
    } catch (e) {
      print('Error creating user: $e');
      return {'success': false, 'error': 'Gagal membuat user'};
    }
  }

  /// Update user
  static Future<Map<String, dynamic>> updateUser(String username, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/users/$username'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      
      return json.decode(response.body);
    } catch (e) {
      print('Error updating user: $e');
      return {'success': false, 'error': 'Gagal memperbarui user'};
    }
  }

  /// Delete user
  static Future<Map<String, dynamic>> deleteUser(String username) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/users/$username'),
      );
      
      return json.decode(response.body);
    } catch (e) {
      print('Error deleting user: $e');
      return {'success': false, 'error': 'Gagal menghapus user'};
    }
  }

  // ========== GEOJSON LAYER OPERATIONS ==========

  /// Get all kecamatan
  static Future<List<Map<String, dynamic>>> getKecamatanList() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/geojson/kecamatan'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching kecamatan: $e');
      return [];
    }
  }

  /// Get all kelurahan
  static Future<List<Map<String, dynamic>>> getKelurahanList() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/geojson/kelurahan'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching kelurahan: $e');
      return [];
    }
  }

  /// Get kecamatan GeoJSON data by ID
  static Future<Map<String, dynamic>?> getKecamatanData(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/geojson/kecamatan/$id/data'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching kecamatan data: $e');
      return null;
    }
  }

  /// Get kelurahan GeoJSON data by ID
  static Future<Map<String, dynamic>?> getKelurahanData(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/geojson/kelurahan/$id/data'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching kelurahan data: $e');
      return null;
    }
  }

  /// Upload kecamatan GeoJSON
  static Future<Map<String, dynamic>> uploadKecamatan(
    String name,
    String color,
    List<int> fileBytes,
    String filename,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/geojson/kecamatan'),
      );
      
      request.fields['name'] = name;
      request.fields['color'] = color;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return json.decode(response.body);
    } catch (e) {
      print('Error uploading kecamatan: $e');
      return {'success': false, 'error': 'Gagal upload kecamatan'};
    }
  }

  /// Upload kelurahan GeoJSON
  static Future<Map<String, dynamic>> uploadKelurahan(
    String name,
    String kecamatanId,
    String color,
    List<int> fileBytes,
    String filename,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/geojson/kelurahan'),
      );
      
      request.fields['name'] = name;
      request.fields['kecamatanId'] = kecamatanId;
      request.fields['color'] = color;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return json.decode(response.body);
    } catch (e) {
      print('Error uploading kelurahan: $e');
      return {'success': false, 'error': 'Gagal upload kelurahan'};
    }
  }

  /// Delete kecamatan
  static Future<Map<String, dynamic>> deleteKecamatan(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/geojson/kecamatan/$id'));
      return json.decode(response.body);
    } catch (e) {
      print('Error deleting kecamatan: $e');
      return {'success': false, 'error': 'Gagal menghapus kecamatan'};
    }
  }

  /// Delete kelurahan
  static Future<Map<String, dynamic>> deleteKelurahan(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/geojson/kelurahan/$id'));
      return json.decode(response.body);
    } catch (e) {
      print('Error deleting kelurahan: $e');
      return {'success': false, 'error': 'Gagal menghapus kelurahan'};
    }
  }

  // ========== AI DETECTION OPERATIONS ==========

  /// Check AI service health
  static Future<bool> checkAiHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ai/health'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking AI health: $e');
      return false;
    }
  }

  /// Start AI detection on a stream
  static Future<Map<String, dynamic>> startAiDetection(String cctvId, String quality) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/start'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cctvId': cctvId,
          'quality': quality,
        }),
      );
      
      return json.decode(response.body);
    } catch (e) {
      print('Error starting AI detection: $e');
      return {
        'success': false,
        'error': 'Gagal memulai AI detection',
      };
    }
  }

  /// Stop AI detection on a stream
  static Future<Map<String, dynamic>> stopAiDetection(String cctvId, String quality) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/stop'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cctvId': cctvId,
          'quality': quality,
        }),
      );
      
      return json.decode(response.body);
    } catch (e) {
      print('Error stopping AI detection: $e');
      return {
        'success': false,
        'error': 'Gagal menghentikan AI detection',
      };
    }
  }

  /// Get AI detection statistics for a stream
  static Future<Map<String, dynamic>?> getAiStats(String cctvId, String quality) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ai/stats/$cctvId?quality=$quality'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error getting AI stats: $e');
      return null;
    }
  }

  /// Get all active AI streams
  static Future<List<String>> getActiveAiStreams() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ai/active'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<String>.from(data['streams'] ?? []);
        }
      }
      return [];
    } catch (e) {
      print('Error getting active AI streams: $e');
      return [];
    }
  }

  /// Get AI stream URL
  static String getAiStreamUrl(String streamId) {
    return '$baseUrl/ai/stream/$streamId';
  }
}

