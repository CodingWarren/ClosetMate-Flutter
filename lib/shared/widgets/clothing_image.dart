import 'dart:io';

import 'package:flutter/material.dart';

/// 智能图片组件：自动判断本地路径或网络 URL
///
/// - 以 `http://` 或 `https://` 开头 → 使用 Image.network
/// - 其他（本地绝对路径）→ 使用 Image.file
class ClothingImage extends StatelessWidget {
  const ClothingImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackIcon = Icons.checkroom,
    this.fallbackIconSize = 36.0,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  bool get _isNetwork =>
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isNetwork) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _fallback(colorScheme),
      );
    }

    final file = File(imageUrl);
    final exists = file.existsSync();
    if (!exists) {
      print('ClothingImage: File does not exist: $imageUrl');
      return _fallback(colorScheme);
    }

    // 调试：打印文件信息
    try {
      final stat = file.statSync();
      print('ClothingImage: File exists, size: ${stat.size} bytes, path: $imageUrl');
    } catch (e) {
      print('ClothingImage: Error checking file: $e');
    }

    return Image.file(
      file,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        print('ClothingImage: Error loading image: $error, path: $imageUrl');
        return _fallback(colorScheme);
      },
    );
  }

  Widget _fallback(ColorScheme colorScheme) {
    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: fallbackIconSize,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
