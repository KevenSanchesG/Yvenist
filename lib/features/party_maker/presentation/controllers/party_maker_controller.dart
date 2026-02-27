import 'package:flutter/foundation.dart';

import '../../domain/use_cases/unlock_party_use_case.dart';
import '../../domain/use_cases/lock_party_for_payment_use_case.dart';
import '../state/party_item_image_cache.dart';
import '../../data/repositories/in_memory_party_repository.dart';
import '../../domain/entities/party.dart';
import '../../domain/enums/party_item_category.dart';
import '../../domain/use_cases/add_item_to_party_use_case.dart';
import '../../domain/use_cases/create_party_use_case.dart';
import '../../domain/use_cases/remove_item_from_party_use_case.dart';
import '../../domain/use_cases/start_planning_use_case.dart';
import '../../domain/value_objects/external_ref.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/party_id.dart';
import '../../domain/value_objects/party_item_id.dart';
import '../../domain/value_objects/party_title.dart';
import '../../domain/value_objects/quantity.dart';
import '../../domain/enums/party_status.dart';
import '../models/party_budget_item_view.dart';

class PartyMakerController extends ChangeNotifier {
  final InMemoryPartyRepository _repo;
  final CreatePartyUseCase _createParty;
  final StartPlanningUseCase _startPlanning;
  final AddItemToPartyUseCase _addItem;
  final RemoveItemFromPartyUseCase _removeItem;
  final PartyItemImageCache _imageCache = PartyItemImageCache();
  final LockPartyForPaymentUseCase _lockForPayment;
  final UnlockPartyUseCase _unlockParty;

  PartyMakerController({
    required InMemoryPartyRepository repo,
    required CreatePartyUseCase createParty,
    required StartPlanningUseCase startPlanning,
    required AddItemToPartyUseCase addItem,
    required RemoveItemFromPartyUseCase removeItem,
    required LockPartyForPaymentUseCase lockForPayment,
    required UnlockPartyUseCase unlockParty,
  })  : _repo = repo,
        _createParty = createParty,
        _startPlanning = startPlanning,
        _addItem = addItem,
        _removeItem = removeItem,
        _lockForPayment = lockForPayment,
        _unlockParty = unlockParty;

  final List<Party> _parties = [];
  List<Party> get parties => List.unmodifiable(_parties);

  /// ✅ Session state (Presentation):
  /// - null => usuário está no HUB (MyParties)
  /// - != null => usuário está construindo/editando uma festa específica
  PartyId? _activePartyId;
  PartyId? get activePartyId => _activePartyId;

  /// ✅ IMPORTANTE:
  /// Se não há sessão ativa, NÃO invente party.
  /// Isso é o que permite entrar no hub.
  Party? get activeParty {
    if (_activePartyId == null) return null;

    for (final p in _parties) {
      if (p.id == _activePartyId) return p;
    }

    // Se o ID ativo não existe mais no repo (futuro sync / inconsistência),
    // encerramos sessão ao invés de cair em "primeira party".
    return null;
  }

  bool get isActivePartyLocked => activeParty?.status == PartyStatus.locked;

  bool get canMutateActiveParty {
    final status = activeParty?.status;
    return status == PartyStatus.draft || status == PartyStatus.planning;
  }

  // ============================================================
  // Helpers para a Home (ContentCard)
  // ============================================================

  bool isExternalItemInActiveParty(String externalId) {
    final party = activeParty;
    if (party == null) return false;

    return party.budget.items.any((i) => i.externalRef.id == externalId);
  }

  PartyItemId? findPartyItemIdByExternalId(String externalId) {
    final party = activeParty;
    if (party == null) return null;

    for (final i in party.budget.items) {
      if (i.externalRef.id == externalId) return i.id;
    }
    return null;
  }

  // ============================================================
  // (B) ViewModel mapping: Domain -> Presentation (sem tocar Domain)
  // ============================================================

  List<PartyBudgetItemView> get budgetItemViews {
    final party = activeParty;
    if (party == null) return const [];

    return party.budget.items
        .map((item) {
          return PartyBudgetItemView(
            id: item.id.value,
            name: item.nameSnapshot,
            unitPriceCents: item.unitPriceSnapshot.cents,
            quantity: item.quantity.value,
            imageUrl: _imageCache.get(item.externalRef.id),
            category: item.category.name,
          );
        })
        .toList(growable: false);
  }

  int get activePartyTotalCents {
    final party = activeParty;
    if (party == null) return 0;
    return party.budget.total.cents;
  }

  // ============================================================
  // Estado do controller
  // ============================================================

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _error;
  String? get error => _error;

  /// ✅ Encerra sessão ativa -> próximo clique no PartyMaker abre HUB
  void clearActiveParty() {
    _activePartyId = null;
    notifyListeners();
  }

  /// ✅ Atualiza lista do repo, mas NÃO define sessão ativa automaticamente.
  /// Se a sessão ativa apontar para um id que não existe mais, zera a sessão.
  void refreshFromRepo() {
    _parties
      ..clear()
      ..addAll(_repo.dumpAll());

    if (_activePartyId != null) {
      final stillExists = _parties.any((p) => p.id == _activePartyId);
      if (!stillExists) {
        _activePartyId = null;
      }
    }

    notifyListeners();
  }

  /// ✅ Seleção explícita pelo HUB
  void setActiveParty(PartyId id) {
    _activePartyId = id;
    notifyListeners();
  }

  Future<Party> _ensureActiveParty({required String ownerId}) async {
    refreshFromRepo();

    // Se já há sessão ativa, tenta carregar ela
    if (_activePartyId != null) {
      final existing = await _repo.getById(_activePartyId!);
      if (existing != null) {
        _upsert(existing);
        return existing;
      }
    }

    // Não há sessão ativa (ou não existe no repo): cria uma nova party
    final partyId = PartyId(DateTime.now().microsecondsSinceEpoch.toString());

    await _createParty(
      partyId: partyId,
      ownerId: ownerId,
      title: PartyTitle('Minha Festa'),
    );

    await _startPlanning(partyId);

    final created = await _repo.getById(partyId);
    final party = created!;
    _upsert(party);

    // ✅ ao criar via ensure (ex: user adicionou item), abre sessão ativa
    _activePartyId = party.id;

    return party;
  }

  Future<Party> startNewParty({required String ownerId}) async {
    _setBusy(true);
    _error = null;

    try {
      final partyId = PartyId(DateTime.now().microsecondsSinceEpoch.toString());

      await _createParty(
        partyId: partyId,
        ownerId: ownerId,
        title: PartyTitle('Minha Festa'),
      );

      await _startPlanning(partyId);

      final created = await _repo.getById(partyId);
      final party = created!;
      _upsert(party);

      // ✅ regra do produto:
      // criar nova festa -> entra direto no modo construção
      _activePartyId = party.id;

      return party;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> addCardToActiveParty({
    required String ownerId,
    required String cardTitle,
    required String cardPrice,
    required String externalId,
    required PartyItemCategory category,
    String? imagePath, // imagem é presentation
  }) async {
    _setBusy(true);
    _error = null;

    try {
      final party = await _ensureActiveParty(ownerId: ownerId);

      // Cache de imagem (presentation)
      if (imagePath != null && imagePath.trim().isNotEmpty) {
        _imageCache.put(externalRefId: externalId, imagePath: imagePath);
      }

      final unitPrice = Money.fromCents(_parsePriceToCents(cardPrice));
      final itemId = PartyItemId(
        DateTime.now().microsecondsSinceEpoch.toString(),
      );

      await _addItem(
        partyId: party.id,
        partyItemId: itemId,
        externalRef: ExternalRef(source: 'vendor_catalog', id: externalId),
        category: category,
        nameSnapshot: cardTitle,
        unitPriceSnapshot: unitPrice,
        quantity: Quantity(1),
      );

      final updated = await _repo.getById(party.id);
      if (updated != null) _upsert(updated);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> addCardToParty({
  required PartyId partyId,
  required String ownerId,
  required String cardTitle,
  required String cardPrice,
  required String externalId,
  required PartyItemCategory category,
  String? imagePath,
}) async {
  _setBusy(true);
  _error = null;

  try {
    final party = await _repo.getById(partyId);
    if (party == null) {
      throw Exception('Party não encontrada.');
    }

    if (party.status == PartyStatus.locked) {
      throw Exception('Essa festa já foi bloqueada.');
    }

    if (imagePath != null && imagePath.trim().isNotEmpty) {
      _imageCache.put(externalRefId: externalId, imagePath: imagePath);
    }

    final unitPrice = Money.fromCents(_parsePriceToCents(cardPrice));
    final itemId = PartyItemId(
      DateTime.now().microsecondsSinceEpoch.toString(),
    );

    await _addItem(
      partyId: party.id,
      partyItemId: itemId,
      externalRef: ExternalRef(source: 'vendor_catalog', id: externalId),
      category: category,
      nameSnapshot: cardTitle,
      unitPriceSnapshot: unitPrice,
      quantity: Quantity(1),
    );

    final updated = await _repo.getById(party.id);
    if (updated != null) _upsert(updated);

    return true;
  } catch (e) {
    _error = e.toString();
    return false;
  } finally {
    _setBusy(false);
  }
}

  Future<bool> removeItemFromActiveParty(PartyItemId itemId) async {
    _setBusy(true);
    _error = null;

    try {
      final party = activeParty;
      if (party == null) {
        throw Exception('Não existe Party ativa.');
      }

      await _removeItem(partyId: party.id, itemId: itemId);

      final updated = await _repo.getById(party.id);
      if (updated != null) _upsert(updated);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> lockActivePartyForPayment() async {
    _setBusy(true);
    _error = null;

    try {
      final party = activeParty;
      if (party == null) {
        throw Exception('Não existe Party ativa.');
      }

      await _lockForPayment(party.id);

      final updated = await _repo.getById(party.id);
      if (updated != null) _upsert(updated);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> unlockActiveParty() async {
    _setBusy(true);
    _error = null;

    try {
      final party = activeParty;
      if (party == null) throw Exception('Não existe Party ativa.');

      await _unlockParty(party.id);

      final updated = await _repo.getById(party.id);
      if (updated != null) _upsert(updated);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // ============================================================
  // (C) Helper: remover por String id (Page não conhece PartyItemId)
  // ============================================================
  Future<bool> removeItemFromActivePartyById(String itemId) async {
    return removeItemFromActiveParty(PartyItemId(itemId));
  }

  // ============================================================
  // Internals
  // ============================================================

  void _upsert(Party party) {
    final idx = _parties.indexWhere((p) => p.id == party.id);
    if (idx == -1) {
      _parties.insert(0, party);
    } else {
      _parties[idx] = party;
    }
    notifyListeners();
  }

  void _setBusy(bool v) {
    _isBusy = v;
    notifyListeners();
  }

  int _parsePriceToCents(String input) {
    final cleaned = input.replaceAll('R\$', '').replaceAll(' ', '').trim();

    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      final reaisPart = parts[0].replaceAll('.', '');
      final centsPartRaw = parts.length > 1 ? parts[1] : '0';
      final centsPart = (centsPartRaw + '00').substring(0, 2);
      final reais = int.tryParse(reaisPart) ?? 0;
      final cents = int.tryParse(centsPart) ?? 0;
      return reais * 100 + cents;
    }

    final reais = int.tryParse(cleaned.replaceAll('.', '')) ?? 0;
    return reais * 100;
  }
}