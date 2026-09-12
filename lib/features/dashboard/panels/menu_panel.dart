import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../manager/manager_data.dart';
import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../utils/image_utils.dart';
import '../widgets/menu/asset_picker.dart';
import '../widgets/menu/category_product_table.dart';
import '../../../l10n/tr.dart';

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
    final picked = await showImageSourcePicker(context, _newProductImage);
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

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    CategoryData category,
  ) async {
    final count = category.products.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.fshiKategorine2),
        content: Text(
          count > 0
              ? 'Kategoria «${category.name}» dhe $count produkte do të fshihen përgjithmonë.'
              : 'Kategoria «${category.name}» do të fshihet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr.anulo),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.negativeText,
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

  Widget _priceField(String catId) {
    return TextField(
      controller: _prodPrice,
      decoration: inputDeco('0.00', prefix: '€ '),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _addProduct(catId),
    );
  }

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
            tr.nukKaKategoriShtoKategoriVazhduar,
            style: TextStyle(color: AppColors.lightGreenText),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _catCtrl,
                  decoration: inputDeco(tr.emriKategoriseRe),
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
            tr.shtuarProdukteDuhetEkzistojePaktenKategori,
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
                decoration: inputDeco(tr.emriKategoriseRe),
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

        DashboardSectionCard(
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final scheme = Theme.of(context).colorScheme;
              final image = GestureDetector(
                onTap: _pickNewImage,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: compact ? double.infinity : 148,
                    height: compact ? 148 : 188,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.14),
                          scheme.primary.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _newProductImage != null
                          ? productImage(
                              _newProductImage,
                              width: compact ? double.infinity : 148,
                              height: compact ? 148 : 188,
                              fit: BoxFit.cover,
                              placeholder: () => const _ImagePlaceholder(),
                            )
                          : const _ImagePlaceholder(),
                    ),
                  ),
                ),
              );

              final form = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Detajet e pijes',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    tr.krijoArtikullRiMenunePosIt,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _MenuFieldLabel(
                    icon: Icons.category_outlined,
                    text: 'Kategoria',
                  ),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<String>(
                    initialValue: catValue,
                    isExpanded: true,
                    decoration: inputDeco(tr.zgjidhKategorine),
                    items: [
                      for (final c in cats)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _selectedCatId = v),
                  ),
                  const SizedBox(height: 14),
                  if (compact) ...[
                    _MenuFieldLabel(
                      icon: Icons.local_bar_outlined,
                      text: 'Emri i pijes',
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _prodName,
                      decoration: inputDeco('p.sh. Espresso, Cola, Mojito'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _MenuFieldLabel(icon: Icons.euro_outlined, text: tr.cmimi),
                    const SizedBox(height: 7),
                    _priceField(catValue),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MenuFieldLabel(
                                icon: Icons.local_bar_outlined,
                                text: 'Emri i pijes',
                              ),
                              const SizedBox(height: 7),
                              TextField(
                                controller: _prodName,
                                decoration: inputDeco(
                                  'p.sh. Espresso, Cola, Mojito',
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 142,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MenuFieldLabel(
                                icon: Icons.euro_outlined,
                                text: tr.cmimi,
                              ),
                              const SizedBox(height: 7),
                              _priceField(catValue),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _addProduct(catValue),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(tr.shtoPijenMenu),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.local_bar_rounded,
                            color: scheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr.shtoPijeRe,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                              Text(
                                tr.plotesoInformacioninPersonalizoFoton,
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
                    const SizedBox(height: 24),
                    if (compact) ...[
                      image,
                      const SizedBox(height: 22),
                      form,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          image,
                          const SizedBox(width: 24),
                          Expanded(child: form),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),

        for (final c in cats) ...[
          CategoryProductTable(
            category: c,
            onDeleteCategory: () => _confirmDeleteCategory(context, c),
            onDeleteProduct: (pid) => m.removeProduct(c.id, pid),
            onEditProduct: (p) => _openEditDialog(context, c.id, p),
            onMoveIn: (p, fromCatId) => m.moveProduct(fromCatId, p.id, c.id),
            onReorderProduct: (pid, dir) => m.reorderProduct(c.id, pid, dir),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _MenuFieldLabel extends StatelessWidget {
  const _MenuFieldLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 34,
          color: scheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          'Shto foto',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Opsionale',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
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
    final pr = double.tryParse(_priceCtrl.text.trim()) ?? 0;
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

  Widget _noImageBox() => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: AppColors.lightGreenBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(
      Icons.hide_image_outlined,
      size: 28,
      color: AppColors.lightGreenText,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
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
                    child: _editImage != null
                        ? productImage(
                            _editImage,
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
                      Text(
                        'Fotoja',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.lightGreenText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined, size: 16),
                        label: const Text('Ndrysho foton'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: BorderSide(color: AppColors.primaryGreen),
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
                controller: _nameCtrl,
                decoration: inputDeco('Emri i produktit'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceCtrl,
                decoration: inputDeco(tr.cmimi),
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr.anulo),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
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
    );
  }
}
