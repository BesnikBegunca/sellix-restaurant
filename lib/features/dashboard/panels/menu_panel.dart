import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../manager/manager_data.dart';
import '../../../models/mock_data.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/dashboard_helpers.dart';
import '../../../utils/image_utils.dart';
import '../widgets/menu/asset_picker.dart';
import '../widgets/menu/category_product_table.dart';

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
                              final picked = await showImageSourcePicker(
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
                                    width: 52,
                                    height: 52,
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
          CategoryProductTable(
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

