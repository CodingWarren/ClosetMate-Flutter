import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/data/models/outfit_model.dart';
import 'package:closetmate/data/repositories/clothing_repository.dart';
import 'package:closetmate/data/repositories/outfit_repository.dart';
import 'package:closetmate/shared/widgets/clothing_image.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class CreateOutfitScreen extends StatefulWidget {
  const CreateOutfitScreen({super.key});

  @override
  State<CreateOutfitScreen> createState() => _CreateOutfitScreenState();
}

class _CreateOutfitScreenState extends State<CreateOutfitScreen> {
  final ClothingRepository _clothingRepo = ClothingRepository();
  final OutfitRepository _outfitRepo = OutfitRepository();
  static const _uuid = Uuid();

  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<ClothingModel> _allClothing = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // 槽位选择
  ClothingModel? _topItem;
  ClothingModel? _bottomItem;
  ClothingModel? _outerItem;
  ClothingModel? _shoesItem;
  ClothingModel? _bagItem;
  final List<ClothingModel> _accessories = [];

  // 场景标签
  final Set<String> _selectedScenes = {};

  @override
  void initState() {
    super.initState();
    _loadClothing();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClothing() async {
    final items = await _clothingRepo.getAllClothing();
    if (!mounted) return;
    setState(() {
      _allClothing = items;
      _isLoading = false;
    });
  }

  bool get _hasAnyItem =>
      _topItem != null ||
      _bottomItem != null ||
      _outerItem != null ||
      _shoesItem != null ||
      _bagItem != null ||
      _accessories.isNotEmpty;

  Future<void> _save() async {
    if (!_hasAnyItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一件衣物')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final name = _nameCtrl.text.trim().isEmpty
        ? '我的搭配 ${now.month}月${now.day}日添加'
        : _nameCtrl.text.trim();

    final outfit = OutfitModel(
      id: _uuid.v4(),
      name: name,
      topId: _topItem?.id ?? '',
      bottomId: _bottomItem?.id ?? '',
      outerId: _outerItem?.id ?? '',
      shoesId: _shoesItem?.id ?? '',
      bagId: _bagItem?.id ?? '',
      accessoryIds: _accessories.map((a) => a.id).join(','),
      sceneTags: _selectedScenes.join(','),
      isFavorite: false,
      wearCount: 0,
      lastWornAt: 0,
      notes: _notesCtrl.text.trim(),
      isAiGenerated: false,
      createdAt: nowMs,
      updatedAt: nowMs,
    );

    await _outfitRepo.insertOutfit(outfit);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _pickClothing({
    required String slotLabel,
    required String? filterCategory,
    required ClothingModel? current,
    required ValueChanged<ClothingModel?> onSelected,
  }) async {
    final candidates = filterCategory == null
        ? _allClothing
        : _allClothing.where((c) => c.category == filterCategory).toList();

    final selected = await showModalBottomSheet<ClothingModel?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ClothingPickerSheet(
        slotLabel: slotLabel,
        candidates: candidates.isEmpty ? _allClothing : candidates,
        current: current,
      ),
    );

    if (selected != null || (selected == null && current != null)) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text(
          '创建搭配',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '搭配名称',
                            hintText: '如：周末休闲搭',
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '选择单品',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        _SlotTile(
                          label: '上衣',
                          emoji: '👕',
                          selected: _topItem,
                          onTap: () => _pickClothing(
                            slotLabel: '选择上衣',
                            filterCategory: null,
                            current: _topItem,
                            onSelected: (v) => setState(() => _topItem = v),
                          ),
                        ),
                        _SlotTile(
                          label: '下装',
                          emoji: '👖',
                          selected: _bottomItem,
                          onTap: () => _pickClothing(
                            slotLabel: '选择下装',
                            filterCategory: null,
                            current: _bottomItem,
                            onSelected: (v) => setState(() => _bottomItem = v),
                          ),
                        ),
                        _SlotTile(
                          label: '外套',
                          emoji: '🧥',
                          selected: _outerItem,
                          onTap: () => _pickClothing(
                            slotLabel: '选择外套',
                            filterCategory: null,
                            current: _outerItem,
                            onSelected: (v) => setState(() => _outerItem = v),
                          ),
                        ),
                        _SlotTile(
                          label: '鞋子',
                          emoji: '👟',
                          selected: _shoesItem,
                          onTap: () => _pickClothing(
                            slotLabel: '选择鞋子',
                            filterCategory: ClothingCategory.shoes,
                            current: _shoesItem,
                            onSelected: (v) => setState(() => _shoesItem = v),
                          ),
                        ),
                        _SlotTile(
                          label: '包包',
                          emoji: '👜',
                          selected: _bagItem,
                          onTap: () => _pickClothing(
                            slotLabel: '选择包包',
                            filterCategory: ClothingCategory.bag,
                            current: _bagItem,
                            onSelected: (v) => setState(() => _bagItem = v),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '场景标签',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: OutfitScene.all.map((scene) {
                            final isSelected = _selectedScenes.contains(scene);
                            return FilterChip(
                              selected: isSelected,
                              label: Text(scene),
                              onSelected: (_) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedScenes.remove(scene);
                                  } else {
                                    _selectedScenes.add(scene);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: '备注',
                            hintText: '添加备注（最多100字）',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Material(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_hasAnyItem && !_isSaving) ? _save : null,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('保存搭配'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── 槽位选择行 ───────────────────────────────────────────────────────────────

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final ClothingModel? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: selected != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 44,
                  height: 44,
                  color: colorScheme.primaryContainer,
                  alignment: Alignment.center,
                  child: selected!.imageUriList.isNotEmpty
                      ? ClothingImage(
                          imageUrl: selected!.imageUriList.first,
                          fit: BoxFit.cover,
                          width: 44,
                          height: 44,
                          fallbackIcon: Icons.checkroom,
                          fallbackIconSize: 20,
                        )
                      : Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              )
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
        title: Text(
          selected != null ? selected!.category : label,
          style: TextStyle(
            fontWeight: selected != null ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: selected != null && selected!.brand.isNotEmpty
            ? Text(selected!.brand)
            : Text(
                '点击选择$label',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
        trailing: selected != null
            ? const Icon(Icons.chevron_right)
            : Icon(Icons.add, color: colorScheme.primary),
        onTap: onTap,
      ),
    );
  }
}

// ─── 衣物选择底部面板 ─────────────────────────────────────────────────────────

class _ClothingPickerSheet extends StatelessWidget {
  const _ClothingPickerSheet({
    required this.slotLabel,
    required this.candidates,
    required this.current,
  });

  final String slotLabel;
  final List<ClothingModel> candidates;
  final ClothingModel? current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    slotLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (current != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('清除选择'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (candidates.isEmpty)
              const Expanded(
                child: Center(child: Text('衣橱里还没有合适的衣物')),
              )
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final clothing = candidates[index];
                    final isSelected = current?.id == clothing.id;
                    final imageUrl = clothing.imageUriList.isNotEmpty
                        ? clothing.imageUriList.first
                        : null;

                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(clothing),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  color: colorScheme.surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: imageUrl != null
                                      ? ClothingImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fallbackIcon: Icons.checkroom,
                                          fallbackIconSize: 32,
                                        )
                                      : const Icon(Icons.checkroom, size: 32),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.surface,
                                child: Text(
                                  clothing.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
