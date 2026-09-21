import 'package:flutter/material.dart';

import '../../../../config/default_menu_catalog.dart';
import '../../../../models/mock_data.dart';
import '../../../../theme/app_colors.dart';
import '../../../../utils/image_utils.dart';
import '../../../../l10n/tr.dart';

typedef ProductDrag = ({String fromCatId, ProductItem product});

class CategoryProductTable extends StatelessWidget {
  const CategoryProductTable({
    super.key,
    required this.category,
    required this.onDeleteCategory,
    required this.onDeleteProduct,
    required this.onEditProduct,
    required this.onMoveIn,
    required this.onReorderProduct,
    this.searchQuery = '',
  });

  final CategoryData category;
  final VoidCallback onDeleteCategory;
  final void Function(String productId) onDeleteProduct;
  final void Function(ProductItem product) onEditProduct;
  final void Function(ProductItem product, String fromCatId) onMoveIn;
  final void Function(String productId, int direction) onReorderProduct;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = searchQuery.trim().toLowerCase();
    final products = q.isEmpty
        ? category.products
        : category.products
              .where((p) => p.name.toLowerCase().contains(q))
              .toList();

    return DragTarget<ProductDrag>(
      onWillAcceptWithDetails: (d) => d.data.fromCatId != category.id,
      onAcceptWithDetails: (d) => onMoveIn(d.data.product, d.data.fromCatId),
      builder: (context, candidateData, _) {
        final isOver = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isOver
                ? AppColors.primaryGreen.withValues(alpha: 0.06)
                : scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isOver ? AppColors.primaryGreen : scheme.outlineVariant,
              width: isOver ? 1.5 : 1,
            ),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        category.icon,
                        size: 20,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            isOver
                                ? 'Lësho këtu për ta zhvendosur'
                                : '${category.products.length} produkte',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isOver
                                  ? AppColors.primaryGreen
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr.fshiKategorine,
                      onPressed: onDeleteCategory,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: AppColors.negativeText,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (products.isEmpty)
                  _EmptyCatalog(
                    hasSearch: q.isNotEmpty,
                    categoryName: category.name,
                  )
                else
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 1100
                          ? 4
                          : c.maxWidth >= 820
                          ? 3
                          : c.maxWidth >= 520
                          ? 2
                          : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.82,
                        ),
                        itemBuilder: (context, i) {
                          final p = products[i];
                          final fullIndex = category.products.indexWhere(
                            (x) => x.id == p.id,
                          );
                          return _ProductCard(
                            product: p,
                            canMoveUp: fullIndex > 0,
                            canMoveDown:
                                fullIndex >= 0 &&
                                fullIndex < category.products.length - 1,
                            canDelete: !DefaultMenuCatalog.isBuiltinProductId(
                              p.id,
                            ),
                            onMoveUp: () => onReorderProduct(p.id, -1),
                            onMoveDown: () => onReorderProduct(p.id, 1),
                            onEdit: () => onEditProduct(p),
                            onDelete: () => onDeleteProduct(p.id),
                            dragData: (fromCatId: category.id, product: p),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.hasSearch, required this.categoryName});

  final bool hasSearch;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.restaurant_menu_outlined,
            size: 34,
            color: AppColors.lightGreenText,
          ),
          const SizedBox(height: 10),
          Text(
            hasSearch
                ? 'Asnjë produkt nuk përputhet'
                : tr.nukKaProdukteKeteKategori,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumGreenText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasSearch
                ? 'Provo një emër tjetër.'
                : 'Shto produktin e parë për “$categoryName”.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.lightGreenText),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.product,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.dragData,
  });

  final ProductItem product;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ProductDrag dragData;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final scheme = Theme.of(context).colorScheme;
    final card = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hover
                ? AppColors.primaryGreen.withValues(alpha: 0.5)
                : scheme.outlineVariant,
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                    child: p.imagePath != null
                        ? productImage(
                            p.imagePath,
                            fit: BoxFit.cover,
                            placeholder: _thumbPlaceholder,
                          )
                        : _thumbPlaceholder(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xCC15241C)],
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${p.price.toStringAsFixed(2)}€',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_hover)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          _MiniIcon(
                            icon: Icons.arrow_upward_rounded,
                            tooltip: tr.lart,
                            onTap: widget.canMoveUp ? widget.onMoveUp : null,
                          ),
                          const SizedBox(width: 4),
                          _MiniIcon(
                            icon: Icons.arrow_downward_rounded,
                            tooltip: tr.poshte,
                            onTap: widget.canMoveDown ? widget.onMoveDown : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ndrysho',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _MiniIcon(
                    icon: Icons.edit_outlined,
                    tooltip: tr.ndrysho,
                    color: AppColors.primaryGreen,
                    onTap: widget.onEdit,
                  ),
                  if (widget.canDelete) ...[
                    const SizedBox(width: 2),
                    _MiniIcon(
                      icon: Icons.delete_outline_rounded,
                      tooltip: tr.fshi,
                      color: AppColors.negativeText,
                      onTap: widget.onDelete,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Draggable<ProductDrag>(
      data: widget.dragData,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 160,
          height: 70,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: p.imagePath != null
                        ? productImage(p.imagePath, fit: BoxFit.cover)
                        : _thumbPlaceholder(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: GestureDetector(onTap: widget.onEdit, child: card),
    );
  }

  Widget _thumbPlaceholder() => ColoredBox(
    color: AppColors.lightGreenBg,
    child: Center(
      child: Icon(
        Icons.fastfood_outlined,
        size: 32,
        color: AppColors.lightGreenText,
      ),
    ),
  );
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = enabled
        ? (color ?? AppColors.darkGreenText)
        : AppColors.lightGreenText.withValues(alpha: 0.35);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 15, color: fg),
          ),
        ),
      ),
    );
  }
}
