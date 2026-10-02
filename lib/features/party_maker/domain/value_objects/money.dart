import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';

class Money implements Comparable<Money> {
  final int cents;
  final String currency; // MVP: 'BRL'

  const Money._(this.cents, this.currency);

  factory Money.fromCents(int cents, {String currency = 'BRL'}) {
    return Money._(cents, currency);
  }

  factory Money.zero({String currency = 'BRL'}) => Money._(0, currency);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money._(cents + other.cents, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money._(cents - other.cents, currency);
  }

  Money multiplyInt(int factor) {
    return Money._(cents * factor, currency);
  }

  bool get isNegative => cents < 0;

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return cents.compareTo(other.cents);
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw PartyDomainException(
        'currency_mismatch',
        'Todos os itens da festa precisam estar na mesma moeda '
            '($currency e ${other.currency} não combinam).',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.cents == cents && other.currency == currency;

  @override
  int get hashCode => Object.hash(cents, currency);

  @override
  String toString() => 'Money($currency ${cents / 100})';
}
