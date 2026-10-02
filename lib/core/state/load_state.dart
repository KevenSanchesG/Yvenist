import 'package:yvenist/core/error/app_failure.dart';

/// Estado de algo que é carregado de forma assíncrona.
///
/// Sendo `sealed`, um `switch` na tela é obrigado a tratar todos os casos:
/// carregando, erro e conteúdo. Não dá para esquecer um deles.
sealed class LoadState<T> {
  const LoadState();

  /// O valor carregado, ou `null` enquanto carrega ou após falhar.
  T? get valueOrNull => switch (this) {
    LoadSuccess<T>(:final value) => value,
    _ => null,
  };

  bool get isLoading => this is LoadInProgress<T>;
}

final class LoadInProgress<T> extends LoadState<T> {
  const LoadInProgress();
}

final class LoadSuccess<T> extends LoadState<T> {
  const LoadSuccess(this.value);

  final T value;
}

final class LoadFailure<T> extends LoadState<T> {
  const LoadFailure(this.failure);

  final AppFailure failure;
}

/// Converte qualquer erro capturado em uma falha apresentável.
AppFailure toFailure(Object error) {
  return error is AppFailure ? error : const UnexpectedFailure();
}
