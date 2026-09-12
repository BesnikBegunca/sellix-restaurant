import 'package:flutter/material.dart';

import '../../../../config/default_menu_catalog.dart';
import '../../../../models/mock_data.dart';
import '../../../../theme/app_colors.dart';
import '../../../../utils/image_utils.dart';
import '../../../../l10n/tr.dart';

typedef ProductDrag = ({String fromCatId, ProductItem product});

class CategoryProductTable extends StatefulWidget {
  const CategoryProductTable({
    super.key,
    required this.category,
    required this.onDeleteCategory,
    required this.onDeleteProduct,
    required this.onEditProduct,
    required this.onMoveIn,
    required this.onReorderProduct,
  });

  final CategoryData category;
  final VoidCallback onDeleteCategory;
  final void Function(String productId) onDeleteProduct;
  final void Function(ProductItem product) onEditProduct;
  final void Function(ProductItem product, String fromCatId) onMoveIn;
  final void Function(String productId, int direction) onReorderProduct;

  @override
  State<CategoryProductTable> createState() => _CategoryProductTableState();
}

class _CategoryProductTableState extends State<CategoryProductTable> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<ProductDrag>(
      onWillAcceptWithDetails: (d) => d.data.fromCatId != widget.category.id,
      onAcceptWithDetails: (d) =>
          widget.onMoveIn(d.data.product, d.data.fromCatId),
      builder: (context, candidateData, _) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isOver
                ? AppColors.lightGreenBg.withValues(alpha: 0.6)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOver
                  ? AppColors.primaryGreen
                  : AppColors.borderSubtle(0.12),
              width: isOver ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isOver ? 0.06 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(c.icon, size: 20, color: AppColors.primaryGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${c.products.length} produkte',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: tr.fshiKategorine,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.negativeText,
                        onPressed: widget.onDeleteCategory,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: c.products.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tr.nukKaProdukteKeteKategori,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            color: scheme.primaryContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 52),
                                SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Emri',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mediumGreenText,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    tr.cmimi,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mediumGreenText,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(width: 120),
                              ],
                            ),
                          ),
                          for (var i = 0; i < c.products.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: AppColors.borderSubtle(0.08),
                              ),
                            _ProductTableRow(
                              product: c.products[i],
                              isLast: i == c.products.length - 1,
                              canMoveUp: i > 0,
                              canMoveDown: i < c.products.length - 1,
                              canDelete: !DefaultMenuCatalog.isBuiltinProductId(
                                c.products[i].id,
                              ),
                              onMoveUp: () =>
                                  widget.onReorderProduct(c.products[i].id, -1),
                              onMoveDown: () =>
                                  widget.onReorderProduct(c.products[i].id, 1),
                              onEdit: () => widget.onEditProduct(c.products[i]),
                              onDelete: () =>
                                  widget.onDeleteProduct(c.products[i].id),
                            ),
                          ],
                        ],
                      ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductTableRow extends StatefulWidget {
  const _ProductTableRow({
    required this.product,
    required this.isLast,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductItem product;
  final bool isLast;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProductTableRow> createState() => _ProductTableRowState();
}

class _ProductTableRowState extends State<_ProductTableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hover
              ? AppColors.lightGreenBg.withValues(alpha: 0.5)
              : AppColors.white,
          borderRadius: widget.isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : BorderRadius.zero,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: p.imagePath != null
                  ? productImage(
                      p.imagePath,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: _thumbPlaceholder,
                    )
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Text(
                p.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGreenText,
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                '\$${p.price.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    icon: Icons.arrow_upward_rounded,
                    tooltip: tr.lart,
                    color: AppColors.mediumGreenText,
                    onTap: widget.canMoveUp ? widget.onMoveUp : null,
                    enabled: widget.canMoveUp,
                  ),
                  const SizedBox(width: 2),
                  _ActionBtn(
                    icon: Icons.arrow_downward_rounded,
                    tooltip: tr.poshte,
                    color: AppColors.mediumGreenText,
                    onTap: widget.canMoveDown ? widget.onMoveDown : null,
                    enabled: widget.canMoveDown,
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    tooltip: tr.ndrysho,
                    color: AppColors.primaryGreen,
                    onTap: widget.onEdit,
                  ),
                  if (widget.canDelete) ...[
                    const SizedBox(width: 4),
                    _ActionBtn(
                      icon: Icons.delete_outline,
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
  }

  Widget _thumbPlaceholder() => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: AppColors.lightGreenBg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.fastfood_outlined,
      size: 22,
      color: AppColors.lightGreenText,
    ),
  );
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.enabled
        ? widget.color
        : AppColors.lightGreenText.withValues(alpha: 0.35);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: widget.enabled ? (_) => setState(() => _hover = true) : null,
        onExit: widget.enabled ? (_) => setState(() => _hover = false) : null,
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hover && widget.enabled
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: fg),
          ),
        ),
      ),
    );
  }
}
