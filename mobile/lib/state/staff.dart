// ============================================================
// GREEN GOLD | جلسة موظف الإدارة — PIN + الاسم + الدور
// ============================================================

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffSession {
  final String name;
  final String role; // OWNER | MANAGER | STAFF | DELIVERY
  final String pin;

  const StaffSession({
    required this.name,
    required this.role,
    required this.pin,
  });

  Map<String, dynamic> toJson() =>
      {'name': name, 'role': role, 'pin': pin};

  factory StaffSession.fromJson(Map<String, dynamic> j) => StaffSession(
        name: j['name']?.toString() ?? '',
        role: j['role']?.toString() ?? '',
        pin: j['pin']?.toString() ?? '',
      );
}

class StaffSessionNotifier extends StateNotifier<StaffSession?> {
  final SharedPreferences prefs;

  StaffSessionNotifier(this.prefs) : super(null) {
    _load();
  }

  void _load() {
    try {
      final raw = prefs.getString('gg-staff');
      if (raw == null || raw.isEmpty) return;
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic>) {
        final s = StaffSession.fromJson(j);
        if (s.name.isNotEmpty &&
            s.pin.isNotEmpty &&
            ['OWNER', 'MANAGER', 'STAFF', 'DELIVERY'].contains(s.role)) {
          state = s;
        }
      }
    } catch (_) {}
  }

  Future<void> login(StaffSession session) async {
    state = session;
    try {
      await prefs.setString('gg-staff', jsonEncode(session.toJson()));
    } catch (_) {}
  }

  Future<void> logout() async {
    state = null;
    try {
      await prefs.remove('gg-staff');
    } catch (_) {}
  }
}

final staffSessionProvider =
    StateNotifierProvider<StaffSessionNotifier, StaffSession?>((ref) {
  throw UnimplementedError('يُستبدل في main عبر overrides');
});
