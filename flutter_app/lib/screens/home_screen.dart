import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cctv_provider.dart';
import 'map_screen.dart';
import 'multi_stream_screen.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import '../widgets/category_sidebar.dart';
import '../widgets/stats_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateToMap() {
    setState(() => _currentIndex = 0);
  }

  List<Widget> get _pages => [
    const MapScreen(),
    MultiStreamScreen(onNavigateToMap: _navigateToMap),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      appBar: _buildPremiumAppBar(context),
      drawer: _buildPremiumDrawer(context),
      body: Consumer<CctvProvider>(
        builder: (context, provider, _) {
          if (_currentIndex == 2) {
            return provider.isLoggedIn ? const AdminScreen() : const LoginScreen();
          }
          return _pages[_currentIndex];
        },
      ),
      bottomNavigationBar: _buildGlassmorphicNavBar(context),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF0F1E36),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.menu, size: 20),
        ),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFFF6B6B)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.videocam, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CCTV STREAMING',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Monitoring System',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Consumer<CctvProvider>(
          builder: (context, provider, _) {
            final selectedCount = provider.selectedCctvs.length;
            if (selectedCount > 0 && _currentIndex == 0) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF00A8CC)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$selectedCount',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => provider.clearSelection(),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh, size: 20),
          ),
          onPressed: () {
            Provider.of<CctvProvider>(context, listen: false).fetchCctvList();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPremiumDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F1E36),
              Color(0xFF0A1628),
            ],
          ),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Premium Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE53935),
                    const Color(0xFFE53935).withOpacity(0.8),
                    const Color(0xFFFF6B6B),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'CCTV STREAMING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sistem Pemantauan CCTV',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Stats Card
            const Padding(
              padding: EdgeInsets.all(16),
              child: StatsCard(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white.withOpacity(0.1)),
            ),
            // Category Label
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.category,
                      size: 16,
                      color: Color(0xFFE53935),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Kategori Lokasi',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: CategorySidebar(),
            ),
            // Admin Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white.withOpacity(0.1)),
            ),
            Consumer<CctvProvider>(
              builder: (context, provider, _) {
                if (provider.isLoggedIn) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user, size: 16, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Logged in as Admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            provider.logout();
                            setState(() => _currentIndex = 0);
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('LOGOUT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7F1D1D),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 2);
                    },
                    icon: const Icon(Icons.admin_panel_settings, size: 18),
                    label: const Text('Admin Panel'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassmorphicNavBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F1E36).withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.map_outlined, Icons.map, 'Peta'),
                  _buildNavItem(1, Icons.grid_view_outlined, Icons.grid_view, 'Multi'),
                  _buildNavItem(2, Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'Admin'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE53935).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFFE53935) : Colors.white54,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddCctvDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CctvFormDialog(
        onSave: () {
          // Refresh provider data
          Provider.of<CctvProvider>(context, listen: false).fetchCctvList();
        },
      ),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    if (_currentIndex != 0) return null;
    
    return Consumer<CctvProvider>(
      builder: (context, provider, _) {
        if (provider.selectedCctvs.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 70),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFFF6B6B)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _currentIndex = 1),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Tonton ${provider.selectedCctvs.length} CCTV',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
