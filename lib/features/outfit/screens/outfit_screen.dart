import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/data/models/outfit_model.dart';
import 'package:closetmate/data/services/recommend/outfit_recommend_service.dart';
import 'package:closetmate/features/outfit/outfit_controller.dart';
import 'package:closetmate/shared/widgets/clothing_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OutfitScreen extends ConsumerWidget {
  const OutfitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(outfitControllerProvider);
    final controller = ref.read(outfitControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '穿搭搭配',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!state.isLoading && state.outfitList.isNotEmpty)
              Text(
                '${state.outfitList.length} 套',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: controller.toggleFavoritesOnly,
            icon: Icon(
              state.showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: state.showFavoritesOnly
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await context.push<bool>('/outfits/create');
          if (saved == true && context.mounted) {
            await controller.refreshRecommendations();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 场景筛选横向滚动
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: state.selectedSceneFilter.isEmpty,
                    label: const Text('全部'),
                    onSelected: (_) => controller.setSceneFilter(''),
                  ),
                ),
                ...OutfitScene.all.map(
                  (scene) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: state.selectedSceneFilter == scene,
                      label: Text(scene),
                      onSelected: (_) => controller.setSceneFilter(scene),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: controller.refreshRecommendations,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        // AI 推荐区域
                        _AiRecommendSection(
                          recommendState: state.recommendState,
                          allClothing: state.allClothing,
                          onRefresh: controller.refreshRecommendations,
                          onSaveOutfit: controller.saveRecommendedOutfit,
                          onFeedback: controller.submitFeedback,
                          onNavigateToCloset: () => context.go('/'),
                          onShowSnackBar: (msg) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        // 搭配列表
                        if (state.outfitList.isEmpty)
                          _EmptyOutfitContent(
                            showFavoritesOnly: state.showFavoritesOnly,
                            hasSceneFilter: state.selectedSceneFilter.isNotEmpty,
                            onCreateOutfit: () => context.push('/outfits/create'),
                          )
                        else
                          ...state.outfitList.map(
                            (outfit) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _OutfitCard(
                                outfit: outfit,
                                allClothing: state.allClothing,
                                onFavoriteToggle: () =>
                                    controller.toggleFavorite(outfit),
                                onWear: () => controller.wearOutfit(outfit),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── AI 推荐区域 ──────────────────────────────────────────────────────────────

class _AiRecommendSection extends StatelessWidget {
  const _AiRecommendSection({
    required this.recommendState,
    required this.allClothing,
    required this.onRefresh,
    required this.onSaveOutfit,
    required this.onFeedback,
    required this.onNavigateToCloset,
    required this.onShowSnackBar,
  });

  final RecommendUiState recommendState;
  final List<ClothingModel> allClothing;
  final VoidCallback onRefresh;
  final Future<bool> Function(OutfitModel) onSaveOutfit;
  final Future<void> Function(String, String) onFeedback;
  final VoidCallback onNavigateToCloset;
  final ValueChanged<String> onShowSnackBar;

  @override
  Widget build(BuildContext context) {
    if (recommendState is RecommendUiEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '今日穿搭推荐',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (recommendState is RecommendUiSuccess)
                  Text(
                    () {
                      final w = (recommendState as RecommendUiSuccess).weather;
                      if (w == null) return '';
                      return '${w.weatherEmoji} ${w.temperature}°C ${w.cityName}';
                    }(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            switch (recommendState) {
              RecommendLoading() => Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI 正在为你生成今日穿搭推荐...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              RecommendUiSuccess(outfits: final outfits, weather: _) =>
                Column(
                  children: [
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: outfits.length,
                        separatorBuilder: (context, ignored) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          return _RecommendCard(
                            recommendedOutfit: outfits[index],
                            allClothing: allClothing,
                            onSave: () => onSaveOutfit(outfits[index].outfit),
                            onFeedback: (feedback) => onFeedback(
                              outfits[index].outfit.id,
                              feedback,
                            ),
                            onShowSnackBar: onShowSnackBar,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('换一套'),
                      ),
                    ),
                  ],
                ),
              RecommendUiInsufficient() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('👗', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '衣橱里的衣物还不够多',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '再添加几件，AI 就能为你生成个性化穿搭推荐了！',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onNavigateToCloset,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('去添加衣物'),
                      ),
                    ),
                  ],
                ),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }
}

// ─── 单个推荐卡片 ─────────────────────────────────────────────────────────────

class _RecommendCard extends StatefulWidget {
  const _RecommendCard({
    required this.recommendedOutfit,
    required this.allClothing,
    required this.onSave,
    required this.onFeedback,
    required this.onShowSnackBar,
  });

  final RecommendedOutfit recommendedOutfit;
  final List<ClothingModel> allClothing;
  final Future<bool> Function() onSave;
  final ValueChanged<String> onFeedback;
  final ValueChanged<String> onShowSnackBar;

  @override
  State<_RecommendCard> createState() => _RecommendCardState();
}

class _RecommendCardState extends State<_RecommendCard> {
  String _feedback = OutfitFeedback.none;
  bool _saved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _feedback = widget.recommendedOutfit.outfit.userFeedback;
  }

  @override
  Widget build(BuildContext context) {
    final outfit = widget.recommendedOutfit;
    final colorScheme = Theme.of(context).colorScheme;

    final items = [
      outfit.topItem,
      outfit.bottomItem,
      outfit.outerItem,
      outfit.shoesItem,
    ].whereType<ClothingModel>().take(4).toList();

    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                outfit.outfit.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 2x2 缩略图
              if (items.isNotEmpty)
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      ...items.map((c) => _ClothingThumb(clothing: c)),
                      if (items.length < 4)
                        ...List.generate(
                          4 - items.length,
                          (_) => Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      '✨',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
              if (outfit.outfit.aiReason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  outfit.outfit.aiReason,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (outfit.idleItems.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    outfit.idleItems.first,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 保存按钮：async await + SnackBar 反馈
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: _isSaving
                        ? Padding(
                            padding: const EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          )
                        : IconButton(
                            onPressed: _saved
                                ? null
                                : () async {
                                    setState(() => _isSaving = true);
                                    final success = await widget.onSave();
                                    if (!mounted) return;
                                    setState(() => _isSaving = false);
                                    if (success) {
                                      setState(() => _saved = true);
                                      widget.onShowSnackBar('✅ 搭配已保存到我的搭配列表');
                                    } else {
                                      widget.onShowSnackBar('❌ 保存失败，请重试');
                                    }
                                  },
                            icon: Icon(
                              _saved
                                  ? Icons.bookmark_added
                                  : Icons.bookmark_border,
                              size: 16,
                              color: _saved
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final newFeedback =
                              _feedback == OutfitFeedback.liked
                                  ? OutfitFeedback.none
                                  : OutfitFeedback.liked;
                          setState(() => _feedback = newFeedback);
                          widget.onFeedback(newFeedback);
                        },
                        child: Text(
                          '👍',
                          style: TextStyle(
                            fontSize: 16,
                            color: _feedback == OutfitFeedback.liked
                                ? null
                                : colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final newFeedback =
                              _feedback == OutfitFeedback.disliked
                                  ? OutfitFeedback.none
                                  : OutfitFeedback.disliked;
                          setState(() => _feedback = newFeedback);
                          widget.onFeedback(newFeedback);
                        },
                        child: Text(
                          '👎',
                          style: TextStyle(
                            fontSize: 16,
                            color: _feedback == OutfitFeedback.disliked
                                ? null
                                : colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClothingThumb extends StatelessWidget {
  const _ClothingThumb({required this.clothing});

  final ClothingModel clothing;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        clothing.imageUriList.isNotEmpty ? clothing.imageUriList.first : null;
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: colorScheme.primaryContainer,
        alignment: Alignment.center,
        child: imageUrl != null
            ? ClothingImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                fallbackIcon: Icons.checkroom,
                fallbackIconSize: 16,
              )
            : Text(
                _categoryEmoji(clothing.category),
                style: const TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  String _categoryEmoji(String category) {
    switch (category) {
      case '上衣':
      case 'T恤':
      case '衬衫':
      case '毛衣':
      case '卫衣':
        return '👕';
      case '裤子':
        return '👖';
      case '裙子':
      case '连衣裙':
        return '👗';
      case '外套':
      case '大衣':
      case '羽绒服':
        return '🧥';
      case '鞋子':
        return '👟';
      case '包包':
        return '👜';
      case '配饰':
        return '💍';
      default:
        return '👔';
    }
  }
}

// ─── 现有搭配卡片 ─────────────────────────────────────────────────────────────

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({
    required this.outfit,
    required this.allClothing,
    required this.onFavoriteToggle,
    required this.onWear,
  });

  final OutfitModel outfit;
  final List<ClothingModel> allClothing;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onWear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final clothingIds = [
      outfit.topId,
      outfit.bottomId,
      outfit.outerId,
      outfit.shoesId,
      outfit.bagId,
    ].where((id) => id.isNotEmpty).toList();

    final clothingItems = clothingIds
        .map((id) => allClothing.where((c) => c.id == id).firstOrNull)
        .whereType<ClothingModel>()
        .toList();

    final scenes = outfit.sceneTagList;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (outfit.isAiGenerated) ...[
                  Icon(Icons.auto_awesome, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    outfit.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onFavoriteToggle,
                  icon: Icon(
                    outfit.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: outfit.isFavorite
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            if (scenes.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                children: scenes.take(3).map((scene) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      scene,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (clothingItems.isNotEmpty) ...[
              Row(
                children: clothingItems.take(5).map((clothing) {
                  final imageUrl = clothing.imageUriList.isNotEmpty
                      ? clothing.imageUriList.first
                      : null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: colorScheme.primaryContainer,
                        alignment: Alignment.center,
                        child: imageUrl != null
                            ? ClothingImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                                fallbackIcon: Icons.checkroom,
                                fallbackIconSize: 20,
                              )
                            : Text(
                                _categoryEmoji(clothing.category),
                                style: const TextStyle(fontSize: 20),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            const Divider(height: 8),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  outfit.wearCount > 0 ? '已穿 ${outfit.wearCount} 次' : '还未穿过',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                FilledButton.tonal(
                  onPressed: onWear,
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 14),
                      SizedBox(width: 4),
                      Text('今天穿这套', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _categoryEmoji(String category) {
    switch (category) {
      case '上衣':
      case 'T恤':
      case '衬衫':
      case '毛衣':
      case '卫衣':
        return '👕';
      case '裤子':
        return '👖';
      case '裙子':
      case '连衣裙':
        return '👗';
      case '外套':
      case '大衣':
      case '羽绒服':
        return '🧥';
      case '鞋子':
        return '👟';
      case '包包':
        return '👜';
      case '配饰':
        return '💍';
      default:
        return '👔';
    }
  }
}

// ─── 空状态 ───────────────────────────────────────────────────────────────────

class _EmptyOutfitContent extends StatelessWidget {
  const _EmptyOutfitContent({
    required this.showFavoritesOnly,
    required this.hasSceneFilter,
    required this.onCreateOutfit,
  });

  final bool showFavoritesOnly;
  final bool hasSceneFilter;
  final VoidCallback onCreateOutfit;

  @override
  Widget build(BuildContext context) {
    final String emoji;
    final String title;
    final String subtitle;

    if (showFavoritesOnly) {
      emoji = '❤️';
      title = '还没有收藏的搭配';
      subtitle = '在搭配卡片上点击❤️收藏你喜欢的搭配';
    } else if (hasSceneFilter) {
      emoji = '🔍';
      title = '该场景下暂无搭配';
      subtitle = '试试切换其他场景标签';
    } else {
      emoji = '✨';
      title = '还没有搭配方案';
      subtitle = '先添加衣物，再来创建你的专属搭配';
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (!showFavoritesOnly && !hasSceneFilter) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateOutfit,
              icon: const Icon(Icons.add),
              label: const Text('创建搭配'),
            ),
          ],
        ],
      ),
    );
  }
}
