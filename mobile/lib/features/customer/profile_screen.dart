// ============================================================
// GREEN GOLD | حسابي — بيانات العميل + معلومات المتجر + الخادم
// + دخول الإدارة + الإصدار وبصمة الثقة
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../services/api_provider.dart';
import '../../shared/widgets.dart';
import '../../state/config.dart';
import '../../state/session.dart';
import '../admin/admin_login_screen.dart';
import 'customer_helpers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(customerSessionProvider);
    final config = ref.watch(appConfigProvider);
    final hintColor = Theme.of(context).hintColor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const Text('👤 حسابي',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),

        // ─── بطاقة الحساب ───
        _AccountCard(
          name: session.name,
          phone: session.phone,
          onEdit: () => _openEditAccountDialog(context, session),
        ),
        const SizedBox(height: 12),

        // ─── معلومات المتجر ───
        _StoreCard(hintColor: hintColor),
        const SizedBox(height: 12),

        // ─── إعدادات الخادم ───
        _ServerCard(
          baseUrl: config.effectiveBaseUrl,
          onChange: () => _openChangeServerDialog(context, config),
        ),
        const SizedBox(height: 12),

        // ─── دخول الإدارة ───
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppPalette.greenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.admin_panel_settings_outlined,
                        color: AppPalette.greenDeep, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('دخول الإدارة',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14.5)),
                        SizedBox(height: 2),
                        Text('للموظفين — برمز PIN خاص بالمتجر',
                            style: TextStyle(fontSize: 11.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ─── التذييل ───
        Center(
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppPalette.greenLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.grass_rounded,
                        color: AppPalette.greenDeep, size: 16),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ذهب أخضر — الإصدار 1.0.0',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'تصوير حقيقي لكل دفعة • تحقق يدوي لكل دفع • OTP للتسليم',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: hintColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────── تعديل بيانات الحساب ─────────

  Future<void> _openEditAccountDialog(
    BuildContext context,
    CustomerSession session,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _EditAccountDialog(
        initialName: session.name,
        initialPhone: session.phone,
      ),
    );
  }

  // ───────── تغيير الخادم ─────────

  Future<void> _openChangeServerDialog(
    BuildContext context,
    AppConfig config,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ChangeServerDialog(
        initialUrl: config.effectiveBaseUrl,
      ),
    );
  }
}

// ───────── بطاقة الحساب ─────────

class _AccountCard extends StatelessWidget {
  final String name;
  final String phone;
  final VoidCallback onEdit;

  const _AccountCard({
    required this.name,
    required this.phone,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    final hasName = name.trim().isNotEmpty;
    final hasPhone = phone.trim().isNotEmpty;
    final initial = hasName ? name.trim().characters.first : '؟';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppPalette.goldGradient,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasName ? name : 'زائر جديد',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  hasPhone
                      ? Text(
                          phone,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                              fontSize: 13, color: hintColor),
                        )
                      : Text(
                          'لم تُسجّل رقم هاتف بعد',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: hintColor,
                              fontStyle: FontStyle.italic),
                        ),
                ],
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: 'تعديل بياناتي',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── نافذة تعديل الحساب ─────────

class _EditAccountDialog extends ConsumerStatefulWidget {
  final String initialName;
  final String initialPhone;

  const _EditAccountDialog({
    required this.initialName,
    required this.initialPhone,
  });

  @override
  ConsumerState<_EditAccountDialog> createState() =>
      _EditAccountDialogState();
}

class _EditAccountDialogState extends ConsumerState<_EditAccountDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _phoneCtrl =
      TextEditingController(text: widget.initialPhone);

  String? _nameError;
  String? _phoneError;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    final phone = normalizePhone(_phoneCtrl.text);

    final nameError =
        name.length < 2 ? 'اكتب اسمك (حرفان على الأقل)' : null;
    final phoneError =
        phone == null ? 'أدخل رقم هاتف يمني صحيح يبدأ بـ7 (9 أرقام)' : null;

    setState(() {
      _nameError = nameError;
      _phoneError = phoneError;
    });
    if (nameError != null || phoneError != null) return;

    setState(() => _saving = true);
    final session = ref.read(customerSessionProvider.notifier);
    await session.setName(name);
    await session.setPhone(phone!);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    _showSnack(messenger, 'تم حفظ بياناتك ✅');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل بياناتي'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الاسم',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'مثال: أحمد عبدالله',
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
            ),
            const SizedBox(height: 14),
            const Text('رقم الهاتف',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: '7XXXXXXXX',
                errorText: _phoneError,
              ),
              onChanged: (_) {
                if (_phoneError != null) {
                  setState(() => _phoneError = null);
                }
              },
            ),
            const SizedBox(height: 4),
            Text(
              'يُستخدم رقمك لعرض طلباتك ومتابعتها — يُحفظ على جهازك فقط',
              style: TextStyle(
                  fontSize: 11, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

// ───────── بطاقة معلومات المتجر ─────────

class _StoreCard extends ConsumerWidget {
  final Color hintColor;

  const _StoreCard({required this.hintColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(publicSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppPalette.greenLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_outlined,
                      color: AppPalette.greenDeep, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: settingsAsync.when(
                    loading: () => const Text('جارٍ جلب معلومات المتجر…',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    error: (e, _) => const Text('معلومات المتجر',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14.5)),
                    data: (settings) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(settings.storeName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text('قات اليوم في عدن — بصور حقيقية',
                            style: TextStyle(
                                fontSize: 11.5, color: hintColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            settingsAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
              error: (e, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      'تعذر جلب معلومات المتجر — تحقق من الخادم',
                      style: TextStyle(fontSize: 12, color: hintColor),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(publicSettingsProvider),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
              data: (settings) => SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => launchWhatsApp(
                    context,
                    settings.whatsapp,
                    'السلام عليكم، لدي استفسار عن متجر ${settings.storeName} 🌿',
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 20),
                  label: const Text('تواصل مع المتجر عبر واتساب'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── بطاقة إعدادات الخادم ─────────

class _ServerCard extends StatelessWidget {
  final String baseUrl;
  final VoidCallback onChange;

  const _ServerCard({required this.baseUrl, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppPalette.goldLight.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dns_outlined,
                      color: AppPalette.goldDark, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('خادم المتجر',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5)),
                      SizedBox(height: 2),
                      Text('عنوان الـ API الذي يتصل به التطبيق',
                          style: TextStyle(fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                baseUrl.isEmpty ? 'غير مضبوط' : baseUrl,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: baseUrl.isEmpty ? hintColor : null,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onChange,
                icon: const Icon(Icons.wifi_tethering, size: 20),
                label: const Text('تغيير الخادم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── إشعار عبر messenger ملتقط قبل إغلاق النافذة ─────────

void _showSnack(ScaffoldMessengerState messenger, String message,
    {bool error = false}) {
  messenger.showSnackBar(
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

// ───────── نافذة تغيير الخادم ─────────

class _ChangeServerDialog extends ConsumerStatefulWidget {
  final String initialUrl;

  const _ChangeServerDialog({required this.initialUrl});

  @override
  ConsumerState<_ChangeServerDialog> createState() =>
      _ChangeServerDialogState();
}

class _ChangeServerDialogState extends ConsumerState<_ChangeServerDialog> {
  late final TextEditingController _urlCtrl =
      TextEditingController(text: widget.initialUrl);

  bool _testing = false;
  bool _saving = false;
  String? _error;
  String? _okStoreName;

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
    // إعادة بناء عميل الـ API وبيانات المتجر على العنوان الجديد
    ref.invalidate(apiClientProvider);
    ref.invalidate(publicSettingsProvider);
    ref.invalidate(checkoutDataProvider);

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    _showSnack(messenger, 'تم حفظ الخادم ✅ — $url');
  }

  @override
  Widget build(BuildContext context) {
    final busy = _testing || _saving;
    return AlertDialog(
      title: const Text('تغيير خادم المتجر'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أدخل عنوان خادم ذهب أخضر (مثال: https://api.greengold.ye)',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 12),
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
              ),
            ),
            const SizedBox(height: 12),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 46,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _test,
                  icon: const Icon(Icons.wifi_tethering, size: 20),
                  label: const Text('اختبار الاتصال'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 46,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _okStoreName != null ? _save : null,
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: const Text('حفظ الخادم'),
                ),
              ),
            ],
            if (_okStoreName != null && !busy) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.verified,
                      color: AppPalette.green, size: 18),
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
              const SizedBox(height: 10),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
