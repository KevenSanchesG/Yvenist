import 'package:flutter/foundation.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/utils/id_generator.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/add_item_to_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/create_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/lock_party_for_payment_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/remove_item_from_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/unlock_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';
import 'package:yvenist/features/party_maker/presentation/models/party_budget_item_view.dart';

/// Estado do Party Maker para as telas.
///
/// Depende só do contrato [PartyRepository]: funciona igual com o repositório
/// em memória (modo demonstração, testes) e com o da API.
class PartyMakerController extends ChangeNotifier {
  PartyMakerController({
    required PartyRepository repository,
    required IdGenerator ids,
    String? ownerId,
  })  : _repository = repository,
        _ids = ids,
        _ownerId = ownerId,
        _createParty = CreatePartyUseCase(repository),
        _addItem = AddItemToPartyUseCase(repository),
        _removeItem = RemoveItemFromPartyUseCase(repository),
        _lockForPayment = LockPartyForPaymentUseCase(repository),
        _unlockParty = UnlockPartyUseCase(repository);

  final PartyRepository _repository;
  final IdGenerator _ids;
  final CreatePartyUseCase _createParty;
  final AddItemToPartyUseCase _addItem;
  final RemoveItemFromPartyUseCase _removeItem;
  final LockPartyForPaymentUseCase _lockForPayment;
  final UnlockPartyUseCase _unlockParty;

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

  /// ✅ Session state (Presentation):
  /// - null => usuário está no HUB (MyParties)
  /// - != null => usuário está construindo/editando uma festa específica
  PartyId? get activePartyId => _activePartyId;

  /// ✅ IMPORTANTE:
  /// Se não há sessão ativa, NÃO invente party.
  /// Isso é o que permite entrar no hub.
  Party? get activeParty {
    if (_activePartyId == null) return null;
    for (final party in _parties) {
      if (party.id == _activePartyId) return party;
    }
    return null;
  }

  bool get isActivePartyLocked => activeParty?.status == PartyStatus.locked;

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
      .where(
        (p) =>
            p.status == PartyStatus.draft || p.status == PartyStatus.planning,
      )
      .toList(growable: false);

  /// O item do catálogo já está em alguma festa em andamento?
  bool isInAnyParty(String externalId) {
    return _parties.any(
      (party) =>
          party.status != PartyStatus.cancelled &&
          party.budget.items.any((item) => item.externalRef.id == externalId),
    );
  }

  List<PartyBudgetItemView> get budgetItemViews {
    final party = activeParty;
    if (party == null) return const [];

    return party.budget.items
        .map(
          (item) => PartyBudgetItemView(
            id: item.id.value,
            name: item.nameSnapshot,
            unitPriceCents: item.unitPriceSnapshot.cents,
            quantity: item.quantity.value,
            imageUrl: item.imageUrlSnapshot,
            category: item.category.name,
          ),
        )
        .toList(growable: false);
  }

  int get activePartyTotalCents => activeParty?.budget.total.cents ?? 0;

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

  /// Busca as festas do dono no repositório.
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

  /// ✅ Seleção explícita pelo HUB
  void setActiveParty(PartyId id) {
    _activePartyId = id;
    _notify();
  }

  /// ✅ Encerra sessão ativa -> próximo clique no PartyMaker abre HUB
  void clearActiveParty() {
    if (_activePartyId == null) return;
    _activePartyId = null;
    _notify();
  }

  // ============================================================
  // Operações
  // ============================================================

  /// Cria uma festa em planejamento e a torna ativa. `null` se falhar.
  Future<Party?> startNewParty(String title) {
    return _guard(() async {
      final party = await _createNewParty(title);
      _upsert(party);
      _activePartyId = party.id;
      return party;
    });
  }

  Future<bool> addItemToParty(PartyId partyId, PartyItemDraft draft) async {
    final saved = await _guard(() => _addDraft(partyId, draft));
    if (saved == null) return false;
    _upsert(saved);
    return true;
  }

  /// Cria uma festa já com o primeiro item. Se o item não puder entrar, a
  /// festa recém-criada é descartada: festa vazia não deve existir.
  Future<bool> addItemToNewParty(String title, PartyItemDraft draft) async {
    final saved = await _guard(() async {
      final party = await _createNewParty(title);
      try {
        return await _addDraft(party.id, draft);
      } catch (_) {
        await _repository.deleteById(party.id);
        rethrow;
      }
    });
    if (saved == null) return false;
    _upsert(saved);
    _activePartyId = saved.id;
    _notify();
    return true;
  }

  Future<bool> removeItemFromActiveParty(String itemId) async {
    final party = activeParty;
    if (party == null) return _fail('Nenhuma festa selecionada.');

    var removed = false;
    await _guard(() async {
      final saved = await _removeItem(
        partyId: party.id,
        itemId: PartyItemId(itemId),
      );
      removed = true;
      if (saved == null) {
        // O último item saiu e a festa foi apagada junto.
        _parties.removeWhere((p) => p.id == party.id);
        _activePartyId = null;
      } else {
        _upsert(saved);
      }
    });
    return removed;
  }

  Future<bool> lockActivePartyForPayment() {
    return _changeActiveParty(_lockForPayment.call);
  }

  Future<bool> unlockActiveParty() {
    return _changeActiveParty(_unlockParty.call);
  }

  // ============================================================
  // Internos
  // ============================================================

  Future<bool> _changeActiveParty(
    Future<Party> Function(PartyId id) operation,
  ) async {
    final party = activeParty;
    if (party == null) return _fail('Nenhuma festa selecionada.');

    final saved = await _guard(() => operation(party.id));
    if (saved == null) return false;
    _upsert(saved);
    return true;
  }

  Future<Party> _createNewParty(String title) {
    final ownerId = _ownerId;
    if (ownerId == null) {
      throw const UnauthorizedFailure('Entre na sua conta para criar festas.');
    }
    return _createParty(
      partyId: PartyId(_ids.newId()),
      ownerId: ownerId,
      title: PartyTitle(title),
      startPlanning: true,
    );
  }

  Future<Party> _addDraft(PartyId partyId, PartyItemDraft draft) {
    return _addItem(
      partyId: partyId,
      partyItemId: PartyItemId(_ids.newId()),
      externalRef: draft.externalRef,
      category: draft.category,
      nameSnapshot: draft.name,
      unitPriceSnapshot: draft.unitPrice,
      quantity: Quantity(1),
      imageUrlSnapshot: draft.imageUrl,
    );
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
      // cópia local está desatualizada: recarrega para a tela voltar a
      // refletir o que está gravado.
      if (error is ConflictFailure || error is NotFoundFailure) await load();
      return null;
    } finally {
      _setBusy(false);
    }
  }

  bool _fail(String message) {
    _error = message;
    _notify();
    return false;
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
