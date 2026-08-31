// ============================================================
// GREEN GOLD | شاشة دخول الإدارة — PIN بأربع خانات ولوحة أرقام
// AdminLoginScreen بلا معاملات (تُفتح من تطبيق العميل مباشرة)
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../services/admin_service.dart';
import '../../state/staff.dart';
import '../../shared/widgets.dart';
import 'admin_shell.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  String? _error;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _submit(String pin) async {
    if (_busy || pin.length != 4) return;
    setState(() => _busy = true);
    try {
      final session = await ref.read(adminServiceProvider).login(pin);
      if (!mounted) return;
      await ref.read(staffSessionProvider.notifier).login(StaffSession(
            name: session.name,
            role: session.role,
            pin: pin,
          ));
      if (!mounted) return;
      showAppSnackBar(context, 'أهلًا ${session.name} 👋');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminShell()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        setState(() {
          _error = 'رمز PIN غير صحيح';
          _pin = '';
        });
        _shake.forward(from: 0);
      } else {
        setState(() => _pin = '');
        showAppSnackBar(context, 'تعذر الاتصال بالخادم', error: true);
      }
    } on StateError {
      if (!mounted) return;
      setState(() => _pin = '');
      showAppSnackBar(context, 'تعذر الاتصال بالخادم', error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pin = '');
      showAppSnackBar(context, 'تعذر الاتصال بالخادم', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addDigit(String d) {
    if (_busy || _pin.length >= 4) return;
    final next = '$_pin$d';
    setState(() {
      _pin = next;
      _error = null;
    });
    if (next.length == 4) {
      // إرسال تلقائي عند اكتمال الخانات الأربع
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _submit(next);
      });
    }
  }

  void _deleteDigit() {
    if (_busy || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppPalette.heroGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70, size: 22),
                      tooltip: 'رجوع',
                    ),
                  ),
                  const SizedBox(height: 8),
                  // الشعار
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.gold.withValues(alpha: 0.45),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.grass_rounded,
                        size: 46, color: AppPalette.green),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'دخول الإدارة — ذهب أخضر',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أدخل رمز الدخول المكوّن من 4 أرقام',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // بطاقة الـ PIN
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 380),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // النقاط الأربع
                        AnimatedBuilder(
                          animation: _shake,
                          builder: (context, child) {
                            final dx =
                                _shake.status == AnimationStatus.dismissed
                                    ? 0.0
                                    : _sinOffset(_shake.value);
                            return Transform.translate(
                              offset: Offset(dx, 0),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (i) {
                              final filled = i < _pin.length;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOut,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 9),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: filled
                                      ? AppPalette.green
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _error != null
                                        ? const Color(0xFFDC2626)
                                        : (filled
                                            ? AppPalette.green
                                            : const Color(0xFFCBD8D0)),
                                    width: 2.4,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 20,
                          child: _error == null
                              ? null
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.close_rounded,
                                        size: 14, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 14),
                        // لوحة الأرقام
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          )
                        else ...[
                          _numpadRow(['1', '2', '3']),
                          const SizedBox(height: 12),
                          _numpadRow(['4', '5', '6']),
                          const SizedBox(height: 12),
                          _numpadRow(['7', '8', '9']),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 68, height: 56),
                              const SizedBox(width: 14),
                              _numpadButton('0'),
                              const SizedBox(width: 14),
                              _deleteButton(),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'الجلسة محفوظة على هذا الجهاز فقط',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _sinOffset(double t) =>
      10 * math.sin(t * 3 * math.pi) * (1 - t);

  Widget _numpadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          _numpadButton(digits[i]),
        ],
      ],
    );
  }

  Widget _numpadButton(String digit) {
    return Material(
      color: const Color(0xFFF2F7F3),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _addDigit(digit),
        child: SizedBox(
          width: 68,
          height: 56,
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B3D20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteButton() {
    return Material(
      color: const Color(0xFFF2F7F3),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _deleteDigit,
        child: const SizedBox(
          width: 68,
          height: 56,
          child: Center(
            child: Icon(Icons.backspace_outlined,
                size: 26, color: Color(0xFF0B3D20)),
          ),
        ),
      ),
    );
  }
}
