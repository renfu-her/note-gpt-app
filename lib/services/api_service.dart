import 'dart:convert';
import 'dart:io';
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

  Future<bool> isLoggedIn() async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return false;
      
      // 嘗試獲取資料夾列表來驗證 token 是否有效
      await getFolders();
      return true;
    } catch (e) {
      return false;
    }
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
      if (data['error'] != null) {
        throw data['message'];
      }
      
      // 儲存 token
      await _storage.write(key: 'token', value: data['token']);
      return data;
    } catch (e) {
      if (e is DioException && e.response?.data['message'] != null) {
        throw e.response?.data['message'];
      }
      throw '登入失敗';
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

  Future<Folder> createFolder({
    required String name,
    int? parentId,
    String? description,
    int? sortOrder,
    bool isActive = true,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'name': name,
        'parent_id': parentId,
        'description': description ?? '',
        'sort_order': sortOrder ?? 0,
        'is_active': isActive,
      };

      print('Creating folder with data: $data'); // 用於調試

      final response = await _dio.post(
        '/folders',
        data: data,
      );

      print('Response: ${response.data}'); // 用於調試

      if (response.data['message'] == '資料夾建立成功') {
        return Folder.fromJson(response.data['data']);
      } else {
        throw Exception('創建資料夾失敗');
      }
    } catch (e) {
      print('Error creating folder: $e'); // 用於調試
      throw Exception('創建資料夾失敗');
    }
  }

  Future<Map<String, dynamic>> getFolderNotes(int folderId) async {
    print('DEBUG: folderId = $folderId');
    try {
      final response = await _dio.get('/notes/folders/$folderId');
      print('DEBUG: response = ${response.data}');
      
      final data = response.data;
      return {
        'id': data['id'] as int,
        'name': data['name'] as String,
        'notes': (data['notes'] as List).map((note) {
          if (note is Map) {
            return {
              'id': note['id'] as int,
              'title': note['title'] as String,
              'created_at': DateTime.parse(note['created_at']),
            };
          }
          return null;
        }).where((note) => note != null).toList(),
      };
    } catch (e) {
      print('DEBUG: error = $e');
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          throw '找不到此資料夾，可能已被刪除';
        }
        throw e.response?.data?['message'] ?? '載入資料夾失敗';
      }
      throw '載入資料夾失敗：$e';
    }
  }

  Future<Map<String, dynamic>> getNote(int noteId) async {
    try {
      final response = await _dio.get('/notes/$noteId');
      final data = response.data['data'];
      return {
        'id': data['id'] as int,
        'title': data['title'] as String,
        'content': data['content'] as String,
        'created_at': DateTime.parse(data['created_at']),
      };
    } catch (e) {
      throw Exception('獲取筆記失敗');
    }
  }

  Future<void> logout() async {
    try {
      // 獲取當前的 token
      final token = await _storage.read(key: 'token');
      if (token == null) {
        throw '未找到認證 Token';
      }

      try {
        // 嘗試調用登出 API
        await _dio.get('/logout');
      } catch (e) {
        // 忽略 API 錯誤
        print('登出 API 調用失敗：$e');
      }
    } finally {
      // 無論如何都清除本地儲存的 token
      await _storage.delete(key: 'token');
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _authDio.post(
        '/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );
      
      if (response.data['error'] != null) {
        throw response.data['message'];
      }
    } catch (e) {
      if (e is DioException && e.response?.data['message'] != null) {
        throw e.response?.data['message'];
      }
      throw '註冊失敗';
    }
  }

  Future<Map<String, dynamic>> createNote({
    required int folderId,
    required String title,
    String? content,
    File? file,
  }) async {
    try {
      final formData = FormData.fromMap({
        'folder_id': folderId,
        'title': title,
        if (content != null) 'content': content,
        if (file != null)
          'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
      });
      final response = await _dio.post(
        '/notes',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (response.data['error'] != null) {
        throw response.data['message'];
      }
      return {
        'id': response.data['data']['id'] as int,
        'title': response.data['data']['title'] as String,
        'content': response.data['data']['content'] as String,
        'created_at': DateTime.parse(response.data['data']['created_at']),
      };
    } catch (e) {
      if (e is DioException && e.response?.data['message'] != null) {
        throw e.response?.data['message'];
      }
      throw '創建筆記失敗';
    }
  }

  Future<Map<String, dynamic>> updateNote({
    required int noteId,
    required String title,
    String? content,
    File? file,
  }) async {
    try {
      if (file != null) {
        final formData = FormData.fromMap({
          'title': title,
          if (content != null) 'content': content,
          'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
        });
        final response = await _dio.post(
          '/notes/$noteId',
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
        if (response.data['error'] != null) {
          throw response.data['message'];
        }
        return {
          'id': response.data['data']['id'] as int,
          'title': response.data['data']['title'] as String,
          'content': response.data['data']['content'] as String,
          'created_at': DateTime.parse(response.data['data']['created_at']),
        };
      } else {
        final data = {
          'title': title,
          if (content != null) 'content': content,
        };
        final response = await _dio.post(
          '/notes/$noteId',
          data: data,
          options: Options(contentType: 'application/json'),
        );
        if (response.data['error'] != null) {
          throw response.data['message'];
        }
        return {
          'id': response.data['data']['id'] as int,
          'title': response.data['data']['title'] as String,
          'content': response.data['data']['content'] as String,
          'created_at': DateTime.parse(response.data['data']['created_at']),
        };
      }
    } catch (e) {
      if (e is DioException && e.response?.data['message'] != null) {
        throw e.response?.data['message'];
      }
      throw '更新筆記失敗';
    }
  }

  Future<void> deleteFolder(int folderId) async {
    final token = await _storage.read(key: 'token');
    if (token == null) {
      throw '未登入';
    }

    try {
      final response = await _dio.delete(
        '/folders/$folderId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw '刪除資料夾失敗';
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          throw '沒有權限刪除此資料夾';
        }
        throw e.response?.data?['message'] ?? '刪除資料夾失敗';
      }
      throw '刪除資料夾失敗：$e';
    }
  }
} 