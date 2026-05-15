import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../manager/manager_data.dart';
import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../utils/image_utils.dart';

typedef _ProductDrag = ({String fromCatId, ProductItem product});

// ── Image source picker ──────────────────────────────────────────────────────

Future<String?> _showImageSourcePicker(
  BuildContext context,
  String? current,
) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Zgjidh burimin e fotos',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Nga asetat e aplikacionit'),
            subtitle: const Text('Foto të parakonfighuruara'),
            onTap: () => Navigator.pop(ctx, 'assets'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Ngarko nga kompjuteri'),
            subtitle: const Text('PNG, JPG, WEBP…'),
            onTap: () => Navigator.pop(ctx, 'pc'),
          ),
          if (current != null && current.isNotEmpty)
            ListTile(
              leading: Icon(
                Icons.hide_image_outlined,
                color: AppColors.negativeText,
              ),
              title: Text(
                'Hiq foton',
                style: TextStyle(color: AppColors.negativeText),
              ),
              onTap: () => Navigator.pop(ctx, 'clear'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Anulo'),
        ),
      ],
    ),
  );
  if (choice == null) return null;
  if (choice == 'clear') return '';
  if (choice == 'assets') {
    if (!context.mounted) return null;
    return _showAssetPicker(context, current);
  }
  return pickAndCopyImageFromPC();
}

const _kImageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};

String _assetLabel(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

Future<List<String>> _loadImageAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest.listAssets().where((a) {
    if (!a.startsWith('assets/images/')) return false;
    final lower = a.toLowerCase();
    return _kImageExtensions.any((ext) => lower.endsWith(ext));
  }).toList()..sort();
}

Future<String?> _showAssetPicker(BuildContext context, String? current) async {
  final assets = await _loadImageAssets();
  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zgjidh foton',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 400),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AssetPickerThumb(
                      path: null,
                      label: 'Pa foto',
                      selected: current == null,
                      onTap: () => Navigator.pop(ctx, ''),
                    ),
                    for (final a in assets)
                      _AssetPickerThumb(
                        path: a,
                        label: _assetLabel(a),
                        selected: current == a,
                        onTap: () => Navigator.pop(ctx, a),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anulo'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AssetPickerThumb extends StatefulWidget {
  const _AssetPickerThumb({
    required this.path,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String? path;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AssetPickerThumb> createState() => _AssetPickerThumbState();
}

class _AssetPickerThumbState extends State<_AssetPickerThumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primaryGreen
                  : _hover
                      ? AppColors.primaryGreen.withValues(alpha: 0.4)
                      : AppColors.lightGreenBorder,
              width: widget.selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: widget.path != null
                    ? productImage(
                        widget.path,
                        width: 96,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: () => Container(
                          width: 96,
                          height: 72,
                          color: AppColors.lightGreenBg,
                          child: const Icon(
                            Icons.image_outlined,
                            color: AppColors.lightGreenText,
                          ),
                        ),
                      )
                    : Container(
                        width: 96,
                        height: 72,
                        color: AppColors.lightGreenBg,
                        child: const Icon(
                          Icons.hide_image_outlined,
                          color: AppColors.lightGreenText,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: widget.selected
                        ? AppColors.primaryGreen
                        : AppColors.mediumGreenText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu Panel ───────────────────────────────────────────────────────────────

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
  String? _selectedCatId;
  String? _newProductImage;

  @override
  void initState() {
    super.initState();
    final c = ManagerData.instance.categories;
    if (c.isNotEmpty) _selectedCatId = c.first.id;
  }

  @override
  void dispose() {
    _catCtrl.dispose();
    _prodName.dispose();
    _prodPrice.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    final picked = await _showImageSourcePicker(context, _newProductImage);
    if (picked != null) {
      setState(() => _newProductImage = picked.isEmpty ? null : picked);
    }
  }

  void _addProduct(String catId) {
    final pr = double.tryParse(_prodPrice.text.trim()) ?? 0;
    if (_prodName.text.trim().isEmpty || pr <= 0) return;
    widget.m.addProduct(
      categoryId: catId,
      name: _prodName.text.trim(),
      price: pr,
      imagePath: _newProductImage,
    );
    _prodName.clear();
    _prodPrice.clear();
    setState(() => _newProductImage = null);
  }

  Future<void> _openEditDialog(
    BuildContext context,
    String catId,
    ProductItem p,
  ) async {
    final nameCtrl = TextEditingController(text: p.name);
    final priceCtrl = TextEditingController(text: p.price.toStringAsFixed(2));
    String? editImage = p.imagePath;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ndrysho produktin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: editImage != null
                            ? productImage(
                                editImage,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: _noImageBox,
                              )
                            : _noImageBox(),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fotoja',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _showImageSourcePicker(
                                context,
                                editImage,
                              );
                              if (picked != null) {
                                setSt(
                                  () => editImage = picked.isEmpty
                                      ? null
                                      : picked,
                                );
                              }
                            },
                            icon: const Icon(Icons.image_outlined, size: 16),
                            label: const Text('Ndrysho foton'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    decoration: inputDeco('Emri i produktit'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    decoration: inputDeco('Çmimi'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Anulo'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final pr =
                              double.tryParse(priceCtrl.text.trim()) ?? 0;
                          if (nameCtrl.text.trim().isEmpty || pr <= 0) return;
                          widget.m.editProduct(
                            catId,
                            p.id,
                            name: nameCtrl.text.trim(),
                            price: pr,
                            imagePath: editImage,
                            clearImage: editImage == null,
                          );
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.white,
                        ),
                        child: const Text('Ruaj ndryshimet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    priceCtrl.dispose();
  }

  Widget _noImageBox() => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: AppColors.lightGreenBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(
      Icons.hide_image_outlined,
      size: 28,
      color: AppColors.lightGreenText,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final cats = m.categories;

    if (cats.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle('7. Menu / kategori dinamike'),
          const SizedBox(height: 16),
          Text(
            'Nuk ka kategori. Shto një kategori për të vazhduar.',
            style: TextStyle(color: AppColors.lightGreenText),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _catCtrl,
                  decoration: inputDeco('Emri i kategorisë së re'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  final txt = _catCtrl.text.trim();
                  if (txt.isEmpty) return;
                  m.addCategory(txt);
                  _catCtrl.clear();
                  setState(() => _selectedCatId = null);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Shto kategori'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Për të shtuar produkte, duhet të ekzistojë të paktën një kategori.',
            style: TextStyle(color: AppColors.mediumGreenText),
          ),
        ],
      );
    }

    final catValue =
        (_selectedCatId != null && cats.any((c) => c.id == _selectedCatId))
        ? _selectedCatId!
        : cats.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('7. Menu / kategori dinamike'),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _catCtrl,
                decoration: inputDeco('Emri i kategorisë së re'),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () {
                if (_catCtrl.text.trim().isNotEmpty) {
                  m.addCategory(_catCtrl.text);
                  _catCtrl.clear();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Shto kategori'),
            ),
          ],
        ),
        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shto produkt',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: inputDeco('Kategoria'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: catValue,
                    isExpanded: true,
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _selectedCatId = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickNewImage,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Tooltip(
                        message: 'Zgjidh foton',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: _newProductImage != null
                                ? productImage(
                                    _newProductImage,
                                    fit: BoxFit.cover,
                                    placeholder: () => const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 22,
                                      color: AppColors.primaryGreen,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 22,
                                    color: AppColors.primaryGreen,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _prodName,
                      decoration: inputDeco('Emri i produktit'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _prodPrice,
                      decoration: inputDeco('Çmimi'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addProduct(catValue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _addProduct(catValue),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Shto'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        for (final c in cats) ...[
          _CategoryProductTable(
            category: c,
            onDeleteCategory: () => m.removeCategory(c.id),
            onDeleteProduct: (pid) => m.removeProduct(c.id, pid),
            onEditProduct: (p) => _openEditDialog(context, c.id, p),
            onMoveIn: (p, fromCatId) => m.moveProduct(fromCatId, p.id, c.id),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _CategoryProductTable extends StatefulWidget {
  const _CategoryProductTable({
    required this.category,
    required this.onDeleteCategory,
    required this.onDeleteProduct,
    required this.onEditProduct,
    required this.onMoveIn,
  });

  final CategoryData category;
  final VoidCallback onDeleteCategory;
  final void Function(String productId) onDeleteProduct;
  final void Function(ProductItem product) onEditProduct;
  final void Function(ProductItem product, String fromCatId) onMoveIn;

  @override
  State<_CategoryProductTable> createState() => _CategoryProductTableState();
}

class _CategoryProductTableState extends State<_CategoryProductTable> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    return DragTarget<_ProductDrag>(
      onWillAcceptWithDetails: (d) => d.data.fromCatId != widget.category.id,
      onAcceptWithDetails: (d) =>
          widget.onMoveIn(d.data.product, d.data.fromCatId),
      builder: (context, candidateData, _) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isOver
                ? AppColors.lightGreenBg.withValues(alpha: 0.6)
                : AppColors.white,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGreenText,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${c.products.length} produkte',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Fshi kategorinë',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.negativeText,
                        onPressed: widget.onDeleteCategory,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.mediumGreenText,
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
                            color: AppColors.beige,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Nuk ka produkte në këtë kategori.',
                            style: TextStyle(
                              color: AppColors.lightGreenText,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            color: AppColors.lightGreenBg,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: const Row(
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
                                    'Çmimi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mediumGreenText,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(width: 88),
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
    required this.onEdit,
    required this.onDelete,
  });

  final ProductItem product;
  final bool isLast;
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
                style: const TextStyle(
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Ndrysho',
                    color: AppColors.primaryGreen,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: Icons.delete_outline,
                    tooltip: 'Fshi',
                    color: AppColors.negativeText,
                    onTap: widget.onDelete,
                  ),
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
    child: const Icon(
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
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hover
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}
