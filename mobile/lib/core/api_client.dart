// ============================================================
// GREEN GOLD | عميل HTTP الموحد (dio)
// - أخطاء عربية دائمًا
// - يرفق x-staff-pin تلقائيًا عند توفر جلسة موظف
// - مهلات مناسبة لضعف الإنترنت
// ============================================================

import 'package:dio/dio.dart';

/// خطأ API موحد برسالة عربية وكود حالة
class ApiException implements Exception {
  final String message;
  final int status;

  ApiException(this.message, this.status);

  bool get isUnauthorized => status == 401;
  bool get isAuthExpiry =>
      status == 401 && (message.contains('PIN') || message.contains('تسجيل دخول'));

  @override
  String toString() => message;
}

class ApiClient {
  final Dio dio;
  final String baseUrl;

  ApiClient({
    required this.baseUrl,
    String? staffPin,
  }) : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          // مهلات قصيرة نسبيًا: على الشبكة الضعيفة نفشل سريعًا
          // ونعرض النسخة المحفوظة بدل انتظار طويل
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          responseType: ResponseType.json,
          headers: {
            'Content-Type': 'application/json',
            if (staffPin != null && staffPin.isNotEmpty)
              'x-staff-pin': staffPin,
          },
        )) {
    dio.interceptors.add(LogInterceptor(
      logPrint: (o) {}, // صمت — لا سجلات في الإنتاج
      requestBody: false,
      responseBody: false,
    ));
  }

  dynamic _unwrap(Response<dynamic> res) {
    final data = res.data;
    if (data is Map<String, dynamic> && data.containsKey('error')) {
      final err = data['error'];
      if (err is String && err.isNotEmpty && res.statusCode != null && res.statusCode! >= 400) {
        throw ApiException(err, res.statusCode ?? 500);
      }
    }
    return data;
  }

  Exception _mapError(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final res = e.response;
      if (res != null) {
        final data = res.data;
        if (data is Map<String, dynamic>) {
          final err = data['error'];
          if (err is String && err.isNotEmpty) {
            return ApiException(err, res.statusCode ?? 500);
          }
        }
        if (res.statusCode == 401) {
          return ApiException('انتهت الجلسة، سجّل الدخول من جديد', 401);
        }
        if (res.statusCode != null && res.statusCode! >= 500) {
          return ApiException('خطأ في الخادم، حاول مرة أخرى', res.statusCode ?? 500);
        }
        return ApiException('حدث خطأ غير متوقع، حاول مرة أخرى', res.statusCode ?? 500);
      }
      return ApiException('تعذر الاتصال بالخادم، تحقق من اتصالك بالإنترنت', 0);
    }
    return ApiException('حدث خطأ غير متوقع، حاول مرة أخرى', 0);
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      final res = await dio.get(path, queryParameters: queryParameters);
      return _unwrap(res);
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<dynamic> post(String path, {Object? body}) async {
    try {
      final res = await dio.post(path, data: body ?? {});
      return _unwrap(res);
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    try {
      final res = await dio.patch(path, data: body ?? {});
      return _unwrap(res);
    } catch (e) {
      throw _mapError(e);
    }
  }
}
