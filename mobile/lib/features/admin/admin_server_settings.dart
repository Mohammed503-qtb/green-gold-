// ============================================================
// GREEN GOLD | إعدادات الخادم — داخل منطقة الإدارة (OWNER فقط)
// ------------------------------------------------------------
// العميل العادي لا يرى أي إعداد تقني. الخادم يُضبط من هنا:
// عرض العنوان الحالي + اختبار عنوان جديد + حفظ.
// عند الحفظ: يُنهى جلسة الموظف ويُعاد بناء كل مزوّدات البيانات.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../services/api_cache.dart';
import '../../services/api_provider.dart';
import '../../state/config.dart';
import '../../state/staff.dart';
import '../customer/customer_helpers.dart';
import '../customer/home_screen.dart';
import 'admin_common.dart';

class AdminServerSettingsScreen extends ConsumerStatefulWidget {
  const AdminServerSettingsScreen({super.key});

  @override
  ConsumerState<AdminServerSettingsScreen> createState() =>
      _AdminServerSettingsScreenState();
}

class _AdminServerSettingsScreenState
    extends ConsumerState<AdminServerSettingsScreen> {
  late final TextEditingController _urlCtrl;

  bool _testing = false;
  bool _saving = false;
  String? _error;
  String? _okStoreName;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
        text: ref.read(appConfigProvider).effectiveBaseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  String _normalize(String url) {
    var u = url.trim();
    if (u.isEmpty) return '';
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<void> _test() async {
    if (_testing) return;
    final url = _normalize(_urlCtrl.text);
    if (url.isEmpty) {
      setState(() => _error = 'أدخل عنوان الخادم أولًا');
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
      _okStoreName = null;
    });
    try {
      final client = ApiClient(baseUrl: url);
      final data = await client.get('/api/settings/public');
      if (data is Map<String, dynamic> &&
          (data.containsKey('storeName') || data.containsKey('whatsapp'))) {
        setState(() {
          _testing = false;
          _okStoreName = data['storeName']?.toString() ?? 'ذهب أخضر';
        });
      } else {
        setState(() {
          _testing = false;
          _error = 'الخادم استجاب لكنه لا يبدو خادم ذهب أخضر';
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _testing = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _testing = false;
        _error = 'تعذر الاتصال بالخادم، تحقق من العنوان';
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _okStoreName == null) return;
    final url = _normalize(_urlCtrl.text);
    if (url.isEmpty) return;
    setState(() => _saving = true);

    await ref.read(appConfigProvider.notifier).setBaseUrl(url);

    if (!mounted) return;

    // إعادة بناء كل مزوّدات البيانات بالعنوان الجديد
    // + تفريغ الكاش (بيانات خادم آخر لا تصلح)
    // + إنهاء جلسة الموظف (الـ PIN يخص الخادم السابق)
    ApiCache.I.resetMemory();
    await ref.read(staffSessionProvider.notifier).logout();
    if (!mounted) return;
    ref.invalidate(apiClientProvider);
    ref.invalidate(publicSettingsProvider);
    ref.invalidate(checkoutDataProvider);
    ref.invalidate(homeCatalogProvider);

    // العودة إلى جذر التطبيق (واجهة العميل بالخادم الجديد)
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF8BE9AF), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('تم حفظ الخادم ✅ — $url')),
          ],
        ),
        backgroundColor: const Color(0xFF17361F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _testing || _saving;
    final current = ref.watch(appConfigProvider).effectiveBaseUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الخادم'),
        actions: [
          IconButton(
            tooltip: 'اختبار الاتصال',
            onPressed: busy ? null : _test,
            icon: const Icon(Icons.wifi_tethering, color: AppPalette.green),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── العنوان الحالي ───
          SectionTitle(title: 'الخادم الحالي', icon: Icons.dns_rounded),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.isEmpty ? 'غير مضبوط' : current,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: current.isEmpty
                          ? Theme.of(context).hintColor
                          : AppPalette.greenDeep,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'كل بيانات المتجر تُجلب من هذا العنوان — التغيير يعمل على هذا الجهاز فقط',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ─── العنوان الجديد ───
          SectionTitle(title: 'تغيير الخادم', icon: Icons.wifi_tethering),
          const SizedBox(height: 10),
          TextField(
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            enabled: !busy,
            onSubmitted: (_) => _test(),
            decoration: const InputDecoration(
              hintText: 'https://...',
              prefixIcon: Icon(Icons.dns_outlined),
              labelText: 'عنوان الخادم الجديد',
            ),
          ),
          const SizedBox(height: 12),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 48,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _test,
                icon: const Icon(Icons.wifi_tethering, size: 20),
                label: const Text('اختبار الاتصال'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _okStoreName != null ? _save : null,
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text('حفظ الخادم وتسجيل الخروج'),
              ),
            ),
          ],
          if (_okStoreName != null && !busy) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.verified, color: AppPalette.green, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'متصل بـ $_okStoreName ✓',
                    style: const TextStyle(
                      color: AppPalette.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_error != null && !busy) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFC62828), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'ملاحظة: عند الحفظ تُنهى جلسة الإدارة الحالية لأن رمز PIN مرتبط بالخادم — سجّل الدخول من جديد بعد التغيير.',
            style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).hintColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
