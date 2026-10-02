import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';

class Quantity {
  final int value;

  Quantity(this.value) {
    if (value < 1) {
      throw const PartyDomainException(
        'invalid_quantity',
        'A quantidade precisa ser pelo menos 1.',
      );
    }
  }

  Quantity add(Quantity other) => Quantity(value + other.value);

  @override
  bool operator ==(Object other) => other is Quantity && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Quantity($value)';
}
