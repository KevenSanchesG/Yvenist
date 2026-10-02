/// Validação de CPF e CNPJ no app, para avisar o usuário antes de enviar.
/// O servidor valida de novo: ele é a autoridade.
///
/// O CNPJ aceita letras nas 12 primeiras posições desde julho de 2026. O
/// cálculo dos dígitos verificadores continua sendo módulo 11, com cada
/// caractere valendo `código ASCII - 48` (dígitos mantêm o valor; A=17, B=18...).
library;

final RegExp _nonAlphanumeric = RegExp('[^0-9A-Za-z]');
final RegExp _digitsOnly = RegExp(r'^[0-9]+$');
final RegExp _cnpjShape = RegExp(r'^[0-9A-Z]{12}[0-9]{2}$');

const List<int> _cnpjWeights = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

/// Remove pontuação e espaços; letras ficam maiúsculas.
String normalizeDocument(String value) {
  return value.replaceAll(_nonAlphanumeric, '').toUpperCase();
}

bool _allSame(String value) => value.split('').toSet().length == 1;

bool isValidCpf(String value) {
  final cpf = normalizeDocument(value);
  if (cpf.length != 11 || !_digitsOnly.hasMatch(cpf) || _allSame(cpf)) {
    return false;
  }

  for (final position in const [9, 10]) {
    var total = 0;
    for (var index = 0; index < position; index++) {
      total += int.parse(cpf[index]) * (position + 1 - index);
    }
    final checkDigit = (total * 10) % 11 % 10;
    if (checkDigit != int.parse(cpf[position])) return false;
  }
  return true;
}

bool isValidCnpj(String value) {
  final cnpj = normalizeDocument(value);
  if (!_cnpjShape.hasMatch(cnpj) || _allSame(cnpj)) return false;

  for (final position in const [12, 13]) {
    final weights = _cnpjWeights.sublist(13 - position);
    var total = 0;
    for (var index = 0; index < position; index++) {
      total += (cnpj.codeUnitAt(index) - 48) * weights[index];
    }
    final remainder = total % 11;
    final checkDigit = remainder < 2 ? 0 : 11 - remainder;
    if (checkDigit != int.parse(cnpj[position])) return false;
  }
  return true;
}
