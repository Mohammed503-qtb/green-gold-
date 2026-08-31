// ============================================================
// GREEN GOLD | شاشة إعداد الخادم — للإدارة فقط
// ------------------------------------------------------------
// لا تظهر للمستخدم العادي: تُفتح عبر النقر السري
// (5 نقرات على شعار بوابة الاتصال أو شاشة دخول الإدارة)
// أو عند أول تشغيل بواسطة من يجهّز الجهاز.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../services/api_cache.dart';
import '../services/api_provider.dart';
import '../state/config.dart';
import 'customer/customer_helpers.dart';
import 'customer/home_screen.dart';

class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _controller = TextEditingController();
  bool _testing = false;
  String? _error;
  String? _okStoreName;

  @override
  void dispose() {
    _controller.dispose();
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
    final url = _normalize(_controller.text);
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
    final url = _normalize(_controller.text);
    if (url.isEmpty || _okStoreName == null) {
      setState(() => _error = 'اختبر الاتصال أولًا ثم احفظ');
      return;
    }
    await ref.read(appConfigProvider.notifier).setBaseUrl(url);
    if (mounted) {
      // إعادة بناء كل مزوّدات البيانات بالعنوان الجديد
      // + تفريغ الكاش (بيانات متجر آخر لا تصلح)
      ApiCache.I.resetMemory();
      ref.invalidate(apiClientProvider);
      ref.invalidate(publicSettingsProvider);
      ref.invalidate(checkoutDataProvider);
      ref.invalidate(homeCatalogProvider);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppPalette.heroGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppPalette.gold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ذهب أخضر',
                    style: TextStyle(
                      color: AppPalette.goldLight,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'قات اليوم في عدن — بشوف ما بتستلمه قبل ما تدفع',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFCFE2D5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            ' 🔗 عنوان خادم المتجر',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'أدخل عنوان خادم ذهب أخضر الذي يديره المتجر (مثال: https://api.greengold.ye)',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _controller,
                            keyboardType: TextInputType.url,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              hintText: 'https://...',
                              prefixIcon: Icon(Icons.dns_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_testing)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else ...[
                            OutlinedButton.icon(
                              onPressed: _test,
                              icon: const Icon(Icons.wifi_tethering),
                              label: const Text('اختبار الاتصال'),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _okStoreName != null ? _save : null,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('حفظ والمتابعة'),
                            ),
                          ],
                          if (_okStoreName != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.verified, color: AppPalette.green),
                                const SizedBox(width: 6),
                                Text(
                                  'متصل بـ $_okStoreName ✓',
                                  style: const TextStyle(
                                    color: AppPalette.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFC62828),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'الإصدار 1.0.2 — ذهب أخضر للتجارة',
                    style: TextStyle(color: Color(0xFF7B9C87), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
