import 'package:flutter/material.dart';

import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/image_utils.dart';
import '../../../widgets/hover_interaction.dart';

class ProductTile extends StatefulWidget {
  const ProductTile({super.key, required this.product, required this.onAdd});

  final ProductItem product;
  final VoidCallback onAdd;

  @override
  State<ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<ProductTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onAdd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.borderSubtle(_hover ? 0.3 : 0.1),
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 100,
                      child: Center(
                        child: widget.product.imagePath != null
                            ? productImage(
                                widget.product.imagePath,
                                fit: BoxFit.contain,
                              )
                            : FittedBox(
                                fit: BoxFit.contain,
                                child: Text(
                                  widget.product.emoji,
                                  style: const TextStyle(fontSize: 96),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.darkGreenText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.product.price.toStringAsFixed(2)}€',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.lightGreenText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        HoverScaleButton(
                          onPressed: widget.onAdd,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: _AddCircle(hover: _hover),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCircle extends StatefulWidget {
  const _AddCircle({required this.hover});

  final bool hover;

  @override
  State<_AddCircle> createState() => _AddCircleState();
}

class _AddCircleState extends State<_AddCircle> {
  bool _innerHover = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.hover || _innerHover;
    return MouseRegion(
      onEnter: (_) => setState(() => _innerHover = true),
      onExit: (_) => setState(() => _innerHover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: h ? AppColors.darkerGreenHover : AppColors.primaryGreen,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: AppColors.white, size: 20),
      ),
    );
  }
}
