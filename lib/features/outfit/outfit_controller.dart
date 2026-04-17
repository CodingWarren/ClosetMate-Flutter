import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/data/models/outfit_model.dart';
import 'package:closetmate/data/repositories/clothing_repository.dart';
import 'package:closetmate/data/repositories/outfit_repository.dart';
import 'package:closetmate/data/repositories/repository_providers.dart';
import 'package:closetmate/data/services/recommend/outfit_recommend_service.dart';
import 'package:closetmate/data/services/weather/qweather_service.dart';
import 'package:closetmate/data/services/weather/weather_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final outfitControllerProvider =
    StateNotifierProvider<OutfitController, OutfitState>((ref) {
  final outfitRepo = ref.watch(outfitRepositoryProvider);
  final clothingRepo = ref.watch(clothingRepositoryProvider);
  return OutfitController(outfitRepo, clothingRepo)..init();
});

// ─── State ────────────────────────────────────────────────────────────────────

class OutfitState {
  const OutfitState({
    this.isLoading = false,
    this.outfitList = const <OutfitModel>[],
    this.allClothing = const <ClothingModel>[],
    this.showFavoritesOnly = false,
    this.selectedSceneFilter = '',
    this.recommendState = const RecommendIdle(),
  });

  final bool isLoading;
  final List<OutfitModel> outfitList;
  final List<ClothingModel> allClothing;
  final bool showFavoritesOnly;
  final String selectedSceneFilter;
  final RecommendUiState recommendState;

  OutfitState copyWith({
    bool? isLoading,
    List<OutfitModel>? outfitList,
    List<ClothingModel>? allClothing,
    bool? showFavoritesOnly,
    String? selectedSceneFilter,
    RecommendUiState? recommendState,
  }) {
    return OutfitState(
      isLoading: isLoading ?? this.isLoading,
      outfitList: outfitList ?? this.outfitList,
      allClothing: allClothing ?? this.allClothing,
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      selectedSceneFilter: selectedSceneFilter ?? this.selectedSceneFilter,
      recommendState: recommendState ?? this.recommendState,
    );
  }
}

// ─── Recommend UI State ───────────────────────────────────────────────────────

sealed class RecommendUiState {
  const RecommendUiState();
}

class RecommendIdle extends RecommendUiState {
  const RecommendIdle();
}

class RecommendLoading extends RecommendUiState {
  const RecommendLoading();
}

class RecommendUiSuccess extends RecommendUiState {
  const RecommendUiSuccess({
    required this.outfits,
    this.weather,
  });

  final List<RecommendedOutfit> outfits;
  final WeatherInfo? weather;
}

class RecommendUiInsufficient extends RecommendUiState {
  const RecommendUiInsufficient(this.clothingCount);

  final int clothingCount;
}

class RecommendUiEmpty extends RecommendUiState {
  const RecommendUiEmpty();
}

// ─── Controller ───────────────────────────────────────────────────────────────

class OutfitController extends StateNotifier<OutfitState> {
  OutfitController(this._outfitRepo, this._clothingRepo)
      : super(const OutfitState());

  final OutfitRepository _outfitRepo;
  final ClothingRepository _clothingRepo;

  // 模拟天气（后续接入真实 API）
  WeatherInfo? _currentWeather;

  Future<void> init() async {
    await _loadClothing();
    await _loadOutfits();
    await loadRecommendations();
  }

  Future<void> _loadClothing() async {
    final clothing = await _clothingRepo.getAllClothing();
    state = state.copyWith(allClothing: clothing);
  }

  Future<void> _loadOutfits() async {
    state = state.copyWith(isLoading: true);
    final all = await _outfitRepo.getAllOutfits();
    final filtered = _applyFilter(all);
    state = state.copyWith(isLoading: false, outfitList: filtered);
  }

  Future<void> loadRecommendations() async {
    if (state.allClothing.isEmpty) {
      state = state.copyWith(recommendState: const RecommendUiEmpty());
      return;
    }

    state = state.copyWith(recommendState: const RecommendLoading());

    // 尝试获取真实天气；失败时降级为 Mock 数据
    final weatherResult = await QWeatherService.getWeatherByCity();
    if (weatherResult is WeatherSuccess) {
      _currentWeather = weatherResult.weather;
    } else {
      // 降级：使用 20°C 晴天 Mock
      _currentWeather = const WeatherInfo(
        temperature: 20,
        feelsLike: 20,
        description: '晴',
        icon: '100',
        cityName: '北京',
        windSpeed: '3',
        humidity: '40',
      );
    }

    final result = OutfitRecommendService.generateRecommendations(
      allClothing: state.allClothing,
      weather: _currentWeather,
    );

    final newState = switch (result) {
      RecommendSuccess(outfits: final outfits) => RecommendUiSuccess(
          outfits: outfits,
          weather: _currentWeather,
        ),
      RecommendInsufficientClothing(clothingCount: final count) =>
        RecommendUiInsufficient(count),
      RecommendEmptyCloset() => const RecommendUiEmpty(),
    };

    state = state.copyWith(recommendState: newState);
  }

  Future<void> refreshRecommendations() async {
    await _loadClothing();
    await loadRecommendations();
  }

  /// 保存 AI 推荐的搭配到数据库，返回是否成功
  Future<bool> saveRecommendedOutfit(OutfitModel outfit) async {
    try {
      await _outfitRepo.insertOutfit(outfit);
      await _loadOutfits();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> submitFeedback(String outfitId, String feedback) async {
    final outfit = await _outfitRepo.getOutfitById(outfitId);
    if (outfit == null) return;
    await _outfitRepo.updateOutfit(outfit.copyWith(userFeedback: feedback));
  }

  Future<void> toggleFavorite(OutfitModel outfit) async {
    await _outfitRepo.updateOutfit(
      outfit.copyWith(isFavorite: !outfit.isFavorite),
    );
    await _loadOutfits();
  }

  /// 检查今天是否已经记录过穿着
  bool _isWornToday(int lastWornAt) {
    if (lastWornAt == 0) return false;
    final last = DateTime.fromMillisecondsSinceEpoch(lastWornAt);
    final today = DateTime.now();
    return last.year == today.year &&
        last.month == today.month &&
        last.day == today.day;
  }

  /// 记录穿着：搭配穿着次数 +1，同时给搭配内所有单品穿着次数 +1
  /// 返回值：1=成功，0=今日已记录，-1=失败
  Future<int> wearOutfit(OutfitModel outfit) async {
    // 今天已经记录过，不重复计数
    if (_isWornToday(outfit.lastWornAt)) return 0;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 1. 更新搭配本身
      await _outfitRepo.updateOutfit(
        outfit.copyWith(
          wearCount: outfit.wearCount + 1,
          lastWornAt: now,
          updatedAt: now,
        ),
      );

      // 2. 同步更新搭配内所有单品的穿着次数
      final clothingIds = [
        outfit.topId,
        outfit.bottomId,
        outfit.outerId,
        outfit.shoesId,
        outfit.bagId,
        ...outfit.accessoryIds.split(',').where((id) => id.isNotEmpty),
      ].where((id) => id.isNotEmpty).toList();

      for (final id in clothingIds) {
        final clothing = await _clothingRepo.getClothingById(id);
        if (clothing != null) {
          await _clothingRepo.updateClothing(
            clothing.copyWith(
              wearCount: clothing.wearCount + 1,
              lastWornAt: now,
              updatedAt: now,
            ),
          );
        }
      }

      await _loadOutfits();
      return 1;
    } catch (e) {
      return -1;
    }
  }

  Future<void> deleteOutfit(String id) async {
    await _outfitRepo.deleteOutfit(id);
    await _loadOutfits();
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(showFavoritesOnly: !state.showFavoritesOnly);
    _applyAndUpdate();
  }

  void setSceneFilter(String scene) {
    state = state.copyWith(selectedSceneFilter: scene);
    _applyAndUpdate();
  }

  Future<void> _applyAndUpdate() async {
    final all = await _outfitRepo.getAllOutfits();
    final filtered = _applyFilter(all);
    state = state.copyWith(outfitList: filtered);
  }

  List<OutfitModel> _applyFilter(List<OutfitModel> all) {
    return all.where((outfit) {
      final matchesFavorite = !state.showFavoritesOnly || outfit.isFavorite;
      final matchesScene = state.selectedSceneFilter.isEmpty ||
          outfit.sceneTags.contains(state.selectedSceneFilter);
      return matchesFavorite && matchesScene;
    }).toList();
  }
}
