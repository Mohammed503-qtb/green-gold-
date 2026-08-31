// ============================================================
// GREEN GOLD | أدوات مشتركة لواجهة العميل — مزوّدات البيانات
// + التقاط صورة إثبات الدفع (كاميرا/معرض → dataURL)
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/checkout.dart';
import '../../services/customer_services.dart';
import '../../shared/widgets.dart';

/// بيانات الشراء (المناطق + طرق الدفع + واتساب المتجر)
/// مشتركة بين السلة وإتمام الطلب والمتتبع
final checkoutDataProvider = FutureProvider<CheckoutData>((ref) {
  return ref.watch(checkoutServiceProvider).fetchCheckoutData();
});

/// الإعدادات العامة للمتجر (الاسم + واتساب) — لشاشة الحساب
final publicSettingsProvider = FutureProvider<PublicSettings>((ref) {
  return ref.watch(checkoutServiceProvider).fetchPublicSettings();
});

/// التقاط صورة إثبات الدفع وضغطها إلى dataURL:
/// maxWidth: 600 + imageQuality: 70 → 'data:image/jpeg;base64,...'
Future<String?> pickProofDataUrl(ImageSource source) async {
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 600,
      imageQuality: 70,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  } catch (_) {
    return null;
  }
}

/// حقل التقاط صورة الإثبات:
/// - عند عدم وجود صورة: زران (كاميرا / معرض)
/// - عند وجود صورة: معاينة مع زر إزالة
class ProofCaptureField extends StatelessWidget {
  final String? dataUrl;
  final ValueChanged<String?> onChanged;

  const ProofCaptureField({
    super.key,
    required this.dataUrl,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final url = await pickProofDataUrl(source);
    if (url == null) {
      if (context.mounted) {
        showAppSnackBar(context, 'تعذر قراءة الصورة، جرّب صورة أخرى', error: true);
      }
      return;
    }
    onChanged(url);
  }

  @override
  Widget build(BuildContext context) {
    final url = dataUrl;
    if (url == null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: const Text('كاميرا'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              label: const Text('معرض'),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 170,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ProofImage(url: url),
          ),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(null),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// بطاقة بعنوان — تُستخدم في تتبع الطلب والحساب
class TitledCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const TitledCard({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
