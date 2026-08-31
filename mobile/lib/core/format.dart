// ============================================================
// GREEN GOLD | أدوات التنسيق — مطابقة لسلوك نسخة الويب
// أرقام لاتينية مفصولة بفواصل + تواريخ عربية
// ============================================================

import 'package:intl/intl.dart';

/// تنسيق المبلغ بالريال اليمني: "12,500 ريال"
String formatYER(num amount) {
  final f = NumberFormat('#,##0', 'en_US');
  return '${f.format(amount)} ريال';
}

/// أرقام لاتينية مفصولة بفواصل (بدون عملة)
String formatNum(num n) => NumberFormat('#,##0', 'en_US').format(n);

/// تنسيق التاريخ عربيًا: "31 أغسطس، 14:30" (أرقام لاتينية)
String formatArabicDate(DateTime? d, {bool withTime = true}) {
  if (d == null) return '—';
  final pattern = withTime ? 'd MMMM، HH:mm' : 'd MMMM';
  try {
    return DateFormat(pattern, 'ar').format(d);
  } catch (_) {
    return DateFormat(pattern).format(d);
  }
}

/// "منذ كذا" عربي
String timeAgoAr(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  final m = diff.inMinutes;
  if (m < 1) return 'الآن';
  if (m < 60) return 'منذ $m دقيقة';
  final h = diff.inHours;
  if (h < 24) return 'منذ $h ساعة';
  final days = (h / 24).floor();
  if (days == 1) return 'أمس';
  if (days < 7) return 'منذ $days أيام';
  return formatArabicDate(d, withTime: false);
}

/// وقت التصوير: "تصوير اليوم 12:40" / "تصوير أمس 08:15" / "تصوير 29 أغسطس"
String capturedLabel(DateTime? capturedAt) {
  if (capturedAt == null) return 'وقت التصوير غير معروف';
  final now = DateTime.now();
  final startOfDayNow = DateTime(now.year, now.month, now.day);
  final startOfDayThen =
      DateTime(capturedAt.year, capturedAt.month, capturedAt.day);
  final diffDays =
      startOfDayNow.difference(startOfDayThen).inDays;
  final hm = DateFormat('HH:mm').format(capturedAt);
  if (diffDays <= 0) return 'تصوير اليوم $hm';
  if (diffDays == 1) return 'تصوير أمس $hm';
  return 'تصوير ${DateFormat('d MMMM', 'ar').format(capturedAt)}';
}

/// يحوّل المدخلات إلى 7xxxxxxxx أو يعيد null إن كان غير صالح
String? normalizePhone(String raw) {
  var p = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (p.startsWith('+967')) {
    p = p.substring(4);
  } else if (p.startsWith('00967')) {
    p = p.substring(5);
  } else if (p.startsWith('967') && p.length == 12) {
    p = p.substring(3);
  }
  return RegExp(r'^7\d{8}$').hasMatch(p) ? p : null;
}

/// يحوّل أي ISO/Datetime قادم من الخادم إلى DateTime محلي
DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v);
  }
  return null;
}
