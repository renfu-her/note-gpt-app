import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/folder.dart';
import '../models/note.dart';

class ApiService {
  static const String baseUrl = 'https://note-db.case-studio.site/api';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio = Dio();
  final Dio _authDio = Dio(); // 專門用於認證的 Dio 實例

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _authDio.options.baseUrl = baseUrl;
    _setupInterceptors();
  }

  void _setupInterceptors() {
    // 為主要的 dio 實例添加認證攔截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 獲取 token
          final token = await _storage.read(key: 'token');
          if (token == null) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: '未找到認證 Token',
              ),
            );
          }
          // 添加 Bearer Token
          options.headers['Authorization'] = 'Bearer $token';
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              // 嘗試刷新 Token
              await refreshToken();
              // 重試原始請求
              final token = await _storage.read(key: 'token');
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              // 如果刷新失敗，清除 token 並拒絕請求
              await _storage.delete(key: 'token');
              return handler.reject(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // 使用不帶認證的 dio 實例進行登入
      final response = await _authDio.post(
        '/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      final data = response.data;
      await _storage.write(key: 'token', value: data['token']);
      return data;
    } catch (e) {
      throw Exception('登入失敗');
    }
  }

  Future<void> refreshToken() async {
    try {
      final currentToken = await _storage.read(key: 'token');
      if (currentToken == null) {
        throw Exception('未找到 Token');
      }

      final response = await _authDio.post(
        '/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $currentToken'},
        ),
      );
      
      final data = response.data;
      await _storage.write(key: 'token', value: data['token']);
    } catch (e) {
      throw Exception('刷新 Token 失敗');
    }
  }

  Future<List<Folder>> getFolders() async {
    try {
      final response = await _dio.get('/folders');
      return (response.data as List)
          .map((json) => Folder.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('獲取資料夾列表失敗');
    }
  }

  Future<Map<String, dynamic>> getFolderNotes(int folderId) async {
    try {
      final response = await _dio.get('/notes/folders/$folderId');
      return {
        'id': response.data['id'] as int,
        'name': response.data['name'] as String,
        'parent_id': response.data['parent_id'] as int,
        'is_active': response.data['is_active'] as int,
        'notes': List<Note>.from(
          (response.data['notes'] as List).map((note) => Note.fromJson(note)),
        ),
      };
    } catch (e) {
      throw Exception('獲取資料夾筆記失敗');
    }
  }

  Future<Note> getNote(int noteId) async {
    try {
      final response = await _dio.get('/notes/$noteId');
      return Note.fromJson(response.data['data']);
    } catch (e) {
      throw Exception('獲取筆記失敗');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/logout');
    } finally {
      await _storage.delete(key: 'token');
    }
  }
} 