import 'package:dio/dio.dart';
import '../data/api.dart';
import 'token_storage.dart';

class ApiClient {
  final TokenStorage tokenStorage;

  late final Dio dio;

  ApiClient({required this.tokenStorage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: Api.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {"Content-Type": "application/json"},
      ),
    );
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        requestHeader: true,
        error: true,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isAuthEndpoint = _isAuthEndpoint(options.path);

          if (!isAuthEndpoint) {
            final access = await tokenStorage.readAccess();
            if (access != null && access.isNotEmpty) {
              options.headers["Authorization"] = "Bearer $access";
            }
          }

          handler.next(options);
        },
        onError: (e, handler) async {
          final status = e.response?.statusCode;

          final isAuthEndpoint = _isAuthEndpoint(e.requestOptions.path);

          if (status == 401 && !isAuthEndpoint) {
            final data = e.requestOptions.data;
            final isFormData = data is FormData;
            if (isFormData) return handler.next(e);
            final refreshed = await _tryRefreshToken();

            if (refreshed) {
              try {
                final newAccess = await tokenStorage.readAccess();
                final headers = Map<String, dynamic>.from(
                  e.requestOptions.headers,
                );
                if (newAccess != null && newAccess.isNotEmpty) {
                  headers["Authorization"] = "Bearer $newAccess";
                }

                final cloneResponse = await dio.request(
                  e.requestOptions.path,
                  data: e.requestOptions.data,
                  queryParameters: e.requestOptions.queryParameters,
                  options: Options(
                    method: e.requestOptions.method,
                    headers: headers,
                    responseType: e.requestOptions.responseType,
                    contentType: e.requestOptions.contentType,
                    followRedirects: e.requestOptions.followRedirects,
                    validateStatus: e.requestOptions.validateStatus,
                    receiveDataWhenStatusError:
                        e.requestOptions.receiveDataWhenStatusError,
                  ),
                );

                return handler.resolve(cloneResponse);
              } catch (retryError) {
                if (retryError is DioException) return handler.next(retryError);
                return handler.next(e);
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) {
    return dio.get(path, queryParameters: query);
  }

  Future<Response> postFormData(String path, {required FormData data}) {
    return dio.post(
      path,
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return dio.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return dio.delete(path);
  }

  bool _isAuthEndpoint(String path) {
    return path.contains(Api.login) ||
        path.contains(Api.refresh) ||
        path.contains(Api.register);
  }

  Future<bool> _tryRefreshToken() async {
    final refresh = await tokenStorage.readRefresh();
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final r = await dio.post(Api.refresh, data: {"refresh": refresh});
      final newAccess = r.data["access"] as String?;
      if (newAccess == null || newAccess.isEmpty) return false;

      // refresh може не повертати refresh, тому зберігаємо старий
      await tokenStorage.saveTokens(access: newAccess, refresh: refresh);
      return true;
    } catch (_) {
      await tokenStorage.clear();
      return false;
    }
  }
}
