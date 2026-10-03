import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Em que festa um item vai entrar: uma que já existe, ou uma nova, que nasce
/// junto com ele.
sealed class PartyTarget {
  const PartyTarget();
}

class ExistingPartyTarget extends PartyTarget {
  const ExistingPartyTarget(this.partyId);

  final PartyId partyId;
}

class NewPartyTarget extends PartyTarget {
  const NewPartyTarget(this.title);

  /// O nome que a pessoa deu para a festa nova.
  final String title;
}
