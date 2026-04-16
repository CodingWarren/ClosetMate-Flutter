class OutfitModel {
  const OutfitModel({
    required this.id,
    required this.name,
    this.topId = '',
    this.bottomId = '',
    this.outerId = '',
    this.shoesId = '',
    this.bagId = '',
    this.accessoryIds = '',
    this.sceneTags = '',
    this.isFavorite = false,
    this.wearCount = 0,
    this.lastWornAt = 0,
    this.notes = '',
    this.ownerId = 'default',
    this.createdAt = 0,
    this.updatedAt = 0,
    this.userFeedback = OutfitFeedback.none,
    this.isAiGenerated = false,
    this.aiReason = '',
  });

  final String id;
  final String name;
  final String topId;
  final String bottomId;
  final String outerId;
  final String shoesId;
  final String bagId;
  final String accessoryIds;
  final String sceneTags;
  final bool isFavorite;
  final int wearCount;
  final int lastWornAt;
  final String notes;
  final String ownerId;
  final int createdAt;
  final int updatedAt;
  final String userFeedback;
  final bool isAiGenerated;
  final String aiReason;

  List<String> get accessoryIdList => accessoryIds.isEmpty
      ? []
      : accessoryIds.split(',').where((e) => e.isNotEmpty).toList();

  List<String> get sceneTagList =>
      sceneTags.isEmpty ? [] : sceneTags.split(',').where((e) => e.isNotEmpty).toList();

  OutfitModel copyWith({
    String? id,
    String? name,
    String? topId,
    String? bottomId,
    String? outerId,
    String? shoesId,
    String? bagId,
    String? accessoryIds,
    String? sceneTags,
    bool? isFavorite,
    int? wearCount,
    int? lastWornAt,
    String? notes,
    String? ownerId,
    int? createdAt,
    int? updatedAt,
    String? userFeedback,
    bool? isAiGenerated,
    String? aiReason,
  }) {
    return OutfitModel(
      id: id ?? this.id,
      name: name ?? this.name,
      topId: topId ?? this.topId,
      bottomId: bottomId ?? this.bottomId,
      outerId: outerId ?? this.outerId,
      shoesId: shoesId ?? this.shoesId,
      bagId: bagId ?? this.bagId,
      accessoryIds: accessoryIds ?? this.accessoryIds,
      sceneTags: sceneTags ?? this.sceneTags,
      isFavorite: isFavorite ?? this.isFavorite,
      wearCount: wearCount ?? this.wearCount,
      lastWornAt: lastWornAt ?? this.lastWornAt,
      notes: notes ?? this.notes,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userFeedback: userFeedback ?? this.userFeedback,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      aiReason: aiReason ?? this.aiReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'topId': topId,
      'bottomId': bottomId,
      'outerId': outerId,
      'shoesId': shoesId,
      'bagId': bagId,
      'accessoryIds': accessoryIds,
      'sceneTags': sceneTags,
      'isFavorite': isFavorite ? 1 : 0,
      'wearCount': wearCount,
      'lastWornAt': lastWornAt,
      'notes': notes,
      'ownerId': ownerId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'userFeedback': userFeedback,
      'isAiGenerated': isAiGenerated ? 1 : 0,
      'aiReason': aiReason,
    };
  }

  factory OutfitModel.fromMap(Map<String, dynamic> map) {
    return OutfitModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      topId: map['topId'] as String? ?? '',
      bottomId: map['bottomId'] as String? ?? '',
      outerId: map['outerId'] as String? ?? '',
      shoesId: map['shoesId'] as String? ?? '',
      bagId: map['bagId'] as String? ?? '',
      accessoryIds: map['accessoryIds'] as String? ?? '',
      sceneTags: map['sceneTags'] as String? ?? '',
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
      wearCount: map['wearCount'] as int? ?? 0,
      lastWornAt: map['lastWornAt'] as int? ?? 0,
      notes: map['notes'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? 'default',
      createdAt: map['createdAt'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int? ?? 0,
      userFeedback: map['userFeedback'] as String? ?? OutfitFeedback.none,
      isAiGenerated: (map['isAiGenerated'] as int? ?? 0) == 1,
      aiReason: map['aiReason'] as String? ?? '',
    );
  }
}

class OutfitFeedback {
  static const String liked = 'LIKED';
  static const String disliked = 'DISLIKED';
  static const String none = 'NONE';
}

class OutfitScene {
  static const String commute = '通勤';
  static const String date = '约会';
  static const String sport = '运动';
  static const String casual = '休闲';
  static const String formal = '正式';
  static const String travel = '旅行';
  static const String other = '其他';

  static const List<String> all = [
    commute,
    date,
    sport,
    casual,
    formal,
    travel,
    other,
  ];
}
