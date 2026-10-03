import 'package:flutter/foundation.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/features/party_maker/domain/entities/quote_request.dart';
import 'package:yvenist/features/party_maker/domain/repositories/quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

/// Os pedidos de orçamento que a conta recebeu como fornecedora, para a tela
/// que os lista e responde.
class QuoteInboxController extends ChangeNotifier {
  QuoteInboxController(this._repository);

  final QuoteInboxRepository _repository;

  LoadState<List<QuoteRequest>> _state = const LoadInProgress();
  bool _isBusy = false;
  String? _error;
  bool _disposed = false;

  LoadState<List<QuoteRequest>> get state => _state;

  /// Verdadeiro enquanto uma resposta está sendo enviada.
  bool get isBusy => _isBusy;

  /// Mensagem da última resposta que falhou, pronta para exibir.
  String? get error => _error;

  Future<void> load() async {
    // Uma lista que já está na tela continua nela enquanto é atualizada. Só
    // quem vem de uma falha ("Tentar novamente") volta a ver o carregamento.
    if (_state is LoadFailure) {
      _state = const LoadInProgress();
      _notify();
    }
    try {
      _state = LoadSuccess(await _repository.list());
    } catch (error) {
      _state = LoadFailure(toFailure(error));
    }
    _notify();
  }

  /// Envia a resposta do fornecedor ao pedido [itemId]. Devolve se deu certo;
  /// o motivo de uma falha fica em [error].
  Future<bool> respond(String itemId, VendorResponse response) async {
    _error = null;
    _isBusy = true;
    _notify();
    try {
      await _repository.respond(itemId, response);
      // Uma resposta pode mudar a situação da festa inteira (o último valor
      // que faltava, por exemplo), e com ela os outros pedidos do mesmo
      // evento: a lista é buscada de novo.
      await load();
      return true;
    } catch (error) {
      _error = describeFailure(error);
      // O cliente aceitou, cancelou ou voltou a editar enquanto a resposta era
      // escrita: a lista volta a mostrar o que vale agora.
      if (error is ConflictFailure || error is NotFoundFailure) await load();
      return false;
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
