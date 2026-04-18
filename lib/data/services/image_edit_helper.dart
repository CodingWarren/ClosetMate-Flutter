import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

class ImageEditHelper {
  /// 显示编辑选项底部弹窗（旋转 / 裁剪），SafeArea 确保按钮不与 home 手势冲突
  static Future<String?> showEditOptions(
    BuildContext context,
    String imagePath,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.rotate_left),
                title: const Text('向左旋转 90°'),
                onTap: () => Navigator.pop(context, 'rotate_left'),
              ),
              ListTile(
                leading: const Icon(Icons.rotate_right),
                title: const Text('向右旋转 90°'),
                onTap: () => Navigator.pop(context, 'rotate_right'),
              ),
              ListTile(
                leading: const Icon(Icons.crop),
                title: const Text('裁剪'),
                onTap: () => Navigator.pop(context, 'crop'),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'rotate_left') {
      return _rotateImage(imagePath, angle: -90);
    } else if (action == 'rotate_right') {
      return _rotateImage(imagePath, angle: 90);
    } else if (action == 'crop') {
      if (!context.mounted) return null;
      return editImage(context, imagePath);
    }
    return null;
  }

  /// 旋转图片，返回旋转后的临时文件路径
  static Future<String?> _rotateImage(
    String imagePath, {
    required double angle,
  }) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final rotated = img.copyRotate(decoded, angle: angle);
      final rotatedBytes = img.encodePng(rotated);

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(rotatedBytes);
      return tempPath;
    } catch (e) {
      print('ImageEditHelper: rotate error: $e');
      return null;
    }
  }

  /// 打开裁剪编辑器，返回编辑后的文件路径；用户取消则返回 null
  static Future<String?> editImage(
    BuildContext context,
    String imagePath,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      compressFormat: ImageCompressFormat.png,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '编辑图片',
          toolbarColor: colorScheme.primary,
          toolbarWidgetColor: colorScheme.onPrimary,
          activeControlsWidgetColor: colorScheme.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
          showCropGrid: true,
          backgroundColor: Colors.white,
          dimmedLayerColor: Colors.black54,
        ),
        IOSUiSettings(
          title: '裁剪图片',
          doneButtonTitle: '完成',
          cancelButtonTitle: '取消',
          rotateButtonsHidden: true,
          rotateClockwiseButtonHidden: true,
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    return croppedFile?.path;
  }
}
