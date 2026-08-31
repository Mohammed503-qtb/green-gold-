// ============================================================
// GREEN GOLD | بوابة الاتصال — تظهر فقط عندما لا يوجد عنوان
// خادم إطلاقًا (نسخة APK بلا عنوان مضمّن ولم يضبطه أحد بعد).
// ------------------------------------------------------------
// المستخدم العادي لا يرى أي إعدادات تقنية هنا — رسالة واضحة
// «تواصل مع إدارة المتجر». مدخل الضبط مخفي:
// 5 نقرات على الشعار ← شاشة إعداد الخادم (للإدارة فقط).
// ============================================================

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../shared/widgets.dart';
import 'server_setup_screen.dart';

class ConnectionGateScreen extends StatelessWidget {
  const ConnectionGateScreen({super.key});

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
                  // الشعار — مدخل الضبط المخفي (5 نقرات)
                  SecretTapArea(
                    onTriggered: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ServerSetupScreen()),
                    ),
                    child: Container(
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
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 380),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 44,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'التطبيق غير مهيأ بعد',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'لم يتم ضبط خادم المتجر على هذا الجهاز.\nتواصل مع إدارة المتجر لإكمال الإعداد.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.7,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'الإصدار 1.0.3 — ذهب أخضر للتجارة',
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
