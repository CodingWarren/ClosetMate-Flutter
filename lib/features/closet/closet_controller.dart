import 'dart:async';

import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/data/repositories/clothing_repository.dart';
import 'package:closetmate/data/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final closetControllerProvider =
    StateNotifierProvider<ClosetController, ClosetState>((ref) {
  final repository = ref.watch(clothingRepositoryProvider);
  return ClosetController(repository)..loadClothing();
});

class FilterState {
  const FilterState({
    this.selectedCategories = const <String>{},
    this.selectedSeasons = const <String>{},
    this.selectedStyles = const <String>{},
    this.selectedStatuses = const <String>{},
  });

  final Set<String> selectedCategories;
  final Set<String> selectedSeasons;
  final Set<String> selectedStyles;
  final Set<String> selectedStatuses;

  bool get isActive =>
      selectedCategories.isNotEmpty ||
      selectedSeasons.isNotEmpty ||
      selectedStyles.isNotEmpty ||
      selectedStatuses.isNotEmpty;

  FilterState copyWith({
    Set<String>? selectedCategories,
    Set<String>? selectedSeasons,
    Set<String>? selectedStyles,
    Set<String>? selectedStatuses,
  }) {
    return FilterState(
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedSeasons: selectedSeasons ?? this.selectedSeasons,
      selectedStyles: selectedStyles ?? this.selectedStyles,
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
    );
  }
}

class ClosetState {
  const ClosetState({
    this.isLoading = false,
    this.isSearchActive = false,
    this.searchQuery = '',
    this.gridColumns = 2,
    this.filterState = const FilterState(),
    this.allClothing = const <ClothingModel>[],
    this.clothingList = const <ClothingModel>[],
  });

  final bool isLoading;
  final bool isSearchActive;
  final String searchQuery;
  final int gridColumns;
  final FilterState filterState;
  final List<ClothingModel> allClothing;
  final List<ClothingModel> clothingList;

  ClosetState copyWith({
    bool? isLoading,
    bool? isSearchActive,
    String? searchQuery,
    int? gridColumns,
    FilterState? filterState,
    List<ClothingModel>? allClothing,
    List<ClothingModel>? clothingList,
  }) {
    return ClosetState(
      isLoading: isLoading ?? this.isLoading,
      isSearchActive: isSearchActive ?? this.isSearchActive,
      searchQuery: searchQuery ?? this.searchQuery,
      gridColumns: gridColumns ?? this.gridColumns,
      filterState: filterState ?? this.filterState,
      allClothing: allClothing ?? this.allClothing,
      clothingList: clothingList ?? this.clothingList,
    );
  }
}

class ClosetController extends StateNotifier<ClosetState> {
  ClosetController(this._repository) : super(const ClosetState());

  final ClothingRepository _repository;

  Future<void> loadClothing() async {
    state = state.copyWith(isLoading: true);
    final allItems = await _repository.getAllClothing();
    final filtered = _applyFilter(
      items: allItems,
      query: state.searchQuery,
      filter: state.filterState,
    );
    state = state.copyWith(
      isLoading: false,
      allClothing: allItems,
      clothingList: filtered,
    );
  }

  void setSearchActive(bool active) {
    state = state.copyWith(isSearchActive: active);
    if (!active && state.searchQuery.isNotEmpty) {
      setSearchQuery('');
    }
  }

  void setSearchQuery(String query) {
    final filtered = _applyFilter(
      items: state.allClothing,
      query: query,
      filter: state.filterState,
    );
    state = state.copyWith(
      searchQuery: query,
      clothingList: filtered,
    );
  }

  void updateFilter(FilterState filter) {
    final filtered = _applyFilter(
      items: state.allClothing,
      query: state.searchQuery,
      filter: filter,
    );
    state = state.copyWith(
      filterState: filter,
      clothingList: filtered,
    );
  }

  void clearFilter() {
    final cleared = const FilterState();
    final filtered = _applyFilter(
      items: state.allClothing,
      query: state.searchQuery,
      filter: cleared,
    );
    state = state.copyWith(
      filterState: cleared,
      clothingList: filtered,
    );
  }

  void toggleGridColumns() {
    state = state.copyWith(
      gridColumns: state.gridColumns == 2 ? 3 : 2,
    );
  }

  List<ClothingModel> _applyFilter({
    required List<ClothingModel> items,
    required String query,
    required FilterState filter,
  }) {
    return items.where((item) {
      final matchesQuery = query.trim().isEmpty ||
          item.category.contains(query) ||
          item.brand.contains(query) ||
          item.notes.contains(query) ||
          item.storageLocation.contains(query) ||
          item.colors.contains(query) ||
          item.styles.contains(query);

      final matchesCategory = filter.selectedCategories.isEmpty ||
          filter.selectedCategories.contains(item.category);

      final matchesSeason = filter.selectedSeasons.isEmpty ||
          filter.selectedSeasons.any((season) => item.seasons.contains(season));

      final matchesStyle = filter.selectedStyles.isEmpty ||
          filter.selectedStyles.any((style) => item.styles.contains(style));

      final matchesStatus = filter.selectedStatuses.isEmpty ||
          filter.selectedStatuses.contains(item.status);

      return matchesQuery &&
          matchesCategory &&
          matchesSeason &&
          matchesStyle &&
          matchesStatus;
    }).toList();
  }
}
