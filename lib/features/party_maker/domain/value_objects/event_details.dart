import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';

/// Os dados do evento, como a pessoa os informa: o nome, o tipo, quando é e
/// para quantas pessoas. São da festa, e não de um item: mudou aqui, vale para
/// tudo o que depende disso (a estimativa por pessoa, a capacidade do salão).
class EventDetails {
  const EventDetails({
    required this.title,
    this.eventType,
    this.eventDate,
    this.guestCount,
  });

  final PartyTitle title;

  /// O tipo de evento, pelo `slug` do catálogo (`wedding`, `debutante`...).
  final String? eventType;
  final EventDate? eventDate;
  final GuestCount? guestCount;
}
