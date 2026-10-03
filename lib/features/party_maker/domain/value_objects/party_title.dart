import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';

class PartyTitle {
  /// O mesmo limite da API e da coluna `parties.title`.
  static const int maxLength = 80;

  final String value;

  /// Sem espaços nas pontas e com espaços simples no meio, como a API grava.
  PartyTitle(String value)
    : value = value.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).join(' ') {
    if (this.value.isEmpty) {
      throw const PartyDomainException(
        'invalid_party_title',
        'Dê um nome para a festa.',
      );
    }
    if (this.value.length > maxLength) {
      throw const PartyDomainException(
        'invalid_party_title',
        'O nome da festa pode ter até $maxLength caracteres.',
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
