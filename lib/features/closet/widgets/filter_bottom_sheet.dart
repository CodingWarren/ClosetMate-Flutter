import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/features/closet/closet_controller.dart';
import 'package:flutter/material.dart';

Future<void> showFilterBottomSheet({
  required BuildContext context,
  required FilterState currentFilter,
  required ValueChanged<FilterState> onFilterChange,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _FilterBottomSheet(
        currentFilter: currentFilter,
        onFilterChange: onFilterChange,
      );
    },
  );
}

class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({
    required this.currentFilter,
    required this.onFilterChange,
  });

  final FilterState currentFilter;
  final ValueChanged<FilterState> onFilterChange;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late FilterState tempFilter;

  @override
  void initState() {
    super.initState();
    tempFilter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    final count = tempFilter.selectedCategories.length +
        tempFilter.selectedSeasons.length +
        tempFilter.selectedStyles.length +
        tempFilter.selectedStatuses.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '筛选',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FilterSection(
                title: '品类',
                options: ClothingCategory.all,
                selected: tempFilter.selectedCategories,
                onSelectionChange: (value) {
                  setState(() {
                    tempFilter = tempFilter.copyWith(selectedCategories: value);
                  });
                },
              ),
              const SizedBox(height: 16),
              _FilterSection(
                title: '季节',
                options: ClothingSeason.all,
                selected: tempFilter.selectedSeasons,
                onSelectionChange: (value) {
                  setState(() {
                    tempFilter = tempFilter.copyWith(selectedSeasons: value);
                  });
                },
              ),
              const SizedBox(height: 16),
              _FilterSection(
                title: '风格',
                options: ClothingStyle.all,
                selected: tempFilter.selectedStyles,
                onSelectionChange: (value) {
                  setState(() {
                    tempFilter = tempFilter.copyWith(selectedStyles: value);
                  });
                },
              ),
              const SizedBox(height: 16),
              _FilterSection(
                title: '状态',
                options: ClothingStatus.all,
                selected: tempFilter.selectedStatuses,
                onSelectionChange: (value) {
                  setState(() {
                    tempFilter = tempFilter.copyWith(selectedStatuses: value);
                  });
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        const cleared = FilterState();
                        widget.onFilterChange(cleared);
                        Navigator.of(context).pop();
                      },
                      child: const Text('重置'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        widget.onFilterChange(tempFilter);
                        Navigator.of(context).pop();
                      },
                      child: Text(count > 0 ? '应用筛选（$count）' : '应用筛选'),
                    ),
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

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelectionChange,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onSelectionChange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              selected: isSelected,
              label: Text(option),
              onSelected: (_) {
                final newSet = isSelected
                    ? (Set<String>.from(selected)..remove(option))
                    : (Set<String>.from(selected)..add(option));
                onSelectionChange(newSet);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
