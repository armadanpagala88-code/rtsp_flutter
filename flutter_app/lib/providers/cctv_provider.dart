import 'package:flutter/material.dart';
import '../models/cctv.dart';
import '../models/category.dart';
import '../services/api_service.dart';

class CctvProvider extends ChangeNotifier {
  List<Cctv> _cctvList = [];
  List<Category> _categories = [];
  String? _selectedCategory;
  bool _isLoading = false;
  String? _error;
  List<Cctv> _selectedCctvs = [];
  
  // Auth state
  bool _isLoggedIn = false;
  String? _adminToken;

  // Map Layer state
  String _selectedTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  String _selectedLayerName = 'OpenStreetMap';

  // Getters
  List<Cctv> get cctvList => _cctvList;
  List<Cctv> get allCctvList => _cctvList; // Alias for multi-stream dialog
  List<Category> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Cctv> get selectedCctvs => _selectedCctvs;
  bool get isLoggedIn => _isLoggedIn;
  String get selectedTileUrl => _selectedTileUrl;
  String get selectedLayerName => _selectedLayerName;

  List<Cctv> get filteredCctvList {
    if (_selectedCategory == null) return _cctvList;
    return _cctvList.where((c) => c.category == _selectedCategory).toList();
  }

  int get onlineCount => _cctvList.where((c) => c.isOnline).length;
  int get offlineCount => _cctvList.where((c) => !c.isOnline).length;

  /// Safe notify that avoids calling during build phase
  void _safeNotifyListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Initialize provider
  Future<void> initialize() async {
    await Future.wait([
      fetchCctvList(),
      fetchCategories(),
    ]);
  }

  /// Fetch all CCTV
  Future<void> fetchCctvList() async {
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      _cctvList = await ApiService.getAllCctv();
    } catch (e) {
      _error = 'Failed to load CCTV list';
    }

    _isLoading = false;
    _safeNotifyListeners();
  }

  /// Fetch categories
  Future<void> fetchCategories() async {
    try {
      _categories = await ApiService.getCategories();
      _safeNotifyListeners();
    } catch (e) {
      _categories = Categories.getAll();
    }
  }

  /// Set selected category
  void setSelectedCategory(String? categoryId) {
    _selectedCategory = categoryId;
    notifyListeners();
  }

  /// Clear category filter
  void clearCategoryFilter() {
    _selectedCategory = null;
    notifyListeners();
  }

  /// Add CCTV to selection (for multi-stream view)
  void addToSelection(Cctv cctv) {
    if (!_selectedCctvs.any((c) => c.id == cctv.id)) {
      _selectedCctvs.add(cctv);
      notifyListeners();
    }
  }

  /// Remove CCTV from selection
  void removeFromSelection(Cctv cctv) {
    _selectedCctvs.removeWhere((c) => c.id == cctv.id);
    notifyListeners();
  }

  /// Clear selection
  void clearSelection() {
    _selectedCctvs.clear();
    notifyListeners();
  }

  /// Check if CCTV is selected
  bool isSelected(Cctv cctv) {
    return _selectedCctvs.any((c) => c.id == cctv.id);
  }

  /// Get CCTV by ID
  Cctv? getCctvById(String id) {
    try {
      return _cctvList.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get category by ID
  Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return Categories.getById(id);
    }
  }

  /// Get CCTV count by category
  int getCctvCountByCategory(String categoryId) {
    return _cctvList.where((c) => c.category == categoryId).length;
  }

  // Auth Methods
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await ApiService.login(username, password);
      if (result['success']) {
        _isLoggedIn = true;
        _adminToken = result['data']['token'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['error'] ?? 'Login failed';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void logout() {
    _isLoggedIn = false;
    _adminToken = null;
    notifyListeners();
  }

  // Map Layer Methods
  void setMapLayer(String name, String url) {
    _selectedLayerName = name;
    _selectedTileUrl = url;
    notifyListeners();
  }
}
