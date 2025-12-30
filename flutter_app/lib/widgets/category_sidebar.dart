import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/cctv_provider.dart';

class CategorySidebar extends StatelessWidget {
  const CategorySidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CctvProvider>(
      builder: (context, provider, _) {
        final categories = provider.categories.isEmpty
            ? Categories.getAll()
            : provider.categories;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            // All category
            _CategoryTile(
              category: Category(
                id: 'ALL',
                name: 'Semua CCTV',
                icon: '📷',
                color: const Color(0xFF00D4FF),
              ),
              count: provider.cctvList.length,
              isSelected: provider.selectedCategory == null,
              onTap: () {
                provider.clearCategoryFilter();
                Navigator.of(context).pop();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Divider(
                height: 1,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            // Category list
            ...categories.map((category) {
              final count = provider.getCctvCountByCategory(category.id);
              return _CategoryTile(
                category: category,
                count: count,
                isSelected: provider.selectedCategory == category.id,
                onTap: () {
                  provider.setSelectedCategory(category.id);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected
            ? category.color.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? Border.all(
                      color: category.color.withOpacity(0.3),
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: category.color.withOpacity(0.2),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    category.iconData,
                    color: category.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                          color: isSelected ? category.color : Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count CCTV',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Selected indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: category.color,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
