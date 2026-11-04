import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code = 'error', this.status = 0});

  final String message;
  final String code;
  final int status;

  bool get isUnauthorized => status == 401;
  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

/// Cliente HTTP fino, com token Bearer e tradução de erros da API.
class ApiClient {
  ApiClient({http.Client? httpClient, this.baseUrl = apiBaseUrl})
    : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  String? token;

  Uri resolveUri(String path) {
    final uri = Uri.parse(path);
    return uri.hasScheme ? uri : Uri.parse(baseUrl).resolve(path);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: path,
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers['accept'] = 'application/json';
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    http.Response response;
    try {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 30));
      response = await http.Response.fromStream(streamed);
    } on Exception {
      throw const ApiException(
        'Não foi possível ligar ao servidor. Verifique a rede e tente novamente.',
        code: 'network',
      );
    }

    Map<String, dynamic> decoded = const {};
    if (response.body.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) decoded = parsed;
      } on FormatException {
        throw ApiException(
          'Resposta inválida do servidor.',
          status: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 400) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          error['message'] as String? ?? 'Ocorreu um erro.',
          code: error['code'] as String? ?? 'error',
          status: response.statusCode,
        );
      }
      throw ApiException(
        'Ocorreu um erro (${response.statusCode}).',
        status: response.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => send('POST', path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => send('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => send('DELETE', path);
}
