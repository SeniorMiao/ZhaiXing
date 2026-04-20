import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../config/app_config.dart';
import '../models/api_models.dart';

String _formatDetail(dynamic detail) {
  if (detail == null) return '请求失败';
  if (detail is String) return detail;
  if (detail is List) {
    return detail.map((e) {
      if (e is Map && e['msg'] != null) return e['msg'].toString();
      return e.toString();
    }).join('\n');
  }
  return detail.toString();
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl, String? Function()? tokenGetter})
      : _tokenGetter = tokenGetter {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = _tokenGetter?.call();
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          return handler.next(options);
        },
      ),
    );
  }

  final String? Function()? _tokenGetter;
  late final Dio _dio;

  Future<AuthResult> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/register',
        data: {
          'email': email,
          'password': password,
          if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        },
      );
      return AuthResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthResult> login({required String email, required String password}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthResult.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<UserInfo> me() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/auth/me');
      return UserInfo.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// 当前用户头像二进制（需已登录且服务端存在头像）。
  Future<Uint8List?> getMyAvatarBytes() async {
    try {
      final res = await _dio.get<List<int>>(
        '/v1/auth/avatar',
        options: Options(responseType: ResponseType.bytes),
      );
      final list = res.data;
      if (list == null) return null;
      return Uint8List.fromList(list);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _mapDio(e);
    }
  }

  Future<UserInfo> uploadAvatar(String filePath) async {
    final name = p.basename(filePath);
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: name),
    });
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/avatar',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 2),
        ),
      );
      return UserInfo.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<UserInfo> deleteAvatar() async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>('/v1/auth/avatar');
      return UserInfo.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<MeetingItem>> listMeetings({int limit = 50}) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/v1/meetings',
        queryParameters: {'limit': limit},
      );
      return (res.data ?? []).map((e) => MeetingItem.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<MeetingDetail> createMeeting({required String meetingType, String? title}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/meetings',
        data: {
          'meeting_type': meetingType,
          if (title != null && title.isNotEmpty) 'title': title,
        },
      );
      return MeetingDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<MeetingDetail> getMeeting(int id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/meetings/$id');
      return MeetingDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<MeetingDetail> uploadMedia(int meetingId, String filePath) async {
    final name = p.basename(filePath);
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: name),
      'chunk_index': 0,
      'total_chunks': 1,
    });
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/meetings/$meetingId/upload',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
      return MeetingDetail.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<int> processMeeting(int meetingId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/v1/meetings/$meetingId/process');
      return res.data!['job_id'] as int;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<JobStatus> getJob(int jobId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/jobs/$jobId');
      return JobStatus.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<MeetingTranscript> getTranscript(int meetingId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/meetings/$meetingId/transcript');
      return MeetingTranscript.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<MeetingSummary> getSummary(int meetingId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/meetings/$meetingId/summary');
      return MeetingSummary.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    String msg = e.message ?? '网络错误';
    if (data is Map && data['detail'] != null) {
      msg = _formatDetail(data['detail']);
    }
    return ApiException(msg, statusCode: code);
  }
}
