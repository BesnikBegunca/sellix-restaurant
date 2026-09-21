import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../manager/manager_data.dart';
import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../shared/widgets/panel_layout.dart';
import '../../../utils/image_utils.dart';
import '../widgets/menu/asset_picker.dart';
import '../widgets/menu/category_product_table.dart';
import '../../../l10n/tr.dart';

class MenuPanel extends StatefulWidget {
  const MenuPanel({super.key, required this.m});

  final ManagerData m;

  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> {
  final _catCtrl = TextEditingController();
  final _prodName = TextEditingController();
  final _prodPrice = TextEditingController();
  final _searchCtrl = TextEditingController();
  String? _selectedCatId;
  String? _newProductImage;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final c = ManagerData.instance.categories;
    if (c.isNotEmpty) _selectedCatId = c.first.id;
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _catCtrl.dispose();
    _prodName.dispose();
    _prodPrice.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    final picked = await showImageSourcePicker(context, _newProductImage);
    if (picked != null) {
      setState(() => _newProductImage = picked.isEmpty ? null : picked);
    }
  }

  void _addCategory() {
    final txt = _catCtrl.text.trim();
    if (txt.isEmpty) return;
    widget.m.addCategory(txt);
    _catCtrl.clear();
    final cats = ManagerData.instance.categories;
    setState(() {
      _formError = null;
      if (cats.isNotEmpty) _selectedCatId = cats.last.id;
    });
  }

  void _addProduct(String catId) {
    final name = _prodName.text.trim();
    final pr = double.tryParse(_prodPrice.text.trim().replaceAll(',', '.')) ?? 0;
    if (name.isEmpty) {
      setState(() => _formError = 'Shkruaj emrin e produktit.');
      return;
    }
    if (pr <= 0) {
      setState(() => _formError = 'Vendos një çmim më të madh se 0.');
      return;
    }
    widget.m.addProduct(
      categoryId: catId,
      name: name,
      price: pr,
      imagePath: _newProductImage,
    );
    _prodName.clear();
    _prodPrice.clear();
    setState(() {
      _newProductImage = null;
      _formError = null;
      _selectedCatId = catId;
    });
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    CategoryData category,
  ) async {
    final count = category.products.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(tr.fshiKategorine2),
        content: Text(
          count > 0
              ? trf.deleteCategoryWithProducts(category.name, count)
              : trf.deleteCategory(category.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr.anulo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negativeText,
            ),
            child: Text(tr.fshi),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await widget.m.removeCategory(category.id);
    if (!mounted) return;
    final cats = ManagerData.instance.categories;
    setState(() {
      if (cats.isEmpty) {
        _selectedCatId = null;
      } else if (_selectedCatId == category.id ||
          !cats.any((c) => c.id == _selectedCatId)) {
        _selectedCatId = cats.first.id;
      }
    });
  }

  Future<void> _openEditDialog(
    BuildContext context,
    String catId,
    ProductItem p,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) =>
          _EditProductDialog(catId: catId, product: p, manager: widget.m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final cats = m.categories;
    final productCount = cats.fold<int>(0, (s, c) => s + c.products.length);

    if (cats.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            icon: Icons.menu_book_outlined,
            title: tr.menu,
            subtitle: 'Krijo kategorinë e parë, pastaj shto produktet e POS-it.',
          ),
          PanelCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      size: 34,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    tr.nukKaKategoriShtoKategoriVazhduar,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr.shtuarProdukteDuhetEkzistojePaktenKategori,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.mediumGreenText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: PanelFormRow(
                      fields: [
                        PanelField(
                          label: 'Emri i kategorisë',
                          flex: 5,
                          child: TextField(
                            controller: _catCtrl,
                            decoration: inputDeco(tr.emriKategoriseRe),
                            onSubmitted: (_) => _addCategory(),
                          ),
                        ),
                      ],
                      trailing: FilledButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Shto kategori'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final catValue =
        (_selectedCatId != null && cats.any((c) => c.id == _selectedCatId))
        ? _selectedCatId!
        : cats.first.id;
    final selected = cats.firstWhere((c) => c.id == catValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          icon: Icons.local_bar_rounded,
          title: tr.menu,
          subtitle:
              'Shto pije me foto dhe çmim. Ashtu siç shfaqen te kamarieri në POS.',
        ),
        PanelStatRow(
          cards: [
            StatLite(
              icon: Icons.category_outlined,
              label: 'Kategori',
              value: '${cats.length}',
            ),
            StatLite(
              icon: Icons.fastfood_outlined,
              label: 'Produkte',
              value: '$productCount',
            ),
            StatLite(
              icon: Icons.sell_outlined,
              label: selected.name,
              value: '${selected.products.length}',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DrinkStudio(
          cats: cats,
          catValue: catValue,
          imagePath: _newProductImage,
          nameCtrl: _prodName,
          priceCtrl: _prodPrice,
          error: _formError,
          onPickImage: _pickNewImage,
          onCategoryChanged: (id) => setState(() => _selectedCatId = id),
          onSubmit: () => _addProduct(catValue),
        ),
        const SizedBox(height: 20),
        PanelColumns(
          breakpoint: 980,
          leftFlex: 4,
          rightFlex: 7,
          left: _CategoryRail(
            cats: cats,
            selectedId: catValue,
            catCtrl: _catCtrl,
            onSelect: (id) => setState(() => _selectedCatId = id),
            onAdd: _addCategory,
            onDelete: (c) => _confirmDeleteCategory(context, c),
            onMoveIn: (p, fromId, toId) => widget.m.moveProduct(fromId, p.id, toId),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: inputDeco('Kërko produkt…').copyWith(
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.lightGreenText,
                  ),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Pastro',
                          onPressed: () => _searchCtrl.clear(),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              CategoryProductTable(
                category: selected,
                searchQuery: _searchCtrl.text,
                onDeleteCategory: () =>
                    _confirmDeleteCategory(context, selected),
                onDeleteProduct: (pid) => m.removeProduct(selected.id, pid),
                onEditProduct: (p) => _openEditDialog(context, selected.id, p),
                onMoveIn: (p, fromCatId) =>
                    m.moveProduct(fromCatId, p.id, selected.id),
                onReorderProduct: (pid, dir) =>
                    m.reorderProduct(selected.id, pid, dir),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatLite extends StatelessWidget {
  const StatLite({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrinkStudio extends StatelessWidget {
  const _DrinkStudio({
    required this.cats,
    required this.catValue,
    required this.imagePath,
    required this.nameCtrl,
    required this.priceCtrl,
    required this.error,
    required this.onPickImage,
    required this.onCategoryChanged,
    required this.onSubmit,
  });

  final List<CategoryData> cats;
  final String catValue;
  final String? imagePath;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final String? error;
  final VoidCallback onPickImage;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF183126), Color(0xFF234B36)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_bar_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pije e re',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Vendos foton, emrin dhe çmimin — pastaj shtohet direkt në POS.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 780;
                final photo = _PhotoWell(
                  imagePath: imagePath,
                  onTap: onPickImage,
                );
                final form = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PanelField(
                      label: 'Emri i pijes',
                      child: TextField(
                        controller: nameCtrl,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: inputDeco('p.sh. Espresso, Mojito, Heineken'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PanelFormRow(
                      breakpoint: 560,
                      fields: [
                        PanelField(
                          label: tr.cmimi,
                          flex: 2,
                          child: TextField(
                            controller: priceCtrl,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: inputDeco('0.00', prefix: '€ '),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.,]'),
                              ),
                            ],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => onSubmit(),
                          ),
                        ),
                        PanelField(
                          label: 'Kategoria',
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(catValue),
                            initialValue: catValue,
                            isExpanded: true,
                            decoration: inputDeco('Zgjidh kategorinë'),
                            borderRadius: BorderRadius.circular(12),
                            items: [
                              for (final cat in cats)
                                DropdownMenuItem(
                                  value: cat.id,
                                  child: Row(
                                    children: [
                                      Icon(cat.icon, size: 18),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          cat.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (id) {
                              if (id != null) onCategoryChanged(id);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      PanelErrorBanner(message: error!),
                    ],
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: onSubmit,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(tr.shtoPijenMenu),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(220, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                      ),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [photo, const SizedBox(height: 20), form],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    photo,
                    const SizedBox(width: 28),
                    Expanded(child: form),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoWell extends StatefulWidget {
  const _PhotoWell({required this.imagePath, required this.onTap});

  final String? imagePath;
  final VoidCallback onTap;

  @override
  State<_PhotoWell> createState() => _PhotoWellState();
}

class _PhotoWellState extends State<_PhotoWell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = widget.imagePath != null && widget.imagePath!.isNotEmpty;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 220,
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFF183126).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hover
                  ? AppColors.primaryGreen
                  : AppColors.primaryGreen.withValues(alpha: 0.35),
              width: _hover ? 2 : 1.4,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      productImage(
                        widget.imagePath,
                        fit: BoxFit.cover,
                        placeholder: () => const _PhotoPlaceholder(),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 140),
                        opacity: _hover ? 1 : 0,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.42),
                          child: Center(
                            child: Text(
                              'Ndrysho foton',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const _PhotoPlaceholder(),
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.add_a_photo_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Shto foton e pijes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kliko këtu · PNG, JPG, WEBP',
          style: TextStyle(fontSize: 12, color: AppColors.lightGreenText),
        ),
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.cats,
    required this.selectedId,
    required this.catCtrl,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
    required this.onMoveIn,
  });

  final List<CategoryData> cats;
  final String selectedId;
  final TextEditingController catCtrl;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  final void Function(CategoryData category) onDelete;
  final void Function(ProductItem product, String fromCatId, String toCatId)
  onMoveIn;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      icon: Icons.category_outlined,
      title: 'Kategoritë',
      subtitle: 'Zgjidh një, ose shto të re.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in cats) ...[
            if (c != cats.first) const SizedBox(height: 8),
            _CategoryTile(
              category: c,
              selected: c.id == selectedId,
              onTap: () => onSelect(c.id),
              onDelete: () => onDelete(c),
              onMoveIn: (p, fromId) => onMoveIn(p, fromId, c.id),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: catCtrl,
            decoration: inputDeco(tr.emriKategoriseRe),
            onSubmitted: (_) => onAdd(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Shto kategori'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
    required this.onDelete,
    required this.onMoveIn,
  });

  final CategoryData category;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(ProductItem product, String fromCatId) onMoveIn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<ProductDrag>(
      onWillAcceptWithDetails: (d) => d.data.fromCatId != category.id,
      onAcceptWithDetails: (d) => onMoveIn(d.data.product, d.data.fromCatId),
      builder: (context, candidate, _) {
        final over = candidate.isNotEmpty;
        return Material(
          color: over
              ? AppColors.primaryGreen.withValues(alpha: 0.10)
              : selected
              ? const Color(0xFF183126)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    size: 18,
                    color: selected
                        ? Colors.white
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.16)
                          : scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${category.products.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr.fshiKategorine,
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    color: AppColors.negativeText.withValues(alpha: 0.75),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({
    required this.catId,
    required this.product,
    required this.manager,
  });

  final String catId;
  final ProductItem product;
  final ManagerData manager;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  String? _editImage;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.name);
    _priceCtrl = TextEditingController(
      text: widget.product.price.toStringAsFixed(2),
    );
    _editImage = widget.product.imagePath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await showImageSourcePicker(context, _editImage);
    if (!mounted) return;
    if (picked != null) {
      setState(() => _editImage = picked.isEmpty ? null : picked);
    }
  }

  void _save() {
    final pr = double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (_nameCtrl.text.trim().isEmpty || pr <= 0) return;
    widget.manager.editProduct(
      widget.catId,
      widget.product.id,
      name: _nameCtrl.text.trim(),
      price: pr,
      imagePath: _editImage,
      clearImage: _editImage == null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ndrysho produktin',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          'Emri, çmimi dhe fotoja e artikullit.',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 112,
                        height: 112,
                        child: _editImage != null
                            ? productImage(
                                _editImage,
                                fit: BoxFit.cover,
                                placeholder: () => ColoredBox(
                                  color: AppColors.lightGreenBg,
                                  child: Icon(
                                    Icons.hide_image_outlined,
                                    color: AppColors.lightGreenText,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: AppColors.lightGreenBg,
                                child: Icon(
                                  Icons.add_a_photo_outlined,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: const Text('Ndrysho foton'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameCtrl,
                          decoration: inputDeco('Emri i produktit'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _priceCtrl,
                          decoration: inputDeco(tr.cmimi, prefix: '€ '),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr.anulo),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Ruaj ndryshimet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
