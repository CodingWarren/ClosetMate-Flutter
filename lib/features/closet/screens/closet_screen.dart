import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/features/closet/closet_controller.dart';
import 'package:closetmate/features/closet/widgets/filter_bottom_sheet.dart';
import 'package:closetmate/shared/widgets/clothing_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClosetScreen extends ConsumerWidget {
  const ClosetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(closetControllerProvider);
    final controller = ref.read(closetControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: state.isSearchActive
          ? AppBar(
              leading: IconButton(
                onPressed: () => controller.setSearchActive(false),
                icon: const Icon(Icons.arrow_back),
              ),
              title: TextField(
                autofocus: true,
                onChanged: controller.setSearchQuery,
                decoration: const InputDecoration(
                  hintText: '搜索品牌、备注、位置...',
                  border: InputBorder.none,
                ),
              ),
            )
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '我的衣橱',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (!state.isLoading && state.clothingList.isNotEmpty)
                    Text(
                      '${state.clothingList.length} 件',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () => controller.setSearchActive(true),
                  icon: const Icon(Icons.search),
                ),
                Badge(
                  isLabelVisible: state.filterState.isActive,
                  child: IconButton(
                    onPressed: () => showFilterBottomSheet(
                      context: context,
                      currentFilter: state.filterState,
                      onFilterChange: controller.updateFilter,
                    ),
                    icon: const Icon(Icons.filter_list),
                  ),
                ),
                IconButton(
                  onPressed: controller.toggleGridColumns,
                  icon: Icon(
                    state.gridColumns == 2 ? Icons.grid_view_outlined : Icons.view_module,
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await context.push<bool>('/clothing/add');
          if (added == true && context.mounted) {
            ref.read(closetControllerProvider.notifier).loadClothing();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.clothingList.isEmpty) {
            return _EmptyClosetContent(
              isFiltered: state.filterState.isActive || state.searchQuery.trim().isNotEmpty,
              onAddClothing: () async {
                final added = await context.push<bool>('/clothing/add');
                if (added == true && context.mounted) {
                  ref.read(closetControllerProvider.notifier).loadClothing();
                }
              },
              onClearFilter: () {
                controller.clearFilter();
                controller.setSearchActive(false);
              },
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadClothing,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: state.gridColumns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: state.gridColumns == 2 ? 0.72 : 0.62,
              ),
              itemCount: state.clothingList.length,
              itemBuilder: (context, index) {
                final clothing = state.clothingList[index];
                return _ClothingCard(clothing: clothing);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ClothingCard extends ConsumerWidget {
  const _ClothingCard({required this.clothing});

  final ClothingModel clothing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = clothing.imageUriList.isNotEmpty ? clothing.imageUriList.first : null;
    final colorScheme = Theme.of(context).colorScheme;

    // 调试：打印图片信息
    if (imageUrl != null) {
      print('ClothingCard: id=${clothing.id}, imageUrl=$imageUrl, imageUriList=${clothing.imageUriList}');
    } else {
      print('ClothingCard: id=${clothing.id}, no image');
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final deleted = await context.push<bool>('/clothing/${clothing.id}');
          if (deleted == true && context.mounted) {
            ref.read(closetControllerProvider.notifier).loadClothing();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: colorScheme.surfaceContainerHighest,
                child: imageUrl == null
                    ? Icon(
                        Icons.checkroom,
                        size: 42,
                        color: colorScheme.primary,
                      )
                    : ClothingImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.image_not_supported_outlined,
                        fallbackIconSize: 36,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clothing.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  if (clothing.brand.isNotEmpty)
                    Text(
                      clothing.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (clothing.colorList.isNotEmpty)
                        _MetaChip(label: clothing.colorList.first),
                      if (clothing.styleList.isNotEmpty)
                        _MetaChip(label: clothing.styleList.first),
                      _MetaChip(label: clothing.status),
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
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _EmptyClosetContent extends StatelessWidget {
  const _EmptyClosetContent({
    required this.isFiltered,
    required this.onAddClothing,
    required this.onClearFilter,
  });

  final bool isFiltered;
  final VoidCallback onAddClothing;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isFiltered ? '🔍' : '👗',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? '没有找到匹配的衣物' : '衣橱还是空的',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered ? '试试调整筛选条件或搜索关键词' : '点击右下角 + 开始添加你的第一件衣物',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            if (isFiltered)
              OutlinedButton(
                onPressed: onClearFilter,
                child: const Text('清除筛选'),
              )
            else
              FilledButton.icon(
                onPressed: onAddClothing,
                icon: const Icon(Icons.add),
                label: const Text('添加衣物'),
              ),
          ],
        ),
      ),
    );
  }
}
