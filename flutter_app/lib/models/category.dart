import 'package:flutter/material.dart';

/// Category Model
class Category {
  final String id;
  final String name;
  final String icon;
  final Color color;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '📷',
      color: _parseColor(json['color']),
    );
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.red;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': '#${color.value.toRadixString(16)}',
    };
  }

  IconData get iconData {
    switch (id) {
      case 'PANTAU_LALIN':
        return Icons.traffic;
      case 'RT_RW':
        return Icons.home;
      case 'SUNGAI':
        return Icons.water;
      case 'POMPA_AIR':
        return Icons.water_drop;
      case 'PEMERINTAHAN':
        return Icons.account_balance;
      case 'TOL':
        return Icons.directions_car;
      default:
        return Icons.videocam;
    }
  }
}

/// Predefined categories
class Categories {
  static const List<Map<String, dynamic>> defaultCategories = [
    {'id': 'PANTAU_LALIN', 'name': 'Pantau Lalin', 'icon': '🚗', 'color': '#E53935'},
    {'id': 'RT_RW', 'name': 'RT RW', 'icon': '🏠', 'color': '#43A047'},
    {'id': 'SUNGAI', 'name': 'Sungai', 'icon': '🌊', 'color': '#1E88E5'},
    {'id': 'POMPA_AIR', 'name': 'Pantau Pompa Air', 'icon': '💧', 'color': '#00ACC1'},
    {'id': 'PEMERINTAHAN', 'name': 'Kantor Pemerintahan', 'icon': '🏛️', 'color': '#8E24AA'},
    {'id': 'TOL', 'name': 'Pantau Ruas Tol', 'icon': '🛣️', 'color': '#FF6F00'},
  ];

  static List<Category> getAll() {
    return defaultCategories.map((c) => Category.fromJson(c)).toList();
  }

  static Category? getById(String id) {
    final data = defaultCategories.firstWhere(
      (c) => c['id'] == id,
      orElse: () => {},
    );
    if (data.isEmpty) return null;
    return Category.fromJson(data);
  }
}
