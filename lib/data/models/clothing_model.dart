class ClothingModel {
  const ClothingModel({
    required this.id,
    required this.imageUris,
    required this.category,
    required this.seasons,
    required this.colors,
    required this.styles,
    this.brand = '',
    this.price = 0.0,
    this.purchaseChannel = '',
    this.purchaseDate = '',
    this.storageLocation = '',
    this.status = ClothingStatus.normal,
    this.wearCount = 0,
    this.lastWornAt = 0,
    this.notes = '',
    this.ownerId = 'default',
    this.isShared = false,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.aiTags = '',
    this.imageProcessed = false,
    this.originalImageUri = '',
  });

  final String id;
  final String imageUris;
  final String category;
  final String seasons;
  final String colors;
  final String styles;
  final String brand;
  final double price;
  final String purchaseChannel;
  final String purchaseDate;
  final String storageLocation;
  final String status;
  final int wearCount;
  final int lastWornAt;
  final String notes;
  final String ownerId;
  final bool isShared;
  final int createdAt;
  final int updatedAt;
  final String aiTags;
  final bool imageProcessed;
  final String originalImageUri;

  List<String> get imageUriList =>
      imageUris.isEmpty ? [] : imageUris.split(',').where((e) => e.isNotEmpty).toList();

  List<String> get seasonList =>
      seasons.isEmpty ? [] : seasons.split(',').where((e) => e.isNotEmpty).toList();

  List<String> get colorList =>
      colors.isEmpty ? [] : colors.split(',').where((e) => e.isNotEmpty).toList();

  List<String> get styleList =>
      styles.isEmpty ? [] : styles.split(',').where((e) => e.isNotEmpty).toList();

  List<String> get aiTagList =>
      aiTags.isEmpty ? [] : aiTags.split(',').where((e) => e.isNotEmpty).toList();

  ClothingModel copyWith({
    String? id,
    String? imageUris,
    String? category,
    String? seasons,
    String? colors,
    String? styles,
    String? brand,
    double? price,
    String? purchaseChannel,
    String? purchaseDate,
    String? storageLocation,
    String? status,
    int? wearCount,
    int? lastWornAt,
    String? notes,
    String? ownerId,
    bool? isShared,
    int? createdAt,
    int? updatedAt,
    String? aiTags,
    bool? imageProcessed,
    String? originalImageUri,
  }) {
    return ClothingModel(
      id: id ?? this.id,
      imageUris: imageUris ?? this.imageUris,
      category: category ?? this.category,
      seasons: seasons ?? this.seasons,
      colors: colors ?? this.colors,
      styles: styles ?? this.styles,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      purchaseChannel: purchaseChannel ?? this.purchaseChannel,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      storageLocation: storageLocation ?? this.storageLocation,
      status: status ?? this.status,
      wearCount: wearCount ?? this.wearCount,
      lastWornAt: lastWornAt ?? this.lastWornAt,
      notes: notes ?? this.notes,
      ownerId: ownerId ?? this.ownerId,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aiTags: aiTags ?? this.aiTags,
      imageProcessed: imageProcessed ?? this.imageProcessed,
      originalImageUri: originalImageUri ?? this.originalImageUri,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageUris': imageUris,
      'category': category,
      'seasons': seasons,
      'colors': colors,
      'styles': styles,
      'brand': brand,
      'price': price,
      'purchaseChannel': purchaseChannel,
      'purchaseDate': purchaseDate,
      'storageLocation': storageLocation,
      'status': status,
      'wearCount': wearCount,
      'lastWornAt': lastWornAt,
      'notes': notes,
      'ownerId': ownerId,
      'isShared': isShared ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'aiTags': aiTags,
      'imageProcessed': imageProcessed ? 1 : 0,
      'originalImageUri': originalImageUri,
    };
  }

  factory ClothingModel.fromMap(Map<String, dynamic> map) {
    return ClothingModel(
      id: map['id'] as String,
      imageUris: map['imageUris'] as String? ?? '',
      category: map['category'] as String? ?? '',
      seasons: map['seasons'] as String? ?? '',
      colors: map['colors'] as String? ?? '',
      styles: map['styles'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      purchaseChannel: map['purchaseChannel'] as String? ?? '',
      purchaseDate: map['purchaseDate'] as String? ?? '',
      storageLocation: map['storageLocation'] as String? ?? '',
      status: map['status'] as String? ?? ClothingStatus.normal,
      wearCount: map['wearCount'] as int? ?? 0,
      lastWornAt: map['lastWornAt'] as int? ?? 0,
      notes: map['notes'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? 'default',
      isShared: (map['isShared'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int? ?? 0,
      aiTags: map['aiTags'] as String? ?? '',
      imageProcessed: (map['imageProcessed'] as int? ?? 0) == 1,
      originalImageUri: map['originalImageUri'] as String? ?? '',
    );
  }
}

class ClothingCategory {
  static const String top = '上衣';
  static const String tShirt = 'T恤';
  static const String shirt = '衬衫';
  static const String sweater = '毛衣';
  static const String hoodie = '卫衣';
  static const String pants = '裤子';
  static const String skirt = '裙子';
  static const String jacket = '外套';
  static const String coat = '大衣';
  static const String downJacket = '羽绒服';
  static const String dress = '连衣裙';
  static const String suit = '套装';
  static const String underwear = '内衣';
  static const String sportswear = '运动服';
  static const String shoes = '鞋子';
  static const String bag = '包包';
  static const String accessory = '配饰';
  static const String other = '其他';

  static const List<String> all = [
    top,
    tShirt,
    shirt,
    sweater,
    hoodie,
    pants,
    skirt,
    jacket,
    coat,
    downJacket,
    dress,
    suit,
    underwear,
    sportswear,
    shoes,
    bag,
    accessory,
    other,
  ];
}

class ClothingSeason {
  static const String spring = '春';
  static const String summer = '夏';
  static const String autumn = '秋';
  static const String winter = '冬';
  static const String allSeason = '四季';

  static const List<String> all = [spring, summer, autumn, winter, allSeason];
}

class ClothingStyle {
  static const String commute = '通勤';
  static const String casual = '休闲';
  static const String sport = '运动';
  static const String formal = '正式';
  static const String date = '约会';
  static const String outdoor = '户外';
  static const String vacation = '度假';
  static const String street = '街头';
  static const String vintage = '复古';
  static const String minimal = '简约';
  static const String other = '其他';

  static const List<String> all = [
    commute,
    casual,
    sport,
    formal,
    date,
    outdoor,
    vacation,
    street,
    vintage,
    minimal,
    other,
  ];
}

class ClothingStatus {
  static const String normal = '正常';
  static const String toWash = '待洗';
  static const String toRepair = '待修复';
  static const String idle = '闲置';
  static const String disposed = '已处置';

  static const List<String> all = [
    normal,
    toWash,
    toRepair,
    idle,
    disposed,
  ];
}
