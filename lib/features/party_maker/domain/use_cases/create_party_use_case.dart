import 'package:yvenist/core/utils/clock.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Cria um evento novo, já em planejamento. Ele pode nascer sem itens: a
/// pessoa segue montando depois.
class CreatePartyUseCase {
  CreatePartyUseCase(this.repository, {this.clock = systemClock});

  final PartyRepository repository;
  final Clock clock;

  Future<Party> call({
    required PartyId partyId,
    required String ownerId,
    required EventDetails details,
  }) async {
    return repository.save(
      newParty(partyId: partyId, ownerId: ownerId, details: details),
    );
  }

  /// A festa nova, ainda sem gravar: é o que outro caso de uso usa para criar
  /// a festa e pôr o primeiro item nela em uma gravação só.
  Party newParty({
    required PartyId partyId,
    required String ownerId,
    required EventDetails details,
  }) {
    final now = clock();
    return Party(
        id: partyId,
        ownerId: ownerId,
        title: details.title,
        createdAt: now,
        updatedAt: now,
        clock: clock,
      )
      ..startPlanning()
      ..updateEventDetails(details);
  }
}
