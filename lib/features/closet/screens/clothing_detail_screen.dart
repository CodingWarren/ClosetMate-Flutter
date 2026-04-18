import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/data/models/outfit_model.dart';
import 'package:closetmate/data/repositories/clothing_repository.dart';
import 'package:closetmate/data/repositories/outfit_repository.dart';
import 'package:closetmate/data/services/image_edit_helper.dart';
import 'package:closetmate/data/services/recommend/outfit_recommend_service.dart';
import 'package:closetmate/shared/widgets/clothing_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ClothingDetailScreen extends StatefulWidget {
  const ClothingDetailScreen({
    super.key,
    required this.clothingId,
  });

  final String clothingId;

  @override
  State<ClothingDetailScreen> createState() => _ClothingDetailScreenState();
}

class _ClothingDetailScreenState extends State<ClothingDetailScreen> {
  final ClothingRepository _repository = ClothingRepository();
  final OutfitRepository _outfitRepository = OutfitRepository();

  ClothingModel? clothing;
  bool isLoading = true;
  bool isWearMarked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    final item = await _repository.getClothingById(widget.clothingId);
    if (!mounted) return;
    setState(() {
      clothing = item;
      isLoading = false;
    });
  }

  Future<void> _editImage(int index) async {
    final item = clothing;
    if (item == null) return;
    final imagePath = item.imageUriList[index];
    final editedPath = await ImageEditHelper.editImage(context, imagePath);
    if (editedPath != null && mounted) {
      final newUris = List<String>.from(item.imageUriList);
      newUris[index] = editedPath;
      await _repository.updateClothing(
        item.copyWith(
          imageUris: newUris.join(','),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await _load();
    }
  }

  Future<void> _showAiOutfitSheet() async {
    final item = clothing;
    if (item == null) return;

    final allClothing = await _repository.getAllClothing();
    if (!mounted) return;

    final result = OutfitRecommendService.generateForCoreItem(
      coreItem: item,
      allClothing: allClothing,
    );

    if (!mounted) return;

    if (result is RecommendInsufficientClothing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('衣橱里的衣物还不够多，无法生成搭配方案')),
      );
      return;
    }

    if (result is! RecommendSuccess) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AiOutfitSheet(
        coreItem: item,
        outfits: result.outfits,
        allClothing: allClothing,
        onSave: (outfit) async {
          await _outfitRepository.insertOutfit(outfit);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ 搭配已保存到我的搭配列表')),
            );
          }
        },
      ),
    );
  }

  Future<void> _markWorn() async {
    await _repository.incrementWearCount(widget.clothingId);
    if (!mounted) return;
    setState(() => isWearMarked = true);
    await _load();
  }

  Future<void> _updateStatus(String status) async {
    await _repository.updateStatus(widget.clothingId, status);
    await _load();
  }

  Future<void> _delete() async {
    await _repository.deleteClothing(widget.clothingId);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final item = clothing;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '衣物详情',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: item == null ? null : _markWorn,
            icon: Icon(
              isWearMarked ? Icons.check_circle : Icons.check_circle_outline,
              color: isWearMarked ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == '__delete__') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除衣物'),
                    content: const Text('确定要删除这件衣物吗？此操作无法撤销。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(
                          '删除',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _delete();
                }
                return;
              }
              await _updateStatus(value);
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem<String>(
                  enabled: false,
                  value: '__title__',
                  child: Text('修改状态'),
                ),
                ...ClothingStatus.all.map(
                  (status) => PopupMenuItem<String>(
                    value: status,
                    child: Row(
                      children: [
                        if (item?.status == status)
                          Icon(
                            Icons.check,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text(status),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: '__delete__',
                  child: Text(
                    '删除衣物',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : item == null
              ? const Center(child: Text('未找到该衣物'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.imageUriList.isNotEmpty)
                        SizedBox(
                          height: 360,
                          child: PageView.builder(
                            itemCount: item.imageUriList.length,
                      itemBuilder: (context, index) {
                              final imageUrl = item.imageUriList[index];
                              return GestureDetector(
                                onLongPress: () => _editImage(index),
                                child: Stack(
                                  children: [
                                    ClothingImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      fallbackIcon: Icons.image_not_supported_outlined,
                                      fallbackIconSize: 40,
                                    ),
                                    // 编辑提示（右下角）
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () => _editImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.55),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.crop_rotate, size: 14, color: Colors.white),
                                              SizedBox(width: 4),
                                              Text('编辑', style: TextStyle(color: Colors.white, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          height: 240,
                          width: double.infinity,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          alignment: Alignment.center,
                          child: const Text(
                            '👗',
                            style: TextStyle(fontSize: 64),
                          ),
                        ),
                      if (isWearMarked)
                        Container(
                          width: double.infinity,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '已标记今日穿着，穿着次数 +1',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.category,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                _StatusBadge(status: item.status),
                              ],
                            ),
                            if (item.brand.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.brand,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                _StatChip(label: '穿着次数', value: '${item.wearCount} 次'),
                                if (item.lastWornAt > 0)
                                  _StatChip(
                                    label: '上次穿着',
                                    value: _daysAgo(item.lastWornAt),
                                  ),
                                if (item.price > 0 && item.wearCount > 0)
                                  _StatChip(
                                    label: '每次成本',
                                    value: '¥${(item.price / item.wearCount).toStringAsFixed(1)}',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 20),
                            _DetailSection(
                              title: '基础信息',
                              children: [
                                _DetailRow(label: '季节', value: item.seasons.replaceAll(',', ' · ')),
                                _DetailRow(label: '颜色', value: item.colors.replaceAll(',', ' · ')),
                                _DetailRow(label: '风格', value: item.styles.replaceAll(',', ' · ')),
                              ],
                            ),
                            if (item.price > 0 ||
                                item.purchaseChannel.isNotEmpty ||
                                item.purchaseDate.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _DetailSection(
                                title: '购买信息',
                                children: [
                                  if (item.price > 0)
                                    _DetailRow(label: '价格', value: '¥${item.price}'),
                                  if (item.purchaseChannel.isNotEmpty)
                                    _DetailRow(label: '渠道', value: item.purchaseChannel),
                                  if (item.purchaseDate.isNotEmpty)
                                    _DetailRow(label: '日期', value: item.purchaseDate),
                                ],
                              ),
                            ],
                            if (item.storageLocation.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _DetailSection(
                                title: '存放信息',
                                children: [
                                  _DetailRow(label: '位置', value: item.storageLocation),
                                ],
                              ),
                            ],
                            if (item.notes.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _DetailSection(
                                title: '备注',
                                children: [
                                  Text(
                                    item.notes,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              '添加于 ${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(item.createdAt))}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final saved = await context.push<bool>(
                                        '/clothing/${widget.clothingId}/edit',
                                      );
                                      if (saved == true) {
                                        await _load();
                                      }
                                    },
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('编辑'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _showAiOutfitSheet,
                                    icon: const Icon(Icons.auto_awesome, size: 16),
                                    label: const Text('AI 搭配'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _daysAgo(int timestamp) {
    final days = (DateTime.now().millisecondsSinceEpoch - timestamp) ~/
        Duration.millisecondsPerDay;
    return days == 0 ? '今天' : '$days 天前';
  }
}

// ─── AI 搭配结果底部弹窗 ──────────────────────────────────────────────────────

class _AiOutfitSheet extends StatefulWidget {
  const _AiOutfitSheet({
    required this.coreItem,
    required this.outfits,
    required this.allClothing,
    required this.onSave,
  });

  final ClothingModel coreItem;
  final List<RecommendedOutfit> outfits;
  final List<ClothingModel> allClothing;
  final Future<void> Function(OutfitModel) onSave;

  @override
  State<_AiOutfitSheet> createState() => _AiOutfitSheetState();
}

class _AiOutfitSheetState extends State<_AiOutfitSheet> {
  final Set<String> _savedIds = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI 搭配方案',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '以「${widget.coreItem.category}」为核心单品，共 ${widget.outfits.length} 套方案',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: widget.outfits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final recommended = widget.outfits[index];
                  final isSaved = _savedIds.contains(recommended.outfit.id);

                  // 收集所有单品（含核心单品）
                  final items = <ClothingModel>[];
                  if (recommended.coreItem != null) items.add(recommended.coreItem!);
                  if (recommended.topItem != null && recommended.topItem!.id != recommended.coreItem?.id) {
                    items.add(recommended.topItem!);
                  }
                  if (recommended.bottomItem != null && recommended.bottomItem!.id != recommended.coreItem?.id) {
                    items.add(recommended.bottomItem!);
                  }
                  if (recommended.outerItem != null && recommended.outerItem!.id != recommended.coreItem?.id) {
                    items.add(recommended.outerItem!);
                  }
                  if (recommended.shoesItem != null && recommended.shoesItem!.id != recommended.coreItem?.id) {
                    items.add(recommended.shoesItem!);
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  recommended.outfit.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isSaved)
                                Icon(Icons.bookmark_added, size: 16, color: colorScheme.primary)
                              else
                                FilledButton.tonal(
                                  onPressed: () async {
                                    await widget.onSave(recommended.outfit);
                                    if (mounted) {
                                      setState(() => _savedIds.add(recommended.outfit.id));
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  child: const Text('保存', style: TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // 单品缩略图横向排列
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, idx) {
                                final c = items[idx];
                                final isCore = c.id == widget.coreItem.id;
                                final imageUrl = c.imageUriList.isNotEmpty ? c.imageUriList.first : null;

                                return Column(
                                  children: [
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 52,
                                            height: 52,
                                            color: isCore
                                                ? colorScheme.primaryContainer
                                                : colorScheme.surfaceContainerHighest,
                                            alignment: Alignment.center,
                                            child: imageUrl != null
                                                ? ClothingImage(
                                                    imageUrl: imageUrl,
                                                    fit: BoxFit.cover,
                                                    width: 52,
                                                    height: 52,
                                                    fallbackIcon: Icons.checkroom,
                                                    fallbackIconSize: 20,
                                                  )
                                                : const Icon(Icons.checkroom, size: 20),
                                          ),
                                        ),
                                        if (isCore)
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.star, size: 9, color: colorScheme.onPrimary),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.category,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isCore ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                        fontWeight: isCore ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (recommended.outfit.aiReason.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              recommended.outfit.aiReason,
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 10),
        Column(
          children: children
              .map(
                (child) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: child,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  Color _statusColor(BuildContext context) {
    switch (status) {
      case ClothingStatus.normal:
        return Colors.green;
      case ClothingStatus.toWash:
        return Colors.orange;
      case ClothingStatus.toRepair:
        return Colors.deepOrange;
      case ClothingStatus.idle:
        return Colors.blueGrey;
      case ClothingStatus.disposed:
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
