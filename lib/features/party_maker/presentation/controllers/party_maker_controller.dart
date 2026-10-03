import 'package:flutter/foundation.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/utils/clock.dart';
import 'package:yvenist/core/utils/id_generator.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/add_item_to_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/cancel_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/confirm_quote_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/create_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/delete_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/remove_item_from_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/reopen_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/request_quote_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/update_event_details_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/update_party_item_use_case.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';

/// Estado do Party Maker para as telas.
///
/// Depende só do contrato [PartyRepository]: funciona igual com o repositório
/// em memória (modo demonstração, testes) e com o da API. Não tem regra de
/// negócio: cada operação é um caso de uso, e as regras são as do agregado.
class PartyMakerController extends ChangeNotifier {
  PartyMakerController({
    required PartyRepository repository,
    required IdGenerator ids,
    String? ownerId,
    Clock clock = systemClock,
  }) : _repository = repository,
       _ids = ids,
       _ownerId = ownerId,
       _createParty = CreatePartyUseCase(repository, clock: clock),
       _addItem = AddItemToPartyUseCase(repository, newId: ids.newId),
       _updateItem = UpdatePartyItemUseCase(repository, newId: ids.newId),
       _removeItem = RemoveItemFromPartyUseCase(repository),
       _updateEventDetails = UpdateEventDetailsUseCase(repository),
       _requestQuote = RequestQuoteUseCase(repository),
       _reopenParty = ReopenPartyUseCase(repository),
       _confirmQuote = ConfirmQuoteUseCase(repository),
       _cancelParty = CancelPartyUseCase(repository),
       _deleteParty = DeletePartyUseCase(repository);

  final PartyRepository _repository;
  final IdGenerator _ids;
  final CreatePartyUseCase _createParty;
  final AddItemToPartyUseCase _addItem;
  final UpdatePartyItemUseCase _updateItem;
  final RemoveItemFromPartyUseCase _removeItem;
  final UpdateEventDetailsUseCase _updateEventDetails;
  final RequestQuoteUseCase _requestQuote;
  final ReopenPartyUseCase _reopenParty;
  final ConfirmQuoteUseCase _confirmQuote;
  final CancelPartyUseCase _cancelParty;
  final DeletePartyUseCase _deleteParty;

  String? _ownerId;
  final List<Party> _parties = [];
  PartyId? _activePartyId;
  bool _isBusy = false;
  bool _hasLoaded = false;
  String? _error;
  String? _loadError;
  Future<void>? _loading;
  bool _disposed = false;

  // ============================================================
  // Leitura
  // ============================================================

  List<Party> get parties => List.unmodifiable(_parties);

  /// A festa aberta na aba:
  /// - `null`: a pessoa está na lista de festas;
  /// - preenchido: está montando ou acompanhando aquela festa.
  PartyId? get activePartyId => _activePartyId;

  Party? get activeParty {
    final id = _activePartyId;
    return id == null ? null : partyById(id);
  }

  Party? partyById(PartyId id) {
    for (final party in _parties) {
      if (party.id == id) return party;
    }
    return null;
  }

  /// Verdadeiro enquanto uma operação está em andamento.
  bool get isBusy => _isBusy;

  /// Verdadeiro depois da primeira carga das festas (com ou sem sucesso).
  bool get hasLoaded => _hasLoaded;

  /// Mensagem da última operação que falhou, pronta para exibir.
  String? get error => _error;

  /// Mensagem de erro da última carga das festas, se ela falhou.
  String? get loadError => _loadError;

  /// Festas que ainda podem receber itens.
  List<Party> get editableParties => _parties
      .where((party) => party.status.isEditable)
      .toList(growable: false);

  /// O item do catálogo já está em alguma festa em andamento?
  bool isInAnyParty(String externalId) {
    return _parties.any(
      (party) =>
          party.status != PartyStatus.cancelled &&
          party.budget.items.any((item) => item.externalRef.id == externalId),
    );
  }

  // ============================================================
  // Sessão
  // ============================================================

  /// Troca o dono das festas (login, logout ou troca de conta): descarta o que
  /// estava carregado e busca as festas da nova conta.
  Future<void> setOwner(String? ownerId) async {
    if (ownerId == _ownerId && _hasLoaded) return;
    _ownerId = ownerId;
    _parties.clear();
    _activePartyId = null;
    _error = null;
    _loadError = null;
    _hasLoaded = false;
    await load();
  }

  /// Busca as festas do dono no repositório. É também como a tela fica sabendo
  /// do que mudou do outro lado: a resposta de um fornecedor.
  Future<void> load() {
    return _loading = _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final ownerId = _ownerId;
    if (ownerId == null) {
      _parties.clear();
      _activePartyId = null;
      _hasLoaded = true;
      _notify();
      return;
    }

    try {
      final loaded = await _repository.listByOwner(ownerId);
      // A conta pode ter mudado enquanto a busca estava em andamento.
      if (ownerId != _ownerId) return;
      _parties
        ..clear()
        ..addAll(loaded);
      _loadError = null;
      if (activeParty == null) _activePartyId = null;
    } catch (error) {
      if (ownerId != _ownerId) return;
      _loadError = _describe(error);
    } finally {
      if (ownerId == _ownerId) {
        _hasLoaded = true;
        _notify();
      }
    }
  }

  /// Abre uma festa na aba.
  void setActiveParty(PartyId id) {
    _activePartyId = id;
    _notify();
  }

  /// Fecha a festa aberta: a aba volta para a lista.
  void clearActiveParty() {
    if (_activePartyId == null) return;
    _activePartyId = null;
    _notify();
  }

  // ============================================================
  // Operações
  // ============================================================
  //
  // Cada uma devolve o resultado, ou `null`/`false` quando falha; o motivo
  // fica em [error]. Nenhuma exceção chega à tela.

  /// Cria um evento novo, em planejamento, e o abre na aba.
  Future<Party?> createParty(EventDetails details) {
    return _guard(() async {
      final party = await _createParty(
        partyId: PartyId(_ids.newId()),
        ownerId: _requireOwner(),
        details: details,
      );
      _upsert(party);
      _activePartyId = party.id;
      return party;
    });
  }

  /// Põe na festa [partyId] um item já configurado. Com [eventDetails], grava
  /// junto os dados do evento informados no mesmo formulário.
  Future<Party?> addItem(
    PartyId partyId,
    ConfiguredItem selection, {
    EventDetails? eventDetails,
  }) {
    return _guard(() async {
      final party = await _addItem(
        partyId: partyId,
        selection: selection,
        eventDetails: eventDetails,
      );
      _upsert(party);
      return party;
    });
  }

  /// Cria a festa já com o item, em uma gravação só: se o item não puder
  /// entrar, a festa não chega a existir.
  Future<Party?> addItemToNewParty(
    EventDetails eventDetails,
    ConfiguredItem selection,
  ) {
    return _guard(() async {
      final party = await _addItem.intoNewParty(
        create: _createParty,
        partyId: PartyId(_ids.newId()),
        ownerId: _requireOwner(),
        eventDetails: eventDetails,
        selection: selection,
      );
      _upsert(party);
      _activePartyId = party.id;
      return party;
    });
  }

  /// Altera a configuração de um item que já está na festa.
  Future<bool> updateItem(
    PartyId partyId,
    PartyItemId itemId, {
    required int quantity,
    required Map<String, Object?> configuration,
    List<ConfiguredItem>? ownServices,
    EventDetails? eventDetails,
  }) {
    return _change(
      () => _updateItem(
        partyId: partyId,
        itemId: itemId,
        quantity: quantity,
        configuration: configuration,
        ownServices: ownServices,
        eventDetails: eventDetails,
      ),
    );
  }

  /// Tira um item da festa. Devolve o que a remoção fez com os outros itens,
  /// para a tela contar à pessoa, ou `null` se falhou.
  Future<ItemRemoval?> removeItem(PartyId partyId, PartyItemId itemId) {
    return _guard(() async {
      final result = await _removeItem(partyId: partyId, itemId: itemId);
      _upsert(result.party);
      return result.removal;
    });
  }

  Future<bool> updateEventDetails(PartyId partyId, EventDetails details) {
    return _change(
      () => _updateEventDetails(partyId: partyId, details: details),
    );
  }

  Future<bool> requestQuote(PartyId partyId) {
    return _change(() => _requestQuote(partyId));
  }

  /// Volta a festa para o planejamento, para a pessoa poder alterá-la.
  Future<bool> reopen(PartyId partyId) => _change(() => _reopenParty(partyId));

  Future<bool> confirmQuote(PartyId partyId) {
    return _change(() => _confirmQuote(partyId));
  }

  Future<bool> cancelParty(PartyId partyId) {
    return _change(() => _cancelParty(partyId));
  }

  /// Apaga a festa de vez e volta para a lista.
  Future<bool> deleteParty(PartyId partyId) async {
    final deleted = await _guard(() async {
      await _deleteParty(partyId);
      _parties.removeWhere((party) => party.id == partyId);
      if (_activePartyId == partyId) _activePartyId = null;
      return true;
    });
    return deleted ?? false;
  }

  // ============================================================
  // Internos
  // ============================================================

  /// Uma operação que devolve a festa como ficou gravada.
  Future<bool> _change(Future<Party> Function() operation) async {
    final saved = await _guard(operation);
    if (saved == null) return false;
    _upsert(saved);
    return true;
  }

  String _requireOwner() {
    final ownerId = _ownerId;
    if (ownerId == null) {
      throw const UnauthorizedFailure('Entre na sua conta para criar festas.');
    }
    return ownerId;
  }

  /// Executa [action] marcando o controller como ocupado e traduzindo
  /// qualquer falha em [error]. Devolve `null` quando falha.
  Future<T?> _guard<T>(Future<T> Function() action) async {
    _error = null;
    _setBusy(true);
    try {
      // Espera uma carga em andamento (ex.: logo após o login) para que o
      // resultado dela não sobrescreva o que esta operação gravar.
      await _loading;
      return await action();
    } catch (error) {
      _error = _describe(error);
      // Conflito ou "não encontrado" vindos do servidor significam que a
      // cópia local está desatualizada (outro aparelho gravou, ou um
      // fornecedor respondeu): recarrega para a tela voltar a refletir o que
      // está gravado.
      if (error is ConflictFailure || error is NotFoundFailure) await load();
      return null;
    } finally {
      _setBusy(false);
    }
  }

  String _describe(Object error) {
    if (error is PartyDomainException) return error.message;
    return describeFailure(error);
  }

  void _upsert(Party party) {
    final index = _parties.indexWhere((p) => p.id == party.id);
    if (index == -1) {
      _parties.insert(0, party);
    } else {
      _parties[index] = party;
    }
    _notify();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    _notify();
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
