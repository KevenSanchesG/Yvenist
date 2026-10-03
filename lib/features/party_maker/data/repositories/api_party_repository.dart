import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/core/utils/clock.dart';
import 'package:yvenist/features/party_maker/data/party_mapper.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Festas gravadas na API.
///
/// O app executa a regra localmente e envia o estado desejado; o servidor
/// valida de novo, grava e devolve a festa como ficou. O que volta substitui a
/// cópia local.
class ApiPartyRepository implements PartyRepository {
  ApiPartyRepository(this._api, {Clock clock = systemClock}) : _clock = clock;

  final ApiClient _api;
  final Clock _clock;

  /// Último estado de cada festa confirmado pelo servidor.
  ///
  /// Guardar o JSON (e não o objeto) faz cada [getById] devolver uma instância
  /// nova: se uma gravação falhar, a alteração feita na instância anterior é
  /// descartada junto com ela, e a próxima leitura volta ao que o servidor tem.
  /// Daqui também sai a versão enviada em cada gravação.
  final Map<String, Json> _confirmed = {};

  @override
  Future<List<Party>> listByOwner(String ownerId) async {
    final json = await _api.get('/parties', authenticated: true) as Json;
    final items = (json['items'] as List).cast<Json>();

    _confirmed
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item['id'] as String, item)));
    return items.map(_toParty).toList();
  }

  @override
  Future<Party?> getById(PartyId id) async {
    final cached = _confirmed[id.value];
    if (cached != null) return _toParty(cached);

    try {
      final json =
          await _api.get('/parties/${id.value}', authenticated: true) as Json;
      return _remember(json);
    } on NotFoundFailure {
      return null;
    }
  }

  @override
  Future<Party> save(Party party) async {
    final version = _confirmed[party.id.value]?['version'] as int?;
    try {
      final json =
          await _api.put(
                '/parties/${party.id.value}',
                authenticated: true,
                body: partyToJson(party, version: version),
              )
              as Json;
      return _remember(json);
    } on ConflictFailure {
      // A cópia local ficou para trás (outro aparelho, ou a resposta de um
      // fornecedor): esquece, para a próxima leitura buscar a festa de novo
      // no servidor.
      _confirmed.remove(party.id.value);
      rethrow;
    } on NotFoundFailure {
      _confirmed.remove(party.id.value);
      rethrow;
    }
  }

  @override
  Future<void> deleteById(PartyId id) async {
    try {
      await _api.delete('/parties/${id.value}', authenticated: true);
    } on NotFoundFailure {
      // Já não existia: o resultado desejado é o mesmo.
    }
    _confirmed.remove(id.value);
  }

  Party _remember(Json json) {
    _confirmed[json['id'] as String] = json;
    return _toParty(json);
  }

  Party _toParty(Json json) => partyFromJson(json, clock: _clock);
}
