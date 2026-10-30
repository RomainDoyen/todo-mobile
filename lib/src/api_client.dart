import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, this.status);

  final String message;
  final int status;

  bool get offline => status == 0;

  bool get serverDown => offline || status == 502 || status == 503 || status == 504;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.baseUrl);

  String baseUrl;

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) {
    return _send('GET', path, token: token, query: query);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    String? token,
    Object? body,
  }) {
    return _send('POST', path, token: token, body: body);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Object? body,
    Map<String, String>? query,
  }) async {
    final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$root$path').replace(queryParameters: query);
    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    Object? encoded = body;
    if (body != null) {
      headers['Content-Type'] = 'application/json';
      encoded = jsonEncode(body);
    }

    http.Response response;
    try {
      final request = http.Request(method, uri);
      request.headers.addAll(headers);
      if (encoded != null) request.body = encoded as String;
      final streamed = await request.send().timeout(const Duration(seconds: 25));
      response = await http.Response.fromStream(streamed);
    } catch (error) {
      throw ApiException('Hors ligne', 0);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Erreur ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {}
      throw ApiException(message, response.statusCode);
    }

    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw ApiException('Réponse inattendue', response.statusCode);
  }
}
