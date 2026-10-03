import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';

class Quantity {
  /// O mesmo teto da API (`MAX_ITEM_QUANTITY`).
  static const int max = 999;

  final int value;

  Quantity(this.value) {
    if (value < 1 || value > max) throw const InvalidQuantity();
  }

  @override
  bool operator ==(Object other) => other is Quantity && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Quantity($value)';
}
