import 'dart:convert';
// ============================================================
// GREEN GOLD | مكونات مشتركة — صور، شارات، عدّادات، حالات
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/theme.dart';

// ───────── صور الشبكة ─────────

class NetImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const NetImage({super.key, this.url, this.width, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return _placeholder(icon: Icons.grass);
    }
    return CachedNetworkImage(
      imageUrl: u,
      width: width,
      height: height,
      fit: fit,
      // فك ترميز بأقصى 600px — ذاكرة أقل وأداء أسرع على الأجهزة المتوسطة
      memCacheWidth: 600,
      maxWidthDiskCache: 900,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => Container(
        color: const Color(0xFFEDF3EE),
        child: const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      ),
      errorWidget: (_, _, _) => _placeholder(icon: Icons.broken_image_outlined),
    );
  }

  Widget _placeholder({required IconData icon}) => Container(
        width: width,
        height: height,
        color: const Color(0xFFEDF3EE),
        child: Icon(icon, size: 34, color: Colors.grey.shade400),
      );
}

/// صورة إثبات الدفع — تدعم dataURL و http
class ProofImage extends StatelessWidget {
  final String url;
  const ProofImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:')) {
      // صورة dataURL مرفوعة من العميل
      try {
        final b64 = url.contains(',') ? url.split(',')[1] : '';
        if (b64.isEmpty) return const SizedBox.shrink();
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.broken_image, size: 40),
        );
      } catch (_) {
        return const Icon(Icons.broken_image, size: 40);
      }
    }
    return NetImage(url: url);
  }
}

// ───────── الشارات ─────────

class StatusChip extends StatelessWidget {
  final String status;
  final Map<String, String> labels;
  final (Color, Color) Function(String) colors;
  final String? text;

  const StatusChip({
    super.key,
    required this.status,
    required this.labels,
    required this.colors,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text ?? labels[status] ?? status,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) => StatusChip(
        status: status,
        labels: kOrderStatusLabels,
        colors: orderStatusColors,
      );
}

class PaymentStatusChip extends StatelessWidget {
  final String status;
  const PaymentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) => StatusChip(
        status: status,
        labels: kPaymentStatusLabels,
        colors: paymentStatusColors,
      );
}

class GradeBadge extends StatelessWidget {
  final String grade;
  const GradeBadge({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = gradeColors(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(kGradeEmoji[grade] ?? '',
              style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            kGradeLabels[grade] ?? grade,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────── عدّاد الكمية ─────────

class QtyStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final double compact;

  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.compact = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          icon: Icons.remove,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        Container(
          constraints: BoxConstraints(minWidth: 40 * compact),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        _btn(
          icon: Icons.add,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }

  Widget _btn({required IconData icon, VoidCallback? onTap}) => Material(
        color: onTap == null ? Colors.grey.shade200 : AppPalette.greenLight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 40 * compact,
            height: 40 * compact,
            child: Icon(
              icon,
              size: 20,
              color: onTap == null ? Colors.grey : AppPalette.greenDeep,
            ),
          ),
        ),
      );
}

// ───────── الحالات ─────────

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;

  const EmptyState({super.key, required this.emoji, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 13.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── أدوات عامة ─────────

void showAppSnackBar(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.check_circle_outline,
            color: error ? const Color(0xFFFFB4A9) : const Color(0xFF8BE9AF),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor:
          error ? const Color(0xFF7F1D1D) : const Color(0xFF17361F),
    ),
  );
}

/// فتح واتساب برسالة (يتطلب رقم المتجر بصيغة دولية بدون +)
Future<void> launchWhatsApp(BuildContext context, String whatsapp, String text) async {
  final uri = waLink(whatsapp, text);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'تعذر فتح واتساب', error: true);
    }
  }
}

/// فتح أي رابط خارجي (فيديو الدفعة مثلاً)
Future<void> launchExternal(BuildContext context, String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'تعذر فتح الرابط', error: true);
    }
  }
}

// ───────── مؤقتات ─────────

/// مؤقت تحديث دوري (لطلبات العميل ولوحة الإدارة)
/// 30 ثانية بدل 15 — يقلل الضغط على الشبكة الضعيفة
final autoRefreshTickerProvider = StreamProvider<int>((ref) {
  return Stream<int>.periodic(const Duration(seconds: 30), (i) => i);
});

// ───────── منطقة النقر السرية (دخول الإدارة المخفي) ─────────

/// تُغلِّف أي عنصر وتطلق [onTriggered] بعد نقرات متقاربة (5 افتراضيًا).
/// تُستخدم لإخفاء مداخل الإدارة عن المستخدمين العاديين —
/// لا شيء يظهر في الواجهة، والوصول عبر نمط نقر يعرفه المدير فقط.
class SecretTapArea extends StatefulWidget {
  final int taps;
  final Duration window;
  final VoidCallback onTriggered;
  final Widget child;

  const SecretTapArea({
    super.key,
    required this.onTriggered,
    required this.child,
    this.taps = 5,
    this.window = const Duration(seconds: 6),
  });

  @override
  State<SecretTapArea> createState() => _SecretTapAreaState();
}

class _SecretTapAreaState extends State<SecretTapArea> {
  int _count = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void _tap() {
    final now = DateTime.now();
    if (now.difference(_last) > widget.window) _count = 0;
    _last = now;
    _count++;
    if (_count >= widget.taps) {
      _count = 0;
      widget.onTriggered();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}
