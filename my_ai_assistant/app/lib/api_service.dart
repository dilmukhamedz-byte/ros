import 'dart:convert';
import 'package:dio/dio.dart';
import 'config.dart';
import 'models.dart';

enum ErrKind { offline, timeout, server }

class ApiException implements Exception {
  final String message;
  final ErrKind kind;
  ApiException(this.message, this.kind);
  @override
  String toString() => message;
}

class ApiService {
  final String deviceId;
  late final Dio _dio;

  ApiService(this.deviceId) {
    _dio = Dio(BaseOptions(
      baseUrl: kApiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'x-device-id': deviceId},
    ));
  }

  ApiException _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Превышено время ожидания ответа', ErrKind.timeout);
      case DioExceptionType.connectionError:
        return ApiException('Нет подключения к интернету или серверу', ErrKind.offline);
      default:
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          return ApiException(data['error'].toString(), ErrKind.server);
        }
        return ApiException('Ошибка сервера (${e.response?.statusCode ?? '?'})', ErrKind.server);
    }
  }

  String _errText(String body) {
    try {
      return jsonDecode(body)['error'].toString();
    } catch (_) {
      return 'Ошибка сервера';
    }
  }

  /// Потоковый ответ: выдаёт куски текста по мере поступления (SSE).
  Stream<String> chatStream(String message, String conversationId, String role) async* {
    Response<ResponseBody> res;
    try {
      res = await _dio.post<ResponseBody>(
        '/api/chat/stream',
        data: {'message': message, 'conversationId': conversationId, 'role': role},
        options: Options(responseType: ResponseType.stream, validateStatus: (_) => true),
      );
    } on DioException catch (e) {
      throw _map(e);
    }
    final bytes = res.data!.stream.cast<List<int>>();
    if (res.statusCode != 200) {
      final body = await utf8.decoder.bind(bytes).join();
      throw ApiException(_errText(body), ErrKind.server);
    }
    try {
      final lines = utf8.decoder.bind(bytes).transform(const LineSplitter());
      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final j = jsonDecode(line.substring(6));
        if (j['error'] != null) throw ApiException(j['error'], ErrKind.server);
        if (j['delta'] != null) yield j['delta'] as String;
      }
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<List<Conversation>> conversations() async {
    try {
      final r = await _dio.get('/api/conversations');
      return (r.data['conversations'] as List).map((e) => Conversation.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<List<ChatMessage>> messages(String id) async {
    try {
      final r = await _dio.get('/api/conversations/$id/messages');
      return (r.data['messages'] as List).map((e) => ChatMessage.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _dio.delete('/api/conversations/$id');
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Map<String, dynamic>> adminStats(String key) async {
    try {
      final r = await _dio.get('/api/admin/stats', options: Options(headers: {'x-admin-key': key}));
      return Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      throw _map(e);
    }
  }
}
