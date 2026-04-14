import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'token_storage.dart';

class AuthApiException implements Exception {
  AuthApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthApiService {
  AuthApiService({TokenStorage? storage}) : _storage = storage ?? TokenStorage.instance;

  final TokenStorage _storage;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final res = await http.post(
      _uri('/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      }),
    );
    return _handleAuthResponse(res);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _uri('/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleAuthResponse(res);
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final res = await http.post(
      _uri('/auth/google'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    return _handleAuthResponse(res);
  }

  Future<void> requestPasswordReset(String email) async {
    final res = await http.post(
      _uri('/auth/forgot-password'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );
    _ensureSuccess(res);
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final res = await http.post(
      _uri('/auth/reset-password'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token.trim(),
        'password': newPassword,
      }),
    );
    _ensureSuccess(res);
  }

  void _ensureSuccess(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    Map<String, dynamic> body;
    try {
      body = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
    } on Object {
      body = <String, dynamic>{};
    }

    final err = body['error'] as String? ?? 'Request failed';
    throw AuthApiException(err, res.statusCode);
  }

  Future<Map<String, dynamic>> _handleAuthResponse(http.Response res) async {
    Map<String, dynamic> body;
    try {
      body = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
    } on Object {
      body = <String, dynamic>{};
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = body['token'] as String?;
      if (token != null && token.isNotEmpty) {
        await _storage.saveToken(token);
      }
      return body;
    }

    final err = body['error'] as String? ?? 'Request failed';
    throw AuthApiException(err, res.statusCode);
  }

  Future<void> signOut() async {
    await _storage.clearToken();
  }

  Future<Map<String, dynamic>?> fetchMe() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return null;

    final res = await http.get(
      _uri('/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) return null;
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }
}
