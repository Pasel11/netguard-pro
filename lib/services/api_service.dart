import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../storage/hive_service.dart';

enum ApiErrorType {
  network,
  server,
  timeout,
  parse,
  unknown,
}

class ApiException implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;

  ApiException(this.type, this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  // غيّر هذا الرابط لـ backend الخاص بك
  static const String baseUrl = 'https://your-app-name.vercel.app';
  
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ))..interceptors.addAll([
    _authInterceptor(),
    _logInterceptor(),
    _retryInterceptor(),
  ]);
  
  static final HiveService _hive = HiveService();
  
  // ===== Interceptors =====
  static Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // يمكن إضافة توكن مصادقة هنا
        handler.next(options);
      },
    );
  }
  
  static Interceptor _logInterceptor() {
    return LogInterceptor(
      request: true,
      requestHeader: false,
      responseHeader: false,
      responseBody: true,
      error: true,
      logPrint: (obj) {
        // استخدم logger في الإنتاج
        // ignore: avoid_print
        print('[API] $obj');
      },
    );
  }
  
  static Interceptor _retryInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        final maxRetries = 2;
        final retryCount = error.requestOptions.extra['retryCount'] ?? 0;
        
        if (retryCount < maxRetries && _isRetryable(error)) {
          error.requestOptions.extra['retryCount'] = retryCount + 1;
          
          // انتظار قبل إعادة المحاولة (exponential backoff)
          await Future.delayed(Duration(seconds: 1 << retryCount));
          
          try {
            final response = await _dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } catch (e) {
            handler.next(error);
            return;
          }
        }
        handler.next(error);
      },
    );
  }
  
  static bool _isRetryable(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        (error.response?.statusCode ?? 0) >= 500;
  }
  
  // ===== Network Check =====
  static Future<bool> hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }
  
  static Future<void> _ensureConnection() async {
    if (!await hasConnection()) {
      throw ApiException(
        ApiErrorType.network,
        'No internet connection. Please check your network.',
      );
    }
  }
  
  // ===== Network Info =====
  static Future<NetworkInfo> getNetworkInfo({bool useCache = true}) async {
    if (useCache) {
      final cached = await _hive.getCachedData('network_info',
          maxAge: const Duration(minutes: 5));
      if (cached != null) {
        return NetworkInfo.fromJson(cached);
      }
    }
    
    await _ensureConnection();
    try {
      final response = await _dio.get('/api/network/info');
      if (response.data['success']) {
        final data = response.data['data'];
        await _hive.cacheData('network_info', data);
        return NetworkInfo.fromJson(data);
      }
      throw ApiException(ApiErrorType.parse, 'Failed to parse network info');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  // ===== Port Scanner =====
  static Future<PortScanResult> scanPorts(String targetIp, {List<int>? ports}) async {
    await _ensureConnection();
    try {
      final response = await _dio.post('/api/scan/ports', data: {
        'targetIp': targetIp,
        if (ports != null) 'ports': ports,
      });
      if (response.data['success']) {
        return PortScanResult.fromJson(response.data['data']);
      }
      throw ApiException(ApiErrorType.parse, 'Failed to parse port scan result');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  // ===== Password Analyzer =====
  static Future<PasswordAnalysis> analyzePassword(String password) async {
    await _ensureConnection();
    try {
      final response = await _dio.post('/api/analyze/password', data: {
        'password': password,
      });
      if (response.data['success']) {
        return PasswordAnalysis.fromJson(response.data['data']);
      }
      throw ApiException(ApiErrorType.parse, 'Failed to parse password analysis');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  // ===== CVE Database =====
  static Future<List<CVE>> getCVEs({String? vendor, String? model}) async {
    if (vendor == null && model == null) {
      // نحاول الكاش أولاً
      final cached = await _hive.getCachedData('all_cves',
          maxAge: const Duration(hours: 1));
      if (cached != null) {
        return (cached['data'] as List)
            .map((e) => CVE.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    
    await _ensureConnection();
    try {
      Response response;
      if (vendor != null || model != null) {
        response = await _dio.post('/api/cve/lookup', data: {
          if (vendor != null) 'vendor': vendor,
          if (model != null) 'model': model,
        });
      } else {
        response = await _dio.get('/api/cve/lookup');
      }
      
      if (response.data['success']) {
        final cves = (response.data['data'] as List)
            .map((e) => CVE.fromJson(e as Map<String, dynamic>))
            .toList();
        
        // حفظ في الكاش لو كان fetch لكل الـ CVEs
        if (vendor == null && model == null) {
          await _hive.cacheData('all_cves', {
            'data': response.data['data'],
          });
        }
        return cves;
      }
      throw ApiException(ApiErrorType.parse, 'Failed to parse CVEs');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  // ===== Router Detector =====
  static Future<RouterInfo> detectRouter(String routerIp) async {
    await _ensureConnection();
    try {
      final response = await _dio.post('/api/router/detect', data: {
        'routerIp': routerIp,
      });
      if (response.data['success']) {
        return RouterInfo.fromJson(response.data['data']);
      }
      throw ApiException(ApiErrorType.parse, 'Failed to parse router info');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  // ===== WPS PIN Calculator =====
  static Future<WPSResult> calculateWPS(String macAddress) async {
    await _ensureConnection();
    try {
      final response = await _dio.post('/api/wps/calculate', data: {
        'macAddress': macAddress,
      });
      if (response.data['success']) {
        return WPSResult.fromJson(response.data['data']);
      }
      throw ApiException(ApiErrorType.parse, 'Failed to parse WPS result');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  // ===== WiFi Signal Analyzer =====
  static Future<Map<String, dynamic>> analyzeWifiSignal(
      Map<String, dynamic> connectionInfo) async {
    await _ensureConnection();
    try {
      final response = await _dio.post('/api/wifi/signal', data: {
        'connectionInfo': connectionInfo,
      });
      if (response.data['success']) {
        return response.data['data'];
      }
      throw ApiException(ApiErrorType.parse, 'Failed to parse WiFi signal');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  // ===== Security Report Generator =====
  static Future<Map<String, dynamic>> generateReport(
      Map<String, dynamic> scanResults) async {
    await _ensureConnection();
    try {
      final response = await _dio.post('/api/report/generate', data: {
        'scanResults': scanResults,
      });
      if (response.data['success']) {
        return response.data['data'];
      }
      throw ApiException(ApiErrorType.parse, 'Failed to parse report');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  // ===== Error Handler =====
  static ApiException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          ApiErrorType.timeout,
          'Connection timeout. Please try again.',
        );
      case DioExceptionType.connectionError:
        return ApiException(
          ApiErrorType.network,
          'No internet connection.',
        );
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        String message = 'Server error';
        if (e.response?.data is Map) {
          message = e.response?.data['error'] ?? message;
        }
        return ApiException(
          ApiErrorType.server,
          message,
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return ApiException(
          ApiErrorType.unknown,
          'Request was cancelled',
        );
      case DioExceptionType.badCertificate:
        return ApiException(
          ApiErrorType.network,
          'SSL certificate error',
        );
      case DioExceptionType.unknown:
      default:
        return ApiException(
          ApiErrorType.unknown,
          e.message ?? 'Unknown error occurred',
        );
    }
  }
}
