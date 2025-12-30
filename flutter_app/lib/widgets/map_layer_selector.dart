import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cctv_provider.dart';

class MapLayerSelector extends StatelessWidget {
  const MapLayerSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CctvProvider>();
    final layers = [
      {
        'name': 'Google Streets',
        'icon': '🚗',
        'url': 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'
      },
      {
        'name': 'Dark Map',
        'icon': '🌙',
        'url': 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
      },
      {
        'name': 'Google Satellite',
        'icon': '🛰️',
        'url': 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
      },
      {
        'name': 'Google Hybrid',
        'icon': '🗺️',
        'url': 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
      },
      {
        'name': 'ESRI Satellite',
        'icon': '🌍',
        'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      },
      {
        'name': 'OpenStreetMap',
        'icon': '🛣️',
        'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
      },
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1E36).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.layers,
                        size: 16,
                        color: Color(0xFF00D4FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Map Layer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: Colors.white.withOpacity(0.1),
              ),
              const SizedBox(height: 4),
              ...layers.map((layer) {
                final isSelected = provider.selectedLayerName == layer['name'];
                return InkWell(
                  onTap: () {
                    provider.setMapLayer(layer['name']!, layer['url']!);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                const Color(0xFFE53935).withOpacity(0.2),
                                const Color(0xFFE53935).withOpacity(0.1),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(
                              color: const Color(0xFFE53935).withOpacity(0.3),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFE53935)
                                  : Colors.white38,
                              width: 2,
                            ),
                            color: isSelected
                                ? const Color(0xFFE53935)
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(
                                    Icons.check,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          layer['icon']!,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            layer['name']!,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
