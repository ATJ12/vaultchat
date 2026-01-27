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
      // Force JSON response type - this is critical!
      responseType: ResponseType.json,
      // Disable automatic type conversion
      validateStatus: (status) => status != null && status < 500,
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
          
          // Debug: Print the actual response data type and content
          Bootstrap.logger.d('Response data type: ${response.data.runtimeType}');
          Bootstrap.logger.d('Response data: ${response.data}');
          
          return handler.next(response);
        },
        onError: (error, handler) {
          Bootstrap.logger.e('✗ ${error.requestOptions.path}', error: error);
          return handler.next(error);
        },
      ),
    );

    // Add transformer to handle JSON properly
    _dio.transformer = BackgroundTransformer();
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