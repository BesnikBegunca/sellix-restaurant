import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_colors.dart';
import '../../../../utils/image_utils.dart';

const _kImageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};

/// Skedarë që nuk janë foto produktesh.
const _kExcludedAssetNames = {
  'permanentlogo.png',
  'iconpos.ico',
};

String _assetLabel(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

Future<List<String>> loadImageAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest.listAssets().where((a) {
    if (!a.startsWith('assets/images/')) return false;
    final fileName = a.split('/').last.toLowerCase();
    if (_kExcludedAssetNames.contains(fileName)) return false;
    final lower = a.toLowerCase();
    return _kImageExtensions.any((ext) => lower.endsWith(ext));
  }).toList()
    ..sort();
}

double _assetDialogWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (w * 0.52).clamp(440.0, 680.0);
}

double _assetDialogHeight(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  return (h * 0.62).clamp(380.0, 560.0);
}

Future<String?> showImageSourcePicker(
  BuildContext context,
  String? current,
) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final w = _assetDialogWidth(ctx).clamp(320.0, 420.0);
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Zgjidh burimin e fotos',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: AppColors.darkGreenText,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Nga asetat e aplikacionit'),
                  subtitle: const Text('Foto të parakonfighuruara'),
                  onTap: () => Navigator.pop(ctx, 'assets'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.upload_file_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Ngarko nga kompjuteri'),
                  subtitle: const Text('PNG, JPG, WEBP…'),
                  onTap: () => Navigator.pop(ctx, 'pc'),
                ),
                if (current != null && current.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.hide_image_outlined,
                      color: AppColors.negativeText,
                    ),
                    title: const Text(
                      'Hiq foton',
                      style: TextStyle(color: AppColors.negativeText),
                    ),
                    onTap: () => Navigator.pop(ctx, 'clear'),
                  ),
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
    },
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
    builder: (ctx) {
      final dialogW = _assetDialogWidth(ctx);
      final dialogH = _assetDialogHeight(ctx);
      final items = <({String? path, String label})>[
        (path: null, label: 'Pa foto'),
        for (final a in assets) (path: a, label: _assetLabel(a)),
      ];

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: dialogW,
          height: dialogH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Zgjidh foton',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreenText,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Mbyll',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 22),
                      color: AppColors.mediumGreenText,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${items.length - 1} foto në asetat e aplikacionit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.lightGreenBorder),
              Expanded(
                child: assets.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nuk u gjetën foto në assets/images/.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.mediumGreenText),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 112,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final currentPath = current?.trim();
                          final noPhoto = currentPath == null || currentPath.isEmpty;
                          return _AssetPickerThumb(
                            path: item.path,
                            label: item.label,
                            selected: item.path == null
                                ? noPhoto
                                : currentPath == item.path,
                            onTap: () => Navigator.pop(
                              ctx,
                              item.path ?? '',
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1, color: AppColors.lightGreenBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Anulo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
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
    final borderColor = widget.selected
        ? AppColors.primaryGreen
        : _hover
            ? AppColors.primaryGreen.withValues(alpha: 0.45)
            : AppColors.lightGreenBorder;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  child: ColoredBox(
                    color: AppColors.lightGreenBg,
                    child: widget.path != null
                        ? productImage(
                            widget.path,
                            fit: BoxFit.contain,
                            placeholder: () => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.lightGreenText,
                                size: 28,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.hide_image_outlined,
                              color: AppColors.lightGreenText,
                              size: 28,
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 7),
                child: Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.15,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w500,
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
