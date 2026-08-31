// ============================================================
// GREEN GOLD | نماذج الدفعات والكتالوج — مطابقة لـ BatchCardDTO
// تحليل دفاعي: أي حقل ناقص لا يكسر التطبيق
// ============================================================

class BatchQuality {
  final int freshness;
  final int density;
  final int fullness;
  final int appearance;

  const BatchQuality({
    required this.freshness,
    required this.density,
    required this.fullness,
    required this.appearance,
  });

  factory BatchQuality.fromJson(Map<String, dynamic> j) => BatchQuality(
        freshness: _int(j['freshness']),
        density: _int(j['density']),
        fullness: _int(j['fullness']),
        appearance: _int(j['appearance']),
      );

  int get average => ((freshness + density + fullness + appearance) / 4).round();

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class BatchCard {
  final String id;
  final String batchCode;
  final String productId;
  final String productName;
  final String grade; // PREMIUM | EXCELLENT | ECONOMIC
  final num price;
  final int availableQty;
  final String status; // ACTIVE | HIDDEN | CLOSED | SOLD_OUT
  final DateTime? capturedAt;
  final String? mainImage;
  final List<String> images;
  final String? video;
  final BatchQuality? quality;
  final int soldCount;
  final num? avgRating;
  final int reviewsCount;

  // ── حقول الإدارة الإضافية (اختيارية) ──
  final int? totalQty;
  final int? reservedQty;
  final int? soldQty;
  final String? description;

  const BatchCard({
    required this.id,
    required this.batchCode,
    required this.productId,
    required this.productName,
    required this.grade,
    required this.price,
    required this.availableQty,
    required this.status,
    this.capturedAt,
    this.mainImage,
    this.images = const [],
    this.video,
    this.quality,
    this.soldCount = 0,
    this.avgRating,
    this.reviewsCount = 0,
    this.totalQty,
    this.reservedQty,
    this.soldQty,
    this.description,
  });

  bool get isActive => status == 'ACTIVE' && availableQty > 0;
  bool get isLowStock => isActive && availableQty <= 5;

  factory BatchCard.fromJson(Map<String, dynamic> j) {
    final qualityRaw = j['quality'];
    final imagesRaw = j['images'];
    return BatchCard(
      id: _s(j['id']) ?? '',
      batchCode: _s(j['batchCode']) ?? '',
      productId: _s(j['productId']) ?? '',
      productName: _s(j['productName']) ?? 'قات',
      grade: _s(j['grade']) ?? 'ECONOMIC',
      price: _n(j['price']) ?? 0,
      availableQty: _i(j['availableQty']),
      status: _s(j['status']) ?? 'CLOSED',
      capturedAt: _d(j['capturedAt']),
      mainImage: _s(j['mainImage']),
      images: imagesRaw is List
          ? imagesRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      video: _s(j['video']),
      quality: qualityRaw is Map<String, dynamic>
          ? BatchQuality.fromJson(qualityRaw)
          : null,
      soldCount: _i(j['soldCount']),
      avgRating: _n(j['avgRating']),
      reviewsCount: _i(j['reviewsCount']),
      totalQty: j['totalQty'] == null ? null : _i(j['totalQty']),
      reservedQty: j['reservedQty'] == null ? null : _i(j['reservedQty']),
      soldQty: j['soldQty'] == null ? null : _i(j['soldQty']),
      description: _s(j['description']),
    );
  }

  static String? _s(dynamic v) =>
      v is String && v.isNotEmpty ? v : null;
  static num? _n(dynamic v) =>
      v is num ? v : (v is String ? num.tryParse(v) : null);
  static int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
  static DateTime? _d(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }
}

class BatchReview {
  final int rating;
  final String smiley; // LOVE | GOOD | OK | BAD
  final bool? matchedPhotos;
  final String? comment;
  final DateTime? createdAt;
  final String? customerName;

  const BatchReview({
    required this.rating,
    required this.smiley,
    this.matchedPhotos,
    this.comment,
    this.createdAt,
    this.customerName,
  });

  factory BatchReview.fromJson(Map<String, dynamic> j) => BatchReview(
        rating: j['rating'] is num ? (j['rating'] as num).round() : 0,
        smiley: j['smiley'] is String ? j['smiley'] as String : 'GOOD',
        matchedPhotos: j['matchedPhotos'] is bool ? j['matchedPhotos'] as bool : null,
        comment: j['comment'] is String && (j['comment'] as String).isNotEmpty
            ? j['comment'] as String
            : null,
        createdAt: j['createdAt'] is String
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
        customerName: j['customerName'] is String && (j['customerName'] as String).isNotEmpty
            ? j['customerName'] as String
            : null,
      );
}

class BatchDetail {
  final BatchCard batch;
  final String? productOrigin;
  final List<BatchReview> reviews;

  const BatchDetail({
    required this.batch,
    this.productOrigin,
    this.reviews = const [],
  });

  num? get avgRating {
    if (reviews.isEmpty) return null;
    final sum = reviews.fold<num>(0, (a, r) => a + r.rating);
    return sum / reviews.length;
  }
}
