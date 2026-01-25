import 'package:dio/dio.dart';
import '../../app/bootstrap.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  static ApiClient get instance => _instance;
  
  late final Dio _dio;
  
  // Change this to your backend URL
  static const baseUrl = 'http://127.0.0.1:8000';
  
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          Bootstrap.logger.d('→ ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          Bootstrap.logger.d('← ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (error, handler) {
          Bootstrap.logger.e('✗ ${error.requestOptions.path}', error: error);
          return handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}