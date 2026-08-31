// ============================================================
// GREEN GOLD | جلسة العميل — الاسم والهاتف والمنطقة (محفوظة)
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerSession {
  final String name;
  final String phone;
  final String? zoneId;

  const CustomerSession({
    this.name = '',
    this.phone = '',
    this.zoneId,
  });

  bool get hasPhone => phone.isNotEmpty;
}

class CustomerSessionNotifier extends StateNotifier<CustomerSession> {
  final SharedPreferences prefs;

  CustomerSessionNotifier(this.prefs)
      : super(CustomerSession(
          name: prefs.getString('gg-name') ?? '',
          phone: prefs.getString('gg-phone') ?? '',
          zoneId: prefs.getString('gg-zone'),
        ));

  Future<void> setName(String name) async {
    await prefs.setString('gg-name', name.trim());
    state = CustomerSession(
        name: name.trim(), phone: state.phone, zoneId: state.zoneId);
  }

  Future<void> setPhone(String phone) async {
    await prefs.setString('gg-phone', phone.trim());
    state = CustomerSession(
        name: state.name, phone: phone.trim(), zoneId: state.zoneId);
  }

  Future<void> setZone(String? zoneId) async {
    if (zoneId == null) {
      await prefs.remove('gg-zone');
    } else {
      await prefs.setString('gg-zone', zoneId);
    }
    state = CustomerSession(
        name: state.name, phone: state.phone, zoneId: zoneId);
  }
}

final customerSessionProvider =
    StateNotifierProvider<CustomerSessionNotifier, CustomerSession>((ref) {
  throw UnimplementedError('يُستبدل في main عبر overrides');
});
