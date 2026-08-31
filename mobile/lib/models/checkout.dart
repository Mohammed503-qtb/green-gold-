// ============================================================
// GREEN GOLD | نماذج الشراء — المناطق وطرق الدفع والإعدادات العامة
// ============================================================

class Zone {
  final String id;
  final String name;
  final num fee;

  const Zone({required this.id, required this.name, required this.fee});

  factory Zone.fromJson(Map<String, dynamic> j) => Zone(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'منطقة',
        fee: _n(j['fee']) ?? 0,
      );

  static num? _n(dynamic v) =>
      v is num ? v : (v is String ? num.tryParse(v) : null);
}

class PaymentMethod {
  final String id;
  final String name;
  final String type; // BANK | WALLET | COD
  final String? accountName;
  final String? institution;
  final String? accountNumber;
  final String? instructions;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    this.accountName,
    this.institution,
    this.accountNumber,
    this.instructions,
  });

  bool get isCod => type == 'COD';

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'طريقة دفع',
        type: j['type']?.toString() ?? 'BANK',
        accountName: _s(j['accountName']),
        institution: _s(j['institution']),
        accountNumber: _s(j['accountNumber']),
        instructions: _s(j['instructions']),
      );

  static String? _s(dynamic v) =>
      v is String && v.isNotEmpty ? v : null;
}

class CheckoutData {
  final List<Zone> zones;
  final List<PaymentMethod> methods;
  final String storeName;
  final String whatsapp;

  const CheckoutData({
    required this.zones,
    required this.methods,
    required this.storeName,
    required this.whatsapp,
  });

  factory CheckoutData.fromJson(Map<String, dynamic> j) => CheckoutData(
        zones: _list<Zone>(j['zones'], Zone.fromJson),
        methods: _list<PaymentMethod>(j['methods'], PaymentMethod.fromJson),
        storeName: j['storeName']?.toString() ?? 'ذهب أخضر',
        whatsapp: j['whatsapp']?.toString() ?? '967771234567',
      );
}

class PublicSettings {
  final String storeName;
  final String whatsapp;

  const PublicSettings({required this.storeName, required this.whatsapp});

  factory PublicSettings.fromJson(Map<String, dynamic> j) => PublicSettings(
        storeName: j['storeName']?.toString() ?? 'ذهب أخضر',
        whatsapp: j['whatsapp']?.toString() ?? '967771234567',
      );
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(e.cast<String, dynamic>()))
      .toList();
}
