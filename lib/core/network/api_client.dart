import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/storage/token_storage.dart';

typedef Json = Map<String, dynamic>;

/// Cliente HTTP da API do Yvenist.
///
/// Concentra o que toda chamada precisa: JSON, cabeçalho de autenticação,
/// renovação da sessão quando o token de acesso expira e tradução de erros
/// para [AppFailure]. Os repositórios só dizem *o que* pedir.
class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required TokenStorage tokenStorage,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  })  : _baseUrl = baseUrl,
        _tokens = tokenStorage,
        _http = httpClient ?? http.Client();

  final Uri _baseUrl;
  final TokenStorage _tokens;
  final http.Client _http;
  final Duration timeout;

  /// Chamado quando a sessão acabou e não pôde ser renovada.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  Future<Object?> get(
    String path, {
    Map<String, String?> query = const {},
    bool authenticated = false,
  }) {
    return _send('GET', path, query: query, authenticated: authenticated);
  }

  Future<Object?> post(String path, {Object? body, bool authenticated = false}) {
    return _send('POST', path, body: body, authenticated: authenticated);
  }

  Future<Object?> put(String path, {Object? body, bool authenticated = false}) {
    return _send('PUT', path, body: body, authenticated: authenticated);
  }

  Future<Object?> patch(String path, {Object? body, bool authenticated = false}) {
    return _send('PATCH', path, body: body, authenticated: authenticated);
  }

  Future<Object?> delete(String path, {bool authenticated = false}) {
    return _send('DELETE', path, authenticated: authenticated);
  }

  void close() => _http.close();

  // ------------------------------------------------------------------

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Object? body,
    required bool authenticated,
  }) async {
    var response = await _execute(
      method,
      path,
      query: query,
      body: body,
      authenticated: authenticated,
    );

    if (response.statusCode == 401 && authenticated) {
      // O token de acesso dura poucos minutos; renova e tenta de novo uma vez.
      if (!await _refreshSession()) {
        onSessionExpired?.call();
        throw const UnauthorizedFailure();
      }
      response = await _execute(
        method,
        path,
        query: query,
        body: body,
        authenticated: true,
      );
      if (response.statusCode == 401) {
        await _tokens.clear();
        onSessionExpired?.call();
        throw const UnauthorizedFailure();
      }
    }

    return _decode(response);
  }

  Future<http.Response> _execute(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Object? body,
    required bool authenticated,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (authenticated) {
      final tokens = await _tokens.read();
      if (tokens == null) throw const UnauthorizedFailure();
      headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }

    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const NetworkFailure();
    } on http.ClientException {
      // Cobre falha de conexão em todas as plataformas (inclusive web).
      throw const NetworkFailure();
    }
  }

  Uri _uri(String path, Map<String, String?> query) {
    final parameters = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };
    return _baseUrl.replace(
      path: '${_baseUrl.path}$path',
      queryParameters: parameters.isEmpty ? null : parameters,
    );
  }

  /// Garante uma única renovação em andamento: várias chamadas que recebem 401
  /// ao mesmo tempo esperam a mesma. Renovar duas vezes com o mesmo token faria
  /// o servidor tratar como reuso e encerrar a sessão.
  Future<bool> _refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final tokens = await _tokens.read();
    if (tokens == null) return false;

    // Falha de rede aqui propaga como NetworkFailure e NÃO apaga a sessão:
    // estar offline não é o mesmo que ter a sessão encerrada.
    final response = await _execute(
      'POST',
      '/auth/refresh',
      body: {'refresh_token': tokens.refreshToken},
      authenticated: false,
    );

    if (response.statusCode == 200) {
      final json = _decodeBody(response) as Json;
      await _tokens.write(AuthTokens.fromJson(json['tokens'] as Json));
      return true;
    }
    // Servidor instável ou limite de requisições: problema passageiro, a
    // sessão continua guardada para uma próxima tentativa.
    if (response.statusCode >= 500 || response.statusCode == 429) {
      throw _failureFor(response);
    }
    // O servidor recusou o token de renovação: a sessão acabou de verdade.
    await _tokens.clear();
    return false;
  }

  Object? _decode(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return _decodeBody(response);
    throw _failureFor(response);
  }

  Object? _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ServerFailure();
    }
  }

  AppFailure _failureFor(http.Response response) {
    final error = _errorBody(response);
    final code = error?['code'] as String?;
    final message = error?['message'] as String?;

    switch (response.statusCode) {
      case 400 || 422:
        return ValidationFailure(
          message ?? 'Confira os dados informados.',
          code: code ?? 'validation_error',
          fieldErrors: _fieldErrors(error),
        );
      case 401:
        return message == null
            ? const UnauthorizedFailure()
            : UnauthorizedFailure(message, code);
      case 403:
        return message == null
            ? const ForbiddenFailure()
            : ForbiddenFailure(message, code);
      case 404:
        return message == null
            ? const NotFoundFailure()
            : NotFoundFailure(message, code);
      case 409:
        return message == null
            ? const ConflictFailure()
            : ConflictFailure(message, code);
      case 429:
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        final retryAfter = seconds == null ? null : Duration(seconds: seconds);
        return message == null
            ? RateLimitedFailure(const RateLimitedFailure().message, retryAfter)
            : RateLimitedFailure(message, retryAfter);
      default:
        return const ServerFailure();
    }
  }

  Json? _errorBody(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Json && decoded['error'] is Json) {
        return decoded['error'] as Json;
      }
    } on FormatException {
      // Corpo que não é JSON (proxy, página de erro): usa a mensagem padrão.
    }
    return null;
  }

  Map<String, String> _fieldErrors(Json? error) {
    final details = error?['details'];
    if (details is! Json || details['fields'] is! List) return const {};

    final result = <String, String>{};
    for (final entry in details['fields'] as List) {
      if (entry is Json && entry['field'] is String && entry['message'] is String) {
        result[entry['field'] as String] = entry['message'] as String;
      }
    }
    return result;
  }
}
