import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'token_storage.dart';

class ExpenseApiService {
  ExpenseApiService({TokenStorage? storage}) : _storage = storage ?? TokenStorage.instance;

  final TokenStorage _storage;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<List<Map<String, dynamic>>> listExpenses() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return [];

    final res = await http.get(
      _uri('/expenses'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) return [];
    try {
      final decoded = jsonDecode(res.body) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on Object {
      return [];
    }
  }

  Future<void> createExpense({
    required double amount,
    String currency = 'TRY',
    String? note,
  }) async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('Not signed in');
    }

    final res = await http.post(
      _uri('/expenses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'amount': amount,
        'currency': currency,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic> body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } on Object {
        body = <String, dynamic>{};
      }
      throw Exception(body['error'] ?? 'Failed to create expense');
    }
  }
}
