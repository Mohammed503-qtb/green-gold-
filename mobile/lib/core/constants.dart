// ============================================================
// GREEN GOLD | ذهب أخضر — الثوابت المشتركة (مطابقة لعقود الخادم)
// مصدر الحقيقة الواحد: src/lib/contracts.ts في مشروع الويب
// ============================================================

import 'package:flutter/material.dart';

// ───────── حالات الطلب (State Machine) ─────────

const Map<String, String> kOrderStatusLabels = {
  'PENDING_PAYMENT': 'بانتظار الدفع',
  'PAYMENT_SUBMITTED': 'تم إرسال إثبات الدفع',
  'CONFIRMED': 'تم تأكيد الطلب',
  'PREPARING': 'جاري التجهيز',
  'READY_FOR_DELIVERY': 'جاهز للتوصيل',
  'OUT_FOR_DELIVERY': 'خرج للتوصيل',
  'DELIVERED': 'تم التسليم',
  'CANCELLED': 'ملغي',
  'PAYMENT_REJECTED': 'مرفوض الدفع',
  'REFUNDED': 'مسترجع',
  'FAILED_DELIVERY': 'تعذر التوصيل',
};

/// المسار الطبيعي للطلب
const List<String> kOrderFlow = [
  'PENDING_PAYMENT',
  'PAYMENT_SUBMITTED',
  'CONFIRMED',
  'PREPARING',
  'READY_FOR_DELIVERY',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
];

/// خطوات شريط التتبع للعميل
const List<MapEntry<String, String>> kCustomerTrackSteps = [
  MapEntry('CONFIRMED', 'تم التأكيد'),
  MapEntry('PREPARING', 'جاري التجهيز'),
  MapEntry('OUT_FOR_DELIVERY', 'التوصيل'),
  MapEntry('DELIVERED', 'التسليم'),
];

/// ألوان شارات حالات الطلب (خلفية، نص)
(Color, Color) orderStatusColors(String status) {
  switch (status) {
    case 'PENDING_PAYMENT':
      return (const Color(0x33F59E0B), const Color(0xFF92400E));
    case 'PAYMENT_SUBMITTED':
      return (const Color(0x337C3AED), const Color(0xFF5B21B6));
    case 'CONFIRMED':
      return (const Color(0x33059669), const Color(0xFF065F46));
    case 'PREPARING':
      return (const Color(0x3365A30D), const Color(0xFF3F6212));
    case 'READY_FOR_DELIVERY':
      return (const Color(0x330D9488), const Color(0xFF115E59));
    case 'OUT_FOR_DELIVERY':
      return (const Color(0x3306B6D4), const Color(0xFF155E75));
    case 'DELIVERED':
      return (const Color(0x3316A34A), const Color(0xFF14532D));
    case 'CANCELLED':
      return (Colors.grey.shade200, Colors.grey.shade700);
    case 'PAYMENT_REJECTED':
    case 'FAILED_DELIVERY':
      return (const Color(0x33DC2626), const Color(0xFF991B1B));
    case 'REFUNDED':
      return (const Color(0x33EA580C), const Color(0xFF9A3412));
    default:
      return (Colors.grey.shade200, Colors.grey.shade700);
  }
}

// ───────── حالات الدفع ─────────

const Map<String, String> kPaymentStatusLabels = {
  'UNPAID': 'غير مدفوع',
  'PENDING_VERIFICATION': 'بانتظار التحقق',
  'PAID': 'مدفوع',
  'REJECTED': 'مرفوض',
  'REFUNDED': 'مسترجع',
};

(Color, Color) paymentStatusColors(String status) {
  switch (status) {
    case 'UNPAID':
      return (Colors.grey.shade200, Colors.grey.shade700);
    case 'PENDING_VERIFICATION':
      return (const Color(0x33F59E0B), const Color(0xFF92400E));
    case 'PAID':
      return (const Color(0x33059669), const Color(0xFF065F46));
    case 'REJECTED':
      return (const Color(0x33DC2626), const Color(0xFF991B1B));
    case 'REFUNDED':
      return (const Color(0x33EA580C), const Color(0xFF9A3412));
    default:
      return (Colors.grey.shade200, Colors.grey.shade700);
  }
}

// ───────── التصنيفات ─────────

const Map<String, String> kGradeLabels = {
  'PREMIUM': 'فاخر',
  'EXCELLENT': 'ممتاز',
  'ECONOMIC': 'اقتصادي',
};

const Map<String, String> kGradeEmoji = {
  'PREMIUM': '💎',
  'EXCELLENT': '⭐',
  'ECONOMIC': '💰',
};

(Color, Color) gradeColors(String grade) {
  switch (grade) {
    case 'PREMIUM':
      // ذهبي فاخر
      return (const Color(0xFFFFF7DB), const Color(0xFF92400E));
    case 'EXCELLENT':
      return (const Color(0x33059669), const Color(0xFF065F46));
    case 'ECONOMIC':
      return (Colors.grey.shade200, Colors.grey.shade800);
    default:
      return (Colors.grey.shade200, Colors.grey.shade800);
  }
}

// ───────── حالات التوصيل ─────────

const Map<String, String> kDeliveryStatusLabels = {
  'WAITING': 'بانتظار التعيين',
  'ASSIGNED': 'تم تعيين سائق',
  'PICKED_UP': 'تم الاستلام من المحل',
  'OUT_FOR_DELIVERY': 'في الطريق إليك',
  'DELIVERED': 'تم التسليم',
  'FAILED': 'تعذر التسليم',
};

// ───────── أنواع طرق الدفع ─────────

const Map<String, String> kPaymentTypeLabels = {
  'BANK': 'تحويل بنكي',
  'WALLET': 'محفظة إلكترونية',
  'COD': 'الدفع عند الاستلام',
};

// ───────── الأدوار والصلاحيات ─────────

const Map<String, String> kStaffRoleLabels = {
  'OWNER': 'المالك',
  'MANAGER': 'مدير',
  'STAFF': 'موظف',
  'DELIVERY': 'سائق',
};

const Map<String, List<String>> kCan = {
  'verifyPayment': ['OWNER', 'MANAGER'],
  'manageBatches': ['OWNER', 'MANAGER', 'STAFF'],
  'changePrice': ['OWNER', 'MANAGER'],
  'advanceOrder': ['OWNER', 'MANAGER', 'STAFF'],
  'manageDelivery': ['OWNER', 'MANAGER', 'STAFF', 'DELIVERY'],
  'viewReports': ['OWNER', 'MANAGER'],
  'viewAudit': ['OWNER', 'MANAGER'],
  'manageSettings': ['OWNER'],
};

bool canRole(String? role, String permission) {
  if (role == null) return false;
  return kCan[permission]?.contains(role) ?? false;
}

// ───────── التقييم ─────────

const Map<String, String> kSmileys = {
  'LOVE': '😍',
  'GOOD': '🙂',
  'OK': '😐',
  'BAD': '☹️',
};

const Map<String, int> kSmileyRating = {
  'LOVE': 5,
  'GOOD': 4,
  'OK': 3,
  'BAD': 2,
};

// ───────── ثوابت عامة ─────────

/// عتبة "مخزون منخفض"
const int kLowStockThreshold = 5;

/// مهلة حجز المخزون (دقائق)
const int kReservationMinutes = 30;

/// الرسالة الجاهزة الرسمية لمتابعة الطلب عبر واتساب
String orderWaMessage(String code) =>
    'السلام عليكم، لدي طلب ذهب أخضر رقم $code وأريد متابعة طلبي.';

/// رابط واتساب مع رسالة
Uri waLink(String whatsapp, String text) {
  final digits = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 9) {
    return Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
  }
  return Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
}
