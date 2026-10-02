import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';

class GuestCount {
  final int value;

  GuestCount(this.value) {
    if (value < 1) {
      throw PartyDomainException(
        'invalid_guest_count',
        'GuestCount deve ser >= 1.',
      );
    }
  }

  @override
  bool operator ==(Object other) => other is GuestCount && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'GuestCount($value)';
}
