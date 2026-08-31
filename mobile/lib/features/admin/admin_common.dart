// ============================================================
// GREEN GOLD | مشتركات واجهة الإدارة — guarded + بطاقات + نوافذ
// لا يُستورد إلا من داخل lib/features/admin/
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../shared/widgets.dart';

// guarded وعائلتها (المواصفة: تُكتب في admin_helpers.dart) — يُعاد تصديرها
// هنا حتى تستمر كل الشاشات المستوردة لـ admin_common بالعمل دون تغيير.
export 'admin_helpers.dart';

// ───────── إصدار بيانات الإدارة ─────────
// يُرفع بعد كل عملية كتابة ناجحة (تحقق دفع/إجراء طلب/تعديل دفعة…)
// فتُعيد كل مزوّدات البيانات الجلب تلقائيًا.
final adminDataVersionProvider = StateProvider<int>((ref) => 0);

/// الوجهة الحالية في غلاف الإدارة — تقرأها الشاشات لتعطيل التحديث الدوري عندما تكون مخفية
final adminShellTabProvider = StateProvider<int>((ref) => 0);

void bumpAdminData(WidgetRef ref) =>
    ref.read(adminDataVersionProvider.notifier).state++;

/// ينتظر مستقبل التحديث ويتجاهل أي خطأ (تحديث يدوي صامت)
Future<void> swallowRefresh<T>(Future<T> future) async {
  try {
    await future;
  } catch (_) {}
}

// ───────── guarded — انتقل إلى admin_helpers.dart (يُعاد تصديره أعلاه) ─────────

// ───────── صيغة أرقام مختصرة للرسوم (45,200 → 45.2k) ─────────

String compactNum(num n) {
  if (n >= 1000000) {
    final v = n / 1000000;
    return '${_trim(v)}M';
  }
  if (n >= 1000) {
    final v = n / 1000;
    return '${_trim(v)}k';
  }
  return formatNum(n);
}

String _trim(num v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

// ───────── بطاقة KPI ─────────

enum KpiTone { normal, success, gold, warning, danger }

class KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final KpiTone tone;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.tone = KpiTone.normal,
    this.onTap,
  });

  (Color, Color) get _colors {
    switch (tone) {
      case KpiTone.success:
        return (AppPalette.greenLight, AppPalette.greenDeep);
      case KpiTone.gold:
        return (AppPalette.goldLight, AppPalette.goldDark);
      case KpiTone.warning:
        return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
      case KpiTone.danger:
        return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      case KpiTone.normal:
        return (const Color(0xFFEDF3EE), AppPalette.greenDeep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tone == KpiTone.gold
              ? AppPalette.gold.withValues(alpha: 0.55)
              : const Color(0xFFE3EAE4),
          width: tone == KpiTone.gold ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0B3D20),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B241E),
                    ),
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

// ───────── عنوان قسم ─────────

class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const SectionTitle({super.key, required this.title, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: AppPalette.green),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ───────── شارة حالة الدفعة ─────────

const Map<String, String> kBatchStatusLabels = {
  'ACTIVE': 'نشطة',
  'HIDDEN': 'مخفية',
  'CLOSED': 'مغلقة',
  'SOLD_OUT': 'نافدة',
};

(Color, Color) batchStatusColors(String status) {
  switch (status) {
    case 'ACTIVE':
      return (AppPalette.greenLight, AppPalette.greenDeep);
    case 'HIDDEN':
      return (Colors.grey.shade200, Colors.grey.shade700);
    case 'CLOSED':
      return (const Color(0xFFFFEDD5), const Color(0xFF9A3412));
    case 'SOLD_OUT':
      return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
    default:
      return (Colors.grey.shade200, Colors.grey.shade700);
  }
}

class BatchStatusChip extends StatelessWidget {
  final String status;
  const BatchStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) => StatusChip(
        status: status,
        labels: kBatchStatusLabels,
        colors: batchStatusColors,
      );
}

// ───────── حركات المخزون ─────────

const Map<String, String> kMovementLabels = {
  'ADD': 'إضافة',
  'RESERVE': 'حجز',
  'RELEASE': 'تحرير',
  'SOLD': 'بيع',
  'CANCEL': 'إلغاء',
  'ADJUST': 'تعديل',
};

(Color, Color) movementColors(String type) {
  switch (type) {
    case 'ADD':
      return (AppPalette.greenLight, AppPalette.greenDeep);
    case 'RESERVE':
      return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    case 'RELEASE':
      return (Colors.grey.shade200, Colors.grey.shade700);
    case 'SOLD':
      return (const Color(0xFFDCF5E4), const Color(0xFF0B3D20));
    case 'CANCEL':
      return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
    case 'ADJUST':
      return (const Color(0xFFE7E5E4), const Color(0xFF44403C));
    default:
      return (Colors.grey.shade200, Colors.grey.shade700);
  }
}

class MovementChip extends StatelessWidget {
  final String type;
  const MovementChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) => StatusChip(
        status: type,
        labels: kMovementLabels,
        colors: movementColors,
      );
}

// ───────── نافذة تكبير صورة الإثبات (ملء الشاشة) ─────────

Future<void> showProofZoom(BuildContext context, String url) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.loose,
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: ProofImage(url: url),
            ),
            PositionedDirectional(
              top: 8,
              start: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ───────── بطاقة OTP الذهبية (لكي يُبلّغ الموظف العميل) ─────────

class OtpGoldCard extends StatelessWidget {
  final String otp;
  final String caption;

  const OtpGoldCard({super.key, required this.otp, this.caption = 'رمز تسليم العميل'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppPalette.goldGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  otp,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'أبلغ العميل',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────── نافذة OTP كبيرة بعد «خرج للتوصيل» ─────────

Future<void> showOtpDialog(BuildContext context, String orderCode, String otp) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: AppPalette.goldGradient,
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_rounded,
                color: Colors.white, size: 40),
            const SizedBox(height: 10),
            const Text(
              'خرج الطلب للتوصيل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'رمز تسليم العميل للطلب $orderCode',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                otp,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 40,
                  letterSpacing: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A6D14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'أبلغ العميل هذا الرمز — يُطلب عند التسليم',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B3D20),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('تم، فهمت'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ───────── إدخال OTP (4 خانات) ─────────

/// حقل إدخال رمز رقمي من 4 خانات — صناديق + لوحة مفاتيح النظام
class OtpBoxes extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final bool invalid;
  final String? errorText;

  const OtpBoxes({super.key, required this.onChanged, this.invalid = false, this.errorText});

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = _controller.text;
    return Column(
      children: [
        Stack(
          alignment: AlignmentDirectional.center,
          children: [
            // الصناديق المرئية (لا ت intercept اللمس)
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < digits.length;
                  final border = widget.invalid
                      ? const Color(0xFFDC2626)
                      : filled
                          ? AppPalette.green
                          : const Color(0xFFD8E2DA);
                  return Container(
                    width: 56,
                    height: 60,
                    margin: EdgeInsetsDirectional.only(end: i < 3 ? 10 : 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filled ? AppPalette.greenLight : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border, width: 2),
                    ),
                    child: Text(
                      filled ? digits[i] : '',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B3D20),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // حقل حقيقي شفاف يستقبل اللمس ويجلب لوحة الأرقام
            ExcludeSemantics(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) {
                  final clean =
                      v.replaceAll(RegExp(r'\D'), '').substring(0, 4);
                  if (clean != v) _controller.text = clean;
                  setState(() {});
                  widget.onChanged(clean);
                },
              ),
            ),
          ],
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

// ───────── حوارات التأكيد والإدخال ─────────

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16.5)),
      content: Text(message,
          style: const TextStyle(fontSize: 13.5, height: 1.6)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('تراجع'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r == true;
}

/// نافذة إدخال نص (سبب الرفض/الإلغاء/اسم السائق…)
Future<String?> textDialog(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  String confirmLabel = 'تأكيد',
  bool requiredText = true,
  int minLen = 2,
  bool danger = false,
  String confirmSuffix = '',
  TextInputType keyboard = TextInputType.text,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 16.5)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: keyboard,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) setDialog(() => error = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('تراجع'),
            ),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                    )
                  : null,
              onPressed: () {
                final v = controller.text.trim();
                if (requiredText && v.length < minLen) {
                  setDialog(() =>
                      error = 'هذا الحقل إجباري ($minLen أحرف على الأقل)');
                  return;
                }
                Navigator.of(ctx).pop(v);
              },
              child: Text(confirmSuffix.isEmpty
                  ? confirmLabel
                  : '$confirmLabel $confirmSuffix'),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  return result;
}

// ───────── أدوات صغيرة ─────────

/// تقصير معرف كيان (cuid) للعرض
String shortId(String id) =>
    id.length <= 10 ? id : '${id.substring(0, 8)}…';

/// عرض JSON مقروء إن أمكن وإلا النص كما هو
String prettyJsonish(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  return raw;
}

/// صف تفصيل صغير (تسمية + قيمة)
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool strong;

  const DetailRow(this.label, this.value, {super.key, this.icon, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppPalette.green),
            const SizedBox(width: 6),
          ],
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFF1B241E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شارة صغيرة عامة (نص + ألوان)
class MiniChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const MiniChip({super.key, required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// هامش رأسي موحد
const kAdminGap = SizedBox(height: 12);

/// بطاقة إجراء في قائمة «المزيد»
class MoreTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MoreTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAE4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// تسمية دور الموظف من kStaffRoleLabels بأمان
String staffRoleLabel(String? role) => kStaffRoleLabels[role] ?? role ?? '';
