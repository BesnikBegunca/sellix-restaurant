import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_colors.dart';
import '../../../../utils/image_utils.dart';

const _kImageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};

String _assetLabel(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

Future<List<String>> loadImageAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest.listAssets().where((a) {
    if (!a.startsWith('assets/images/')) return false;
    final lower = a.toLowerCase();
    return _kImageExtensions.any((ext) => lower.endsWith(ext));
  }).toList()..sort();
}

Future<String?> showImageSourcePicker(
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
    return showAssetPicker(context, current);
  }
  return pickAndCopyImageFromPC();
}

Future<String?> showAssetPicker(BuildContext context, String? current) async {
  final assets = await loadImageAssets();
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
