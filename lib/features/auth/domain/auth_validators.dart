/// Validações dos formulários de conta. Devolvem a mensagem de erro para o
/// campo, ou `null` quando o valor é aceito. O servidor valida de novo.
library;

const int passwordMinLength = 8;
const int passwordMaxLength = 128;

// Propositalmente simples: confere o formato geral e deixa a verificação
// completa para o servidor. Regex "perfeita" de e-mail rejeita endereços reais.
final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final RegExp _nonDigits = RegExp(r'\D');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Informe seu e-mail.';
  if (!_emailShape.hasMatch(email)) return 'E-mail inválido.';
  return null;
}

/// Para o login: só exige que a senha tenha sido digitada. Avisar aqui sobre
/// o tamanho mínimo daria pista sobre a regra a quem está tentando adivinhar.
String? validateCurrentPassword(String? value) {
  return (value == null || value.isEmpty) ? 'Informe sua senha.' : null;
}

/// Para cadastro e troca de senha. Exige só tamanho: regras de composição
/// (maiúscula, símbolo...) levam a senhas previsíveis e não são mais
/// recomendadas (NIST 800-63B).
String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Crie uma senha.';
  if (password.trim().isEmpty) return 'A senha não pode ser só de espaços.';
  if (password.length < passwordMinLength) {
    return 'Use pelo menos $passwordMinLength caracteres.';
  }
  if (password.length > passwordMaxLength) {
    return 'Use no máximo $passwordMaxLength caracteres.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) return 'Repita a senha.';
  return value == password ? null : 'As senhas não conferem.';
}

String? validateFullName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Informe seu nome.';
  if (name.length < 2) return 'Nome muito curto.';
  if (name.length > 120) return 'Nome muito longo.';
  return null;
}

/// Telefone é opcional; se preenchido, precisa de DDD + número.
String? validatePhone(String? value) {
  final digits = (value ?? '').replaceAll(_nonDigits, '');
  if (digits.isEmpty) return null;
  if (digits.length < 10 || digits.length > 13) {
    return 'Informe o telefone com DDD.';
  }
  return null;
}

/// `21999998888` -> `(21) 99999-8888`. Outros tamanhos voltam como vieram.
String formatPhone(String? digits) {
  if (digits == null) return '';
  final value = digits.replaceAll(_nonDigits, '');
  if (value.length == 11) {
    return '(${value.substring(0, 2)}) ${value.substring(2, 7)}-'
        '${value.substring(7)}';
  }
  if (value.length == 10) {
    return '(${value.substring(0, 2)}) ${value.substring(2, 6)}-'
        '${value.substring(6)}';
  }
  return digits;
}
