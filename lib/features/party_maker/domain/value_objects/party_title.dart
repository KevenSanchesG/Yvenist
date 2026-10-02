import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';

class PartyTitle {
  final String value;

  PartyTitle(String value) : value = value.trim() {
    if (this.value.isEmpty) {
      throw const PartyDomainException(
        'invalid_party_title',
        'Dê um nome para a festa.',
      );
    }
  }

  @override
  bool operator ==(Object other) => other is PartyTitle && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'PartyTitle($value)';
}
