import 'dart:io';

import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/data/repositories/clothing_repository.dart';
import 'package:closetmate/data/services/ai/baidu_ai_service.dart';
import 'package:closetmate/data/services/ai/remove_bg_service.dart';
import 'package:closetmate/data/services/image_edit_helper.dart';
import 'package:closetmate/data/services/image_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class AddClothingScreen extends StatefulWidget {
  const AddClothingScreen({
    super.key,
    this.editClothingId,
  });

  final String? editClothingId;

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  final ClothingRepository _repository = ClothingRepository();
  final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  int _currentStep = 1;
  bool _isSaving = false;

  // Step 1 – images
  List<String> _imageUris = [];

  // Step 2 – basic info
  String _selectedCategory = '';
  Set<String> _selectedSeasons = {};
  Set<String> _selectedColors = {};
  Set<String> _selectedStyles = {};

  // AI 状态
  bool _isAiTagging = false;
  String _aiTagMessage = '';
  String _originalImageUri = '';
  bool _imageProcessed = false;
  // 正在处理的图片索引（-1 表示没有）
  int _processingImageIndex = -1;

  // Step 3 – detail info
  final _brandCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _selectedPurchaseChannel = '';
  final _purchaseDateCtrl = TextEditingController();
  final _storageLocationCtrl = TextEditingController();
  String _selectedStatus = ClothingStatus.normal;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.editClothingId != null) {
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    _purchaseDateCtrl.dispose();
    _storageLocationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final item = await _repository.getClothingById(widget.editClothingId!);
    if (item == null || !mounted) return;
    setState(() {
      _imageUris = item.imageUriList;
      _selectedCategory = item.category;
      _selectedSeasons = item.seasonList.toSet();
      _selectedColors = item.colorList.toSet();
      _selectedStyles = item.styleList.toSet();
      _brandCtrl.text = item.brand;
      _priceCtrl.text = item.price > 0 ? item.price.toString() : '';
      _selectedPurchaseChannel = item.purchaseChannel;
      _purchaseDateCtrl.text = item.purchaseDate;
      _storageLocationCtrl.text = item.storageLocation;
      _selectedStatus = item.status;
      _notesCtrl.text = item.notes;
    });
  }

  Future<void> _pickFromGallery() async {
    if (_imageUris.length >= 5) return;
    final files = await _picker.pickMultiImage(limit: 5 - _imageUris.length);
    if (files.isEmpty) return;

    // 先压缩图片（后台，不阻塞 UI）
    final persisted = await ImageStorageService.copyAndCompressAll(
      files.map((f) => f.path).toList(),
    );
    if (!mounted) return;

    final newUris = [..._imageUris, ...persisted].take(5).toList();
    setState(() => _imageUris = newUris);

    // 对第一张新图片触发 AI 处理（非阻塞，在卡片上显示遮罩）
    if (persisted.isNotEmpty) {
      final idx = newUris.indexOf(persisted.first);
      _triggerAiProcessingAsync(persisted.first, idx);
    }
  }

  Future<void> _takePhoto() async {
    if (_imageUris.length >= 5) return;
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return;

    final persisted = await ImageStorageService.copyAndCompress(file.path);
    if (!mounted) return;

    final newUris = [..._imageUris, persisted].take(5).toList();
    setState(() => _imageUris = newUris);

    final idx = newUris.indexOf(persisted);
    _triggerAiProcessingAsync(persisted, idx);
  }

  /// 非阻塞 AI 抠图：在图片卡片上显示遮罩，不阻塞表单操作
  void _triggerAiProcessingAsync(String imagePath, int imageIndex) {
    setState(() {
      _processingImageIndex = imageIndex;
      _originalImageUri = imagePath;
    });

    RemoveBgService.removeBackground(imagePath).then((result) async {
      if (!mounted) return;
      setState(() => _processingImageIndex = -1);

      if (result is RemoveBgSuccess) {
        // 弹出对比弹窗让用户选择
        final useProcessed = await _showAiResultDialog(
          originalPath: imagePath,
          processedPath: result.processedPath,
        );
        if (useProcessed == true && mounted) {
          setState(() {
            _imageUris = _imageUris.map((uri) {
              return uri == imagePath ? result.processedPath : uri;
            }).toList();
            _imageProcessed = true;
          });
        }
      } else if (result is RemoveBgError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI 抠图失败：${result.message}'),
              action: SnackBarAction(label: '知道了', onPressed: () {}),
            ),
          );
        }
      }
    });
  }

  /// 手动重新触发 AI 抠图（点击图片上的 ✨ 按钮）
  void _retriggerAi(String imagePath, int imageIndex) {
    _triggerAiProcessingAsync(imagePath, imageIndex);
  }

  /// 编辑图片（旋转/裁剪）
  Future<void> _editImage(String imagePath, int imageIndex) async {
    final editedPath = await ImageEditHelper.showEditOptions(context, imagePath);
    if (editedPath != null && mounted) {
      // 将编辑后的图片持久化到应用目录
      final persistedPath = await ImageStorageService.copyAndCompress(editedPath);
      setState(() {
        _imageUris[imageIndex] = persistedPath;
      });
    }
  }

  Future<bool?> _showAiResultDialog({
    required String originalPath,
    required String processedPath,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            const Text('AI 图片处理', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('选择你想使用的图片效果'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('原图', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(originalPath), height: 120, fit: BoxFit.cover),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'AI 抠图',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(processedPath), height: 120, fit: BoxFit.cover),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('使用原图'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.auto_awesome, size: 14),
            label: const Text('使用 AI 抠图'),
          ),
        ],
      ),
    );
  }

  Future<void> _runBaiduAiTagging() async {
    if (_imageUris.isEmpty) return;
    setState(() {
      _isAiTagging = true;
      _aiTagMessage = 'AI 正在识别衣物信息...';
    });

    final result = await BaiduAiService.recognizeClothing(_imageUris.first);

    if (!mounted) return;

    if (result is AiTagSuccess) {
      setState(() {
        _isAiTagging = false;
        _aiTagMessage = 'AI 已识别并预填标签，✨ 标记为 AI 推荐，可修改';
        if (_selectedCategory.isEmpty && result.category.isNotEmpty) {
          _selectedCategory = result.category;
        }
        if (_selectedSeasons.isEmpty && result.seasons.isNotEmpty) {
          _selectedSeasons = result.seasons.toSet();
        }
        if (_selectedColors.isEmpty && result.colors.isNotEmpty) {
          _selectedColors = result.colors.toSet();
        }
        if (_selectedStyles.isEmpty && result.styles.isNotEmpty) {
          _selectedStyles = result.styles.toSet();
        }
      });
    } else if (result is AiTagError) {
      setState(() {
        _isAiTagging = false;
        _aiTagMessage = 'AI 识别失败：${result.message}，请手动选择标签';
      });
    }
  }

  void _onEnterStep2() {
    // 编辑模式下不自动触发 AI 识别，避免覆盖用户已有的标签数据
    final isEditMode = widget.editClothingId != null;
    if (!isEditMode && _imageUris.isNotEmpty && _aiTagMessage.isEmpty) {
      _runBaiduAiTagging();
    }
  }

  bool get _isStep2Valid =>
      _selectedCategory.isNotEmpty &&
      _selectedSeasons.isNotEmpty &&
      _selectedColors.isNotEmpty &&
      _selectedStyles.isNotEmpty;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final imageUrisStr = _imageUris.join(',');

    if (widget.editClothingId != null) {
      final existing = await _repository.getClothingById(widget.editClothingId!);
      if (existing != null) {
        await _repository.updateClothing(
          existing.copyWith(
            imageUris: imageUrisStr,
            category: _selectedCategory,
            seasons: _selectedSeasons.join(','),
            colors: _selectedColors.join(','),
            styles: _selectedStyles.join(','),
            brand: _brandCtrl.text.trim(),
            price: double.tryParse(_priceCtrl.text) ?? 0.0,
            purchaseChannel: _selectedPurchaseChannel,
            purchaseDate: _purchaseDateCtrl.text.trim(),
            storageLocation: _storageLocationCtrl.text.trim(),
            status: _selectedStatus,
            notes: _notesCtrl.text.trim(),
            updatedAt: now,
          ),
        );
      }
    } else {
      await _repository.insertClothing(
        ClothingModel(
          id: _uuid.v4(),
          imageUris: imageUrisStr,
          category: _selectedCategory,
          seasons: _selectedSeasons.join(','),
          colors: _selectedColors.join(','),
          styles: _selectedStyles.join(','),
          brand: _brandCtrl.text.trim(),
          price: double.tryParse(_priceCtrl.text) ?? 0.0,
          purchaseChannel: _selectedPurchaseChannel,
          purchaseDate: _purchaseDateCtrl.text.trim(),
          storageLocation: _storageLocationCtrl.text.trim(),
          status: _selectedStatus,
          notes: _notesCtrl.text.trim(),
          originalImageUri: _originalImageUri,
          imageProcessed: _imageProcessed,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editClothingId != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: Text(
          isEdit ? '编辑衣物' : '添加衣物',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: _currentStep),
          const Divider(height: 1),
          Expanded(
            child: _currentStep == 1
                ? _Step1ImagePicker(
                    imageUris: _imageUris,
                    processingIndex: _processingImageIndex,
                    imageProcessed: _imageProcessed,
                    onPickGallery: _pickFromGallery,
                    onTakePhoto: _takePhoto,
                    onRemove: (uri) {
                      setState(() => _imageUris.remove(uri));
                    },
                    onRetriggerAi: _retriggerAi,
                    onEditImage: _editImage,
                  )
                : _currentStep == 2
                    ? _Step2BasicInfo(
                        selectedCategory: _selectedCategory,
                        onCategoryChange: (v) => setState(() => _selectedCategory = v),
                        selectedSeasons: _selectedSeasons,
                        onSeasonsChange: (v) => setState(() => _selectedSeasons = v),
                        selectedColors: _selectedColors,
                        onColorsChange: (v) => setState(() => _selectedColors = v),
                        selectedStyles: _selectedStyles,
                        onStylesChange: (v) => setState(() => _selectedStyles = v),
                        isAiTagging: _isAiTagging,
                        aiTagMessage: _aiTagMessage,
                      )
                    : _Step3DetailInfo(
                        brandCtrl: _brandCtrl,
                        priceCtrl: _priceCtrl,
                        selectedPurchaseChannel: _selectedPurchaseChannel,
                        onPurchaseChannelChange: (v) =>
                            setState(() => _selectedPurchaseChannel = v),
                        purchaseDateCtrl: _purchaseDateCtrl,
                        storageLocationCtrl: _storageLocationCtrl,
                        selectedStatus: _selectedStatus,
                        onStatusChange: (v) => setState(() => _selectedStatus = v),
                        notesCtrl: _notesCtrl,
                      ),
          ),
          _BottomButtons(
            currentStep: _currentStep,
            isSaving: _isSaving,
            isStep2Valid: _isStep2Valid,
            isEdit: isEdit,
            onBack: () => setState(() => _currentStep--),
            onNext: () {
              if (_currentStep < 3) {
                final nextStep = _currentStep + 1;
                setState(() => _currentStep = nextStep);
                if (nextStep == 2) _onEnterStep2();
              } else {
                _save();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─── 步骤指示器 ───────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['上传图片', '基础信息', '详细信息'];
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          final step = index + 1;
          final isActive = step == currentStep;
          final isDone = step < currentStep;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isActive || isDone)
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                      : Text(
                          '$step',
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: (isActive || isDone) ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── 步骤1：图片（含卡片级 AI 处理遮罩）────────────────────────────────────────

class _Step1ImagePicker extends StatelessWidget {
  const _Step1ImagePicker({
    required this.imageUris,
    required this.processingIndex,
    required this.imageProcessed,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onRemove,
    required this.onRetriggerAi,
    required this.onEditImage,
  });

  final List<String> imageUris;
  final int processingIndex;
  final bool imageProcessed;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final ValueChanged<String> onRemove;
  final void Function(String uri, int index) onRetriggerAi;
  final void Function(String uri, int index) onEditImage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('上传衣物图片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '最多5张，支持拍照或从相册选择（可跳过）',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          // AI 功能说明 / 已处理标记
          if (imageProcessed)
            _InfoBanner(
              icon: Icons.check_circle,
              text: '已使用 AI 抠图效果',
              color: colorScheme.primaryContainer,
              iconColor: colorScheme.primary,
            )
          else if (imageUris.isEmpty)
            _InfoBanner(
              icon: Icons.auto_awesome,
              text: '上传图片后，AI 将自动去除背景，生成干净的商品图效果',
              color: colorScheme.primaryContainer,
              iconColor: colorScheme.primary,
            ),
          const SizedBox(height: 16),
          // 图片网格（最多5张）
          Row(
            children: [
              ...imageUris.take(5).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final uri = entry.value;
                final isProcessing = index == processingIndex;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Stack(
                        children: [
                          // 图片
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(uri),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.broken_image),
                                );
                              },
                            ),
                          ),
                          // AI 处理中遮罩（仅当前处理的图片）
                          if (isProcessing)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'AI处理中',
                                        style: TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // 删除按钮（处理中时隐藏）
                          if (!isProcessing)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => onRemove(uri),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close, size: 14, color: colorScheme.onError),
                                ),
                              ),
                            ),
                          // 编辑图片按钮（左下角，处理中时隐藏）
                          if (!isProcessing)
                            Positioned(
                              bottom: MediaQuery.of(context).padding.bottom + 4,
                              left: 4,
                              child: GestureDetector(
                                onTap: () => onEditImage(uri, index),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.crop_rotate, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          // 重新触发 AI 按钮（仅第一张图片，且没有在处理中）
                          if (!isProcessing && index == 0 && processingIndex == -1)
                            Positioned(
                              bottom: MediaQuery.of(context).padding.bottom + 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => onRetriggerAi(uri, index),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.auto_awesome, size: 14, color: colorScheme.onPrimary),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              // 添加按钮（未满5张时显示）
              if (imageUris.length < 5)
                Expanded(
                  child: GestureDetector(
                    onTap: onPickGallery,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 28, color: colorScheme.onSurfaceVariant),
                            const SizedBox(height: 4),
                            Text('添加', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // 空位占位
              ...List.generate(
                (5 - imageUris.length - 1).clamp(0, 5),
                (_) => const Expanded(child: SizedBox()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: imageUris.length < 5 && processingIndex == -1 ? onTakePhoto : null,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('拍照'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: imageUris.length < 5 && processingIndex == -1 ? onPickGallery : null,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('相册'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: iconColor)),
          ),
        ],
      ),
    );
  }
}

// ─── 步骤2：基础信息 ──────────────────────────────────────────────────────────

class _Step2BasicInfo extends StatelessWidget {
  const _Step2BasicInfo({
    required this.selectedCategory,
    required this.onCategoryChange,
    required this.selectedSeasons,
    required this.onSeasonsChange,
    required this.selectedColors,
    required this.onColorsChange,
    required this.selectedStyles,
    required this.onStylesChange,
    this.isAiTagging = false,
    this.aiTagMessage = '',
  });

  final String selectedCategory;
  final ValueChanged<String> onCategoryChange;
  final Set<String> selectedSeasons;
  final ValueChanged<Set<String>> onSeasonsChange;
  final Set<String> selectedColors;
  final ValueChanged<Set<String>> onColorsChange;
  final Set<String> selectedStyles;
  final ValueChanged<Set<String>> onStylesChange;
  final bool isAiTagging;
  final String aiTagMessage;

  static const _colorOptions = [
    '白', '黑', '灰', '米', '红', '粉', '橙', '黄', '绿', '蓝', '紫', '棕', '花纹', '条纹', '格纹',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('基础信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('以下字段均为必填', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (isAiTagging || aiTagMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (isAiTagging)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                    )
                  else
                    Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiTagMessage,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _FormSection(
            title: '品类 *',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ClothingCategory.all.map((category) {
                return FilterChip(
                  selected: selectedCategory == category,
                  label: Text(category),
                  onSelected: (_) => onCategoryChange(category),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          _FormSection(
            title: '季节 *（可多选）',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ClothingSeason.all.map((season) {
                final isSelected = selectedSeasons.contains(season);
                return FilterChip(
                  selected: isSelected,
                  label: Text(season),
                  onSelected: (_) {
                    final newSet = isSelected
                        ? (Set<String>.from(selectedSeasons)..remove(season))
                        : (Set<String>.from(selectedSeasons)..add(season));
                    onSeasonsChange(newSet);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          _FormSection(
            title: '颜色 *（可多选）',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((color) {
                final isSelected = selectedColors.contains(color);
                return FilterChip(
                  selected: isSelected,
                  label: Text(color),
                  onSelected: (_) {
                    final newSet = isSelected
                        ? (Set<String>.from(selectedColors)..remove(color))
                        : (Set<String>.from(selectedColors)..add(color));
                    onColorsChange(newSet);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          _FormSection(
            title: '风格 *（可多选）',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ClothingStyle.all.map((style) {
                final isSelected = selectedStyles.contains(style);
                return FilterChip(
                  selected: isSelected,
                  label: Text(style),
                  onSelected: (_) {
                    final newSet = isSelected
                        ? (Set<String>.from(selectedStyles)..remove(style))
                        : (Set<String>.from(selectedStyles)..add(style));
                    onStylesChange(newSet);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── 步骤3：详细信息 ──────────────────────────────────────────────────────────

class _Step3DetailInfo extends StatelessWidget {
  const _Step3DetailInfo({
    required this.brandCtrl,
    required this.priceCtrl,
    required this.selectedPurchaseChannel,
    required this.onPurchaseChannelChange,
    required this.purchaseDateCtrl,
    required this.storageLocationCtrl,
    required this.selectedStatus,
    required this.onStatusChange,
    required this.notesCtrl,
  });

  final TextEditingController brandCtrl;
  final TextEditingController priceCtrl;
  final String selectedPurchaseChannel;
  final ValueChanged<String> onPurchaseChannelChange;
  final TextEditingController purchaseDateCtrl;
  final TextEditingController storageLocationCtrl;
  final String selectedStatus;
  final ValueChanged<String> onStatusChange;
  final TextEditingController notesCtrl;

  static const _purchaseChannels = [
    '实体店', '淘宝', '天猫', '京东', '拼多多', '抖音', '小红书', '海外购', '二手', '礼物', '其他',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('详细信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('以下字段均为选填', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: '品牌', hintText: '如：优衣库、ZARA')),
          const SizedBox(height: 16),
          TextField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            decoration: const InputDecoration(labelText: '购买价格（元）', hintText: '0.00'),
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: '购买渠道',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _purchaseChannels.map((channel) {
                return FilterChip(
                  selected: selectedPurchaseChannel == channel,
                  label: Text(channel),
                  onSelected: (_) => onPurchaseChannelChange(selectedPurchaseChannel == channel ? '' : channel),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: purchaseDateCtrl, decoration: const InputDecoration(labelText: '购买日期', hintText: 'YYYY-MM-DD')),
          const SizedBox(height: 16),
          TextField(controller: storageLocationCtrl, decoration: const InputDecoration(labelText: '存放位置', hintText: '如：衣柜第二层')),
          const SizedBox(height: 16),
          _FormSection(
            title: '衣物状态',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ClothingStatus.all.where((s) => s != ClothingStatus.disposed).map((status) {
                return FilterChip(
                  selected: selectedStatus == status,
                  label: Text(status),
                  onSelected: (_) => onStatusChange(status),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: notesCtrl,
            maxLines: 4,
            maxLength: 200,
            decoration: const InputDecoration(labelText: '备注', hintText: '添加备注（最多200字）', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── 通用表单区块 ─────────────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ─── 底部按钮 ─────────────────────────────────────────────────────────────────

class _BottomButtons extends StatelessWidget {
  const _BottomButtons({
    required this.currentStep,
    required this.isSaving,
    required this.isStep2Valid,
    required this.isEdit,
    required this.onBack,
    required this.onNext,
  });

  final int currentStep;
  final bool isSaving;
  final bool isStep2Valid;
  final bool isEdit;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final canProceed = currentStep == 2 ? isStep2Valid : true;

    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Row(
          children: [
            if (currentStep > 1) ...[
              Expanded(child: OutlinedButton(onPressed: onBack, child: const Text('上一步'))),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                onPressed: (canProceed && !isSaving) ? onNext : null,
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(currentStep == 3 ? (isEdit ? '保存修改' : '完成添加') : '下一步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
