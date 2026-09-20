import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_colors.dart';
import '../../../../utils/image_utils.dart';
import '../../../../l10n/tr.dart';

const _kImageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'};

/// Skedarë që nuk janë foto produktesh.
const _kExcludedAssetNames = {
  'permanentlogo.png',
  'sellix_logo.svg',
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
  }).toList()..sort();
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
    useRootNavigator: false,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        Icons.photo_outlined,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zgjidh burimin e fotos',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          Text(
                            'Asetat e aplikacionit ose një skedar nga kompjuteri.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Nga asetat e aplikacionit',
                  subtitle: tr.fotoParakonfighuruara,
                  onTap: () => Navigator.pop(ctx, 'assets'),
                ),
                const SizedBox(height: 8),
                _SourceTile(
                  icon: Icons.upload_file_outlined,
                  title: 'Ngarko nga kompjuteri',
                  subtitle: 'PNG, JPG, WEBP…',
                  onTap: () => Navigator.pop(ctx, 'pc'),
                ),
                if (current != null && current.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SourceTile(
                    icon: Icons.hide_image_outlined,
                    title: 'Hiq foton',
                    subtitle: 'Produkti mbetet pa imazh.',
                    danger: true,
                    onTap: () => Navigator.pop(ctx, 'clear'),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr.anulo),
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

class _SourceTile extends StatefulWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends State<_SourceTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.danger ? AppColors.negativeText : AppColors.primaryGreen;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hover
                ? accent.withValues(alpha: 0.08)
                : AppColors.lightGreenBg.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? accent.withValues(alpha: 0.35)
                  : AppColors.lightGreenBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(widget.icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.danger
                            ? AppColors.negativeText
                            : AppColors.darkGreenText,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightGreenText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> showAssetPicker(BuildContext context, String? current) async {
  final assets = await loadImageAssets();
  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) {
      final dialogW = _assetDialogWidth(ctx);
      final dialogH = _assetDialogHeight(ctx);
      final items = <({String? path, String label})>[
        (path: null, label: tr.paFoto),
        for (final a in assets) (path: a, label: _assetLabel(a)),
      ];

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: dialogW,
          height: dialogH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.collections_outlined,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zgjidh foton',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkGreenText,
                            ),
                          ),
                          Text(
                            trf.photosInAssets(items.length - 1),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr.mbyll,
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 22),
                      color: AppColors.mediumGreenText,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: AppColors.lightGreenBorder),
              Expanded(
                child: assets.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            tr.nukUGjetenFotoAssetsImages,
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
                          final noPhoto =
                              currentPath == null || currentPath.isEmpty;
                          return _AssetPickerThumb(
                            path: item.path,
                            label: item.label,
                            selected: item.path == null
                                ? noPhoto
                                : currentPath == item.path,
                            onTap: () => Navigator.pop(ctx, item.path ?? ''),
                          );
                        },
                      ),
              ),
              Divider(height: 1, color: AppColors.lightGreenBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(tr.anulo),
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
                            placeholder: () => Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.lightGreenText,
                                size: 28,
                              ),
                            ),
                          )
                        : Center(
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
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
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
