import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Returns true when [path] points to a bundled asset (starts with "assets/").
bool isAssetPath(String path) => path.startsWith('assets/');

/// Picks one image file from the PC, copies it to the app's documents
/// directory under `pos_product_images/`, and returns the absolute path.
/// Returns null if the user cancels or if copying fails.
Future<String?> pickAndCopyImageFromPC() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final srcPath = result.files.first.path;
  if (srcPath == null) return null;

  final docsDir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory(p.join(docsDir.path, 'pos_product_images'));
  await imagesDir.create(recursive: true);

  final ext = p.extension(srcPath);
  final destPath =
      p.join(imagesDir.path, '${DateTime.now().millisecondsSinceEpoch}$ext');
  await File(srcPath).copy(destPath);
  return destPath;
}

/// Renders a product image from either a bundled asset path or an absolute
/// file-system path. Falls back to [placeholder] when path is null/empty or
/// when the image cannot be loaded.
Widget productImage(
  String? path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget Function()? placeholder,
}) {
  Widget fallback() =>
      placeholder?.call() ?? const SizedBox.shrink();

  if (path == null || path.isEmpty) return fallback();

  if (isAssetPath(path)) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => fallback(),
    );
  }

  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => fallback(),
  );
}
