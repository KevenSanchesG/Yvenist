import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/core/storage/token_storage.dart';

/// Resposta JSON em UTF-8, como a API devolve.
http.Response jsonResponse(Object? body, {int status = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Resposta de erro no formato padrão da API.
http.Response errorResponse(int status, String code, String message) {
  return jsonResponse({
    'error': {'code': code, 'message': message},
  }, status: status);
}

/// Uma API de mentira para testar os repositórios: cada teste diz o que cada
/// rota responde e depois confere o que foi pedido.
class FakeApi {
  FakeApi({
    AuthTokens? tokens = const AuthTokens(
      accessToken: 'acesso',
      refreshToken: 'renovacao',
    ),
  }) : storage = InMemoryTokenStorage(tokens) {
    client = ApiClient(
      baseUrl: Uri.parse('https://api.test$_prefix'),
      tokenStorage: storage,
      httpClient: MockClient(_handle),
    );
  }

  static const String _prefix = '/api/v1';

  final InMemoryTokenStorage storage;
  late final ApiClient client;
  final List<http.Request> requests = [];
  final Map<String, http.Response Function(http.Request)> _routes = {};

  /// Define a resposta de uma rota, calculada a partir da requisição.
  void on(
    String method,
    String path,
    http.Response Function(http.Request request) handler,
  ) {
    _routes['$method $path'] = handler;
  }

  /// Define uma resposta JSON fixa para uma rota.
  void reply(String method, String path, Object? body, {int status = 200}) {
    on(method, path, (_) => jsonResponse(body, status: status));
  }

  /// Faz uma rota responder sem corpo (ex.: 204).
  void replyEmpty(String method, String path, {int status = 204}) {
    on(method, path, (_) => http.Response('', status));
  }

  /// Faz uma rota falhar com um erro da API.
  void fail(
    String method,
    String path,
    int status,
    String code,
    String message,
  ) {
    on(method, path, (_) => errorResponse(status, code, message));
  }

  http.Request get lastRequest => requests.last;

  /// Corpo JSON da última requisição.
  Map<String, dynamic> get lastBody {
    return jsonDecode(lastRequest.body) as Map<String, dynamic>;
  }

  /// "MÉTODO /caminho" de cada requisição feita, na ordem.
  List<String> get calls => [
    for (final request in requests)
      '${request.method} ${request.url.path.substring(_prefix.length)}',
  ];

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path.substring(_prefix.length);
    final handler = _routes['${request.method} $path'];
    if (handler == null) {
      return errorResponse(
        404,
        'route_not_stubbed',
        'O teste não definiu resposta para ${request.method} $path',
      );
    }
    return handler(request);
  }
}
