import 'package:flutter/material.dart';

import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';

class CategoryTile extends StatefulWidget {
  const CategoryTile({
    super.key,
    required this.data,
    required this.active,
    required this.onTap,
  });

  final CategoryData data;
  final bool active;
  final VoidCallback onTap;

  @override
  State<CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<CategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    return SizedBox.expand(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: a ? AppColors.lightGreenBg : AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: a
                    ? AppColors.borderEmphasized(0.3)
                    : AppColors.borderSubtle(_hover ? 0.2 : 0.1),
              ),
              boxShadow: a
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: a
                              ? AppColors.darkGreenText
                              : AppColors.mediumGreenText,
                        ),
                      ),
                    ),
                    Icon(
                      widget.data.icon,
                      size: 20,
                      color: a
                          ? AppColors.primaryGreen
                          : AppColors.lightGreenText,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.data.products.length} items',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.lightGreenText,
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
