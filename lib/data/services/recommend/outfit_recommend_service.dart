import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/data/models/outfit_model.dart';
import 'package:closetmate/data/services/weather/weather_service.dart';
import 'package:uuid/uuid.dart';

class OutfitRecommendService {
  static const int minClothingForRecommend = 2;
  static const int maxRecommendations = 3;
  static const _uuid = Uuid();

  static RecommendState generateRecommendations({
    required List<ClothingModel> allClothing,
    WeatherInfo? weather,
    int count = maxRecommendations,
  }) {
    final availableClothing =
        allClothing.where((item) => item.status != ClothingStatus.disposed).toList();

    if (availableClothing.isEmpty) {
      return const RecommendEmptyCloset();
    }

    if (availableClothing.length < minClothingForRecommend) {
      return RecommendInsufficientClothing(availableClothing.length);
    }

    final temperature = weather?.temperature ?? 20;
    final now = DateTime.now().millisecondsSinceEpoch;

    final suitableClothing = _filterByTemperature(availableClothing, temperature);

    final sortedByIdle = [...suitableClothing]..sort((a, b) {
        final aDays = a.lastWornAt > 0
            ? ((now - a.lastWornAt) ~/ Duration.millisecondsPerDay)
            : 999999;
        final bDays = b.lastWornAt > 0
            ? ((now - b.lastWornAt) ~/ Duration.millisecondsPerDay)
            : 999999;
        return bDays.compareTo(aDays);
      });

    final tops = sortedByIdle.where((e) => _isTopCategory(e.category)).toList();
    final bottoms = sortedByIdle.where((e) => _isBottomCategory(e.category)).toList();
    final dresses = sortedByIdle.where((e) => e.category == ClothingCategory.dress).toList();
    final outers = sortedByIdle.where((e) => _isOuterCategory(e.category)).toList();
    final shoes = sortedByIdle.where((e) => e.category == ClothingCategory.shoes).toList();

    final recommendations = <RecommendedOutfit>[];
    final usedTopIds = <String>{};
    final usedBottomIds = <String>{};
    final usedDressIds = <String>{};

    final needOuter = temperature < WeatherService.tempCool;

    for (var index = 0; index < count; index++) {
      final outfit = _buildOutfit(
        index: index,
        tops: tops,
        bottoms: bottoms,
        dresses: dresses,
        outers: outers,
        shoes: shoes,
        usedTopIds: usedTopIds,
        usedBottomIds: usedBottomIds,
        usedDressIds: usedDressIds,
        needOuter: needOuter,
        now: now,
        temperature: temperature,
        weather: weather,
      );

      if (outfit != null) {
        recommendations.add(outfit);
      }
    }

    if (recommendations.isEmpty) {
      return RecommendInsufficientClothing(availableClothing.length);
    }

    return RecommendSuccess(recommendations);
  }

  static RecommendedOutfit? _buildOutfit({
    required int index,
    required List<ClothingModel> tops,
    required List<ClothingModel> bottoms,
    required List<ClothingModel> dresses,
    required List<ClothingModel> outers,
    required List<ClothingModel> shoes,
    required Set<String> usedTopIds,
    required Set<String> usedBottomIds,
    required Set<String> usedDressIds,
    required bool needOuter,
    required int now,
    required int temperature,
    required WeatherInfo? weather,
  }) {
    ClothingModel? topItem;
    ClothingModel? bottomItem;
    ClothingModel? outerItem;
    ClothingModel? shoesItem;

    final useDress = (index % 2 == 1) && dresses.isNotEmpty;

    if (useDress) {
      final dress = dresses.where((e) => !usedDressIds.contains(e.id)).cast<ClothingModel?>().firstWhere(
            (e) => e != null,
            orElse: () => null,
          );
      if (dress != null) {
        usedDressIds.add(dress.id);
        topItem = dress;
      }
    }

    if (topItem == null) {
      final top = tops.where((e) => !usedTopIds.contains(e.id)).cast<ClothingModel?>().firstWhere(
            (e) => e != null,
            orElse: () => null,
          );
      if (top != null) {
        usedTopIds.add(top.id);
        topItem = top;
      }
    }

    if (topItem?.category != ClothingCategory.dress) {
      final bottom = bottoms
          .where((e) => !usedBottomIds.contains(e.id))
          .cast<ClothingModel?>()
          .firstWhere((e) => e != null, orElse: () => null);
      if (bottom != null) {
        usedBottomIds.add(bottom.id);
        bottomItem = bottom;
      }
    }

    if (topItem == null) return null;
    if (topItem.category != ClothingCategory.dress && bottomItem == null) return null;

    if (needOuter && outers.isNotEmpty) {
      outerItem = outers.first;
    }

    if (shoes.isNotEmpty) {
      shoesItem = shoes.first;
    }

    final idleItems = <String>[];
    for (final item in [topItem, bottomItem, outerItem].whereType<ClothingModel>()) {
      if (item.lastWornAt > 0) {
        final days = (now - item.lastWornAt) ~/ Duration.millisecondsPerDay;
        if (days >= 30) {
          idleItems.add('${item.category}已 $days 天未穿');
        }
      } else if (item.wearCount == 0) {
        idleItems.add('${item.category}还未穿过');
      }
    }

    final reason = _buildReason(
      temperature: temperature,
      weather: weather,
      idleItems: idleItems,
    );

    final outfitName = _buildOutfitName(index + 1, temperature);

    final outfit = OutfitModel(
      id: _uuid.v4(),
      name: outfitName,
      topId: topItem.category != ClothingCategory.dress ? topItem.id : '',
      bottomId: bottomItem?.id ?? '',
      outerId: outerItem?.id ?? '',
      shoesId: shoesItem?.id ?? '',
      bagId: '',
      accessoryIds: '',
      sceneTags: _inferSceneTags(temperature),
      isFavorite: false,
      wearCount: 0,
      lastWornAt: 0,
      notes: '',
      isAiGenerated: true,
      aiReason: reason.length > 100 ? reason.substring(0, 100) : reason,
      userFeedback: OutfitFeedback.none,
    );

    return RecommendedOutfit(
      outfit: outfit,
      topItem: topItem.category != ClothingCategory.dress ? topItem : null,
      bottomItem: topItem.category == ClothingCategory.dress ? null : bottomItem,
      outerItem: outerItem,
      shoesItem: shoesItem,
      idleItems: idleItems,
    );
  }

  static String _buildReason({
    required int temperature,
    required WeatherInfo? weather,
    required List<String> idleItems,
  }) {
    final parts = <String>[];

    if (temperature < WeatherService.tempVeryCold) {
      parts.add('$temperature°C 寒冷天气，厚外套保暖');
    } else if (temperature < WeatherService.tempCool) {
      parts.add('$temperature°C 凉爽天气，薄外套刚好');
    } else if (temperature < WeatherService.tempWarm) {
      parts.add('$temperature°C 温暖天气，单衣舒适');
    } else {
      parts.add('$temperature°C 炎热天气，清凉穿搭');
    }

    if (idleItems.isNotEmpty) {
      parts.add(idleItems.first);
    }

    return parts.join('，');
  }

  static String _buildOutfitName(int index, int temperature) {
    final prefix = temperature < WeatherService.tempVeryCold
        ? '保暖'
        : temperature < WeatherService.tempCool
            ? '清爽'
            : temperature < WeatherService.tempWarm
                ? '舒适'
                : '清凉';
    return 'AI推荐 · $prefix搭配 $index';
  }

  static String _inferSceneTags(int temperature) {
    if (temperature < WeatherService.tempVeryCold) return '休闲,通勤';
    if (temperature < WeatherService.tempCool) return '休闲,通勤';
    if (temperature < WeatherService.tempWarm) return '休闲,约会';
    return '休闲,度假';
  }

  static List<ClothingModel> _filterByTemperature(
    List<ClothingModel> clothing,
    int temperature,
  ) {
    final filtered = clothing.where((item) {
      final category = item.category;

      if (temperature < WeatherService.tempVeryCold) {
        return _isTopCategory(category) ||
            _isOuterCategory(category) ||
            _isBottomCategory(category) ||
            {
              ClothingCategory.shoes,
              ClothingCategory.bag,
              ClothingCategory.accessory,
            }.contains(category) ||
            (category == ClothingCategory.dress &&
                (item.seasons.contains('冬') || item.seasons.contains('四季')));
      }

      if (temperature < WeatherService.tempCool) {
        if (category == ClothingCategory.dress || category == ClothingCategory.skirt) {
          return !item.seasons.contains('夏') ||
              item.seasons.contains('春') ||
              item.seasons.contains('四季');
        }
        return true;
      }

      if (temperature < WeatherService.tempWarm) {
        return category != ClothingCategory.downJacket &&
            category != ClothingCategory.coat;
      }

      return category != ClothingCategory.downJacket &&
          category != ClothingCategory.coat &&
          category != ClothingCategory.sweater;
    }).toList();

    return filtered.isEmpty ? clothing : filtered;
  }

  static bool _isTopCategory(String category) {
    return {
      ClothingCategory.top,
      ClothingCategory.tShirt,
      ClothingCategory.shirt,
      ClothingCategory.sweater,
      ClothingCategory.hoodie,
      ClothingCategory.sportswear,
      ClothingCategory.underwear,
    }.contains(category);
  }

  static bool _isBottomCategory(String category) {
    return {
      ClothingCategory.pants,
      ClothingCategory.skirt,
    }.contains(category);
  }

  static bool _isOuterCategory(String category) {
    return {
      ClothingCategory.jacket,
      ClothingCategory.coat,
      ClothingCategory.downJacket,
    }.contains(category);
  }

  /// 核心单品搭配：以 [coreItem] 为核心，生成 [count] 套必须包含该单品的搭配方案。
  static RecommendState generateForCoreItem({
    required ClothingModel coreItem,
    required List<ClothingModel> allClothing,
    int count = 3,
  }) {
    final available = allClothing
        .where((c) => c.status != ClothingStatus.disposed && c.id != coreItem.id)
        .toList();

    if (available.isEmpty) {
      return RecommendInsufficientClothing(1);
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // 按闲置时间排序（优先推荐闲置久的）
    final sorted = [...available]..sort((a, b) {
        final aDays = a.lastWornAt > 0
            ? ((now - a.lastWornAt) ~/ Duration.millisecondsPerDay)
            : 999999;
        final bDays = b.lastWornAt > 0
            ? ((now - b.lastWornAt) ~/ Duration.millisecondsPerDay)
            : 999999;
        return bDays.compareTo(aDays);
      });

    final tops = sorted.where((e) => _isTopCategory(e.category)).toList();
    final bottoms = sorted.where((e) => _isBottomCategory(e.category)).toList();
    final dresses = sorted.where((e) => e.category == ClothingCategory.dress).toList();
    final outers = sorted.where((e) => _isOuterCategory(e.category)).toList();
    final shoes = sorted.where((e) => e.category == ClothingCategory.shoes).toList();

    final coreCategory = coreItem.category;
    final isCoreTop = _isTopCategory(coreCategory);
    final isCoreBottom = _isBottomCategory(coreCategory);
    final isCoreOuter = _isOuterCategory(coreCategory);
    final isCoreDress = coreCategory == ClothingCategory.dress;
    final isCoreShoes = coreCategory == ClothingCategory.shoes;

    final recommendations = <RecommendedOutfit>[];
    final usedCombinationKeys = <String>{};

    for (var i = 0; i < count * 3 && recommendations.length < count; i++) {
      ClothingModel? topItem;
      ClothingModel? bottomItem;
      ClothingModel? outerItem;
      ClothingModel? shoesItem;

      // 根据核心单品的品类，决定其他槽位如何填充
      if (isCoreTop || isCoreDress) {
        topItem = coreItem;
        if (!isCoreDress) {
          // 需要下装
          final idx = i % bottoms.length.clamp(1, 999);
          bottomItem = bottoms.isNotEmpty ? bottoms[idx % bottoms.length] : null;
        }
        if (outers.isNotEmpty && i % 2 == 0) {
          outerItem = outers[i % outers.length];
        }
        shoesItem = shoes.isNotEmpty ? shoes[i % shoes.length] : null;
      } else if (isCoreBottom) {
        bottomItem = coreItem;
        final idx = i % tops.length.clamp(1, 999);
        topItem = tops.isNotEmpty ? tops[idx % tops.length] : null;
        if (outers.isNotEmpty && i % 2 == 0) {
          outerItem = outers[i % outers.length];
        }
        shoesItem = shoes.isNotEmpty ? shoes[i % shoes.length] : null;
      } else if (isCoreOuter) {
        outerItem = coreItem;
        final topIdx = i % tops.length.clamp(1, 999);
        topItem = tops.isNotEmpty ? tops[topIdx % tops.length] : null;
        final botIdx = i % bottoms.length.clamp(1, 999);
        bottomItem = bottoms.isNotEmpty ? bottoms[botIdx % bottoms.length] : null;
        shoesItem = shoes.isNotEmpty ? shoes[i % shoes.length] : null;
      } else if (isCoreShoes) {
        shoesItem = coreItem;
        final topIdx = i % tops.length.clamp(1, 999);
        topItem = tops.isNotEmpty ? tops[topIdx % tops.length] : null;
        final botIdx = i % bottoms.length.clamp(1, 999);
        bottomItem = bottoms.isNotEmpty ? bottoms[botIdx % bottoms.length] : null;
        if (outers.isNotEmpty && i % 2 == 0) {
          outerItem = outers[i % outers.length];
        }
      } else {
        // 包包/配饰：作为配件，搭配一套完整穿搭
        topItem = tops.isNotEmpty ? tops[i % tops.length] : null;
        bottomItem = bottoms.isNotEmpty ? bottoms[i % bottoms.length] : null;
        shoesItem = shoes.isNotEmpty ? shoes[i % shoes.length] : null;
      }

      // 必须有上衣（或连衣裙）
      if (topItem == null && !isCoreDress) continue;
      // 非连衣裙必须有下装
      if (!isCoreDress && bottomItem == null && !isCoreOuter) continue;

      // 去重：同一组合不重复推荐
      final key = [
        topItem?.id ?? '',
        bottomItem?.id ?? '',
        outerItem?.id ?? '',
        shoesItem?.id ?? '',
      ].join('|');
      if (usedCombinationKeys.contains(key)) continue;
      usedCombinationKeys.add(key);

      final idleItems = <String>[];
      for (final item in [topItem, bottomItem, outerItem].whereType<ClothingModel>()) {
        if (item.id == coreItem.id) continue;
        if (item.lastWornAt > 0) {
          final days = (now - item.lastWornAt) ~/ Duration.millisecondsPerDay;
          if (days >= 30) idleItems.add('${item.category}已 $days 天未穿');
        } else if (item.wearCount == 0) {
          idleItems.add('${item.category}还未穿过');
        }
      }

      final reason = '以${coreItem.category}为核心单品搭配'
          '${idleItems.isNotEmpty ? "，${idleItems.first}" : ""}';

      final outfit = OutfitModel(
        id: _uuid.v4(),
        name: 'AI搭配 · 方案 ${recommendations.length + 1}',
        topId: (topItem != null && topItem.category != ClothingCategory.dress)
            ? topItem.id
            : '',
        bottomId: bottomItem?.id ?? '',
        outerId: outerItem?.id ?? '',
        shoesId: shoesItem?.id ?? '',
        bagId: '',
        accessoryIds: '',
        sceneTags: '休闲,通勤',
        isFavorite: false,
        wearCount: 0,
        lastWornAt: 0,
        notes: '',
        isAiGenerated: true,
        aiReason: reason.length > 100 ? reason.substring(0, 100) : reason,
        userFeedback: OutfitFeedback.none,
      );

      recommendations.add(RecommendedOutfit(
        outfit: outfit,
        topItem: (topItem?.category != ClothingCategory.dress) ? topItem : null,
        bottomItem: isCoreDress ? null : bottomItem,
        outerItem: outerItem,
        shoesItem: shoesItem,
        idleItems: idleItems,
        coreItem: coreItem,
      ));
    }

    if (recommendations.isEmpty) {
      return RecommendInsufficientClothing(available.length + 1);
    }

    return RecommendSuccess(recommendations);
  }

  static int getIdleDays(ClothingModel clothing) {
    if (clothing.lastWornAt == 0) return -1;
    return (DateTime.now().millisecondsSinceEpoch - clothing.lastWornAt) ~/
        Duration.millisecondsPerDay;
  }
}

sealed class RecommendState {
  const RecommendState();
}

class RecommendSuccess extends RecommendState {
  const RecommendSuccess(this.outfits);

  final List<RecommendedOutfit> outfits;
}

class RecommendInsufficientClothing extends RecommendState {
  const RecommendInsufficientClothing(this.clothingCount);

  final int clothingCount;
}

class RecommendEmptyCloset extends RecommendState {
  const RecommendEmptyCloset();
}

class RecommendedOutfit {
  const RecommendedOutfit({
    required this.outfit,
    required this.topItem,
    required this.bottomItem,
    required this.outerItem,
    required this.shoesItem,
    required this.idleItems,
    this.coreItem,
  });

  final OutfitModel outfit;
  final ClothingModel? topItem;
  final ClothingModel? bottomItem;
  final ClothingModel? outerItem;
  final ClothingModel? shoesItem;
  final List<String> idleItems;
  /// 核心单品（仅在"核心单品搭配"模式下有值）
  final ClothingModel? coreItem;
}
