import 'package:closetmate/data/repositories/clothing_repository.dart';
import 'package:closetmate/data/repositories/outfit_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clothingRepositoryProvider = Provider<ClothingRepository>((ref) {
  return ClothingRepository();
});

final outfitRepositoryProvider = Provider<OutfitRepository>((ref) {
  return OutfitRepository();
});
