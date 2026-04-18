import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

/// 图片编辑工具类（旋转 / 裁剪）
///
/// 封装 image_cropper 调用，提供统一的编辑入口。
class ImageEditHelper {
  /// 打开图片编辑器，返回编辑后的文件路径；用户取消则返回 null。
  static Future<String?> editImage(
    BuildContext context,
    String imagePath,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      // 强制输出 PNG 格式，保留透明通道（防止透明背景变黑）
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
          title: '编辑图片',
          doneButtonTitle: '完成',
          cancelButtonTitle: '取消',
          rotateButtonsHidden: false,
          rotateClockwiseButtonHidden: false,
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    return croppedFile?.path;
  }
}
