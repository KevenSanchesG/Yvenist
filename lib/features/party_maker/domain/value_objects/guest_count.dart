import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';

class GuestCount {
  /// O mesmo teto da API.
  static const int max = 100000;

  final int value;

  GuestCount(this.value) {
    if (value < 1 || value > max) {
      throw const PartyDomainException(
        'invalid_guest_count',
        'O número de convidados precisa ficar entre 1 e 100 mil.',
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
