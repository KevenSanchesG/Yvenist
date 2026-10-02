/// Falhas que a camada de dados pode devolver para a apresentação.
///
/// [message] é sempre um texto em português pronto para mostrar ao usuário.
/// [code] é o código estável enviado pela API, para quando a tela precisa
/// decidir o que fazer (e não só exibir o texto).
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => '$runtimeType(${code ?? '-'}): $message';
}

/// Sem internet, servidor fora do ar ou tempo esgotado.
final class NetworkFailure extends AppFailure {
  const NetworkFailure()
      : super(
          'Sem conexão. Verifique sua internet e tente novamente.',
          code: 'network',
        );
}

/// Não autenticado: sessão expirada ou credenciais inválidas.
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([
    super.message = 'Sua sessão expirou. Entre novamente.',
    String? code,
  ]) : super(code: code ?? 'unauthorized');
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([
    super.message = 'Você não tem permissão para esta ação.',
    String? code,
  ]) : super(code: code ?? 'forbidden');
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([
    super.message = 'Não encontramos o que você procurava.',
    String? code,
  ]) : super(code: code ?? 'not_found');
}

/// A operação conflita com o estado atual (regra de negócio ou edição
/// concorrente).
final class ConflictFailure extends AppFailure {
  const ConflictFailure([
    super.message = 'Não foi possível concluir: os dados mudaram.',
    String? code,
  ]) : super(code: code ?? 'conflict');
}

/// Dados recusados pelo servidor. [fieldErrors] liga cada campo ao seu erro.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(
    super.message, {
    super.code = 'validation_error',
    this.fieldErrors = const {},
  });

  final Map<String, String> fieldErrors;
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure([
    super.message = 'Muitas tentativas. Aguarde um pouco e tente novamente.',
    this.retryAfter,
  ]) : super(code: 'too_many_requests');

  final Duration? retryAfter;
}

final class ServerFailure extends AppFailure {
  const ServerFailure()
      : super(
          'Tivemos um problema do nosso lado. Tente novamente em instantes.',
          code: 'internal_error',
        );
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure()
      : super('Algo deu errado. Tente novamente.', code: 'unexpected');
}

/// Texto para mostrar ao usuário a partir de qualquer erro capturado.
String describeFailure(Object error) {
  return error is AppFailure ? error.message : const UnexpectedFailure().message;
}
