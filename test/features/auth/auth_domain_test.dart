import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/features/auth/domain/auth_validators.dart';
import 'package:yvenist/features/auth/domain/entities/app_user.dart';

void main() {
  group('AppUser', () {
    const user = AppUser(
      id: '1',
      email: 'ana@example.com',
      fullName: 'Ana Maria de Souza',
      phone: '21999998888',
    );

    test('primeiro nome e iniciais vêm do nome completo', () {
      expect(user.firstName, 'Ana');
      expect(user.initials, 'AS');
    });

    test('iniciais lidam com um só nome, espaços extras e nome vazio', () {
      expect(const AppUser(id: '1', email: 'e', fullName: 'Ana').initials, 'A');
      expect(
        const AppUser(id: '1', email: 'e', fullName: '  ana   souza ').initials,
        'AS',
      );
      expect(const AppUser(id: '1', email: 'e', fullName: '  ').initials, '?');
    });

    test('copyWith altera só o que foi pedido e sabe limpar campos', () {
      final renamed = user.copyWith(fullName: 'Ana Souza');
      expect(renamed.fullName, 'Ana Souza');
      expect(renamed.phone, '21999998888');
      expect(renamed.email, user.email);

      final withoutPhone = user.copyWith(phone: () => null);
      expect(withoutPhone.phone, isNull);
      expect(withoutPhone.fullName, user.fullName);
    });
  });

  group('validação de e-mail', () {
    test('aceita endereços comuns, com espaços nas pontas', () {
      expect(validateEmail('ana@example.com'), isNull);
      expect(validateEmail('  ana.souza+festas@mail.example.com.br '), isNull);
    });

    test('recusa vazio e formatos inválidos', () {
      expect(validateEmail(null), 'Informe seu e-mail.');
      expect(validateEmail('   '), 'Informe seu e-mail.');
      for (final invalid in [
        'ana',
        'ana@',
        '@example.com',
        'a@b',
        'a b@c.com',
      ]) {
        expect(validateEmail(invalid), 'E-mail inválido.', reason: invalid);
      }
    });
  });

  group('validação de senha', () {
    test('login só exige que a senha tenha sido digitada', () {
      expect(validateCurrentPassword('x'), isNull);
      expect(validateCurrentPassword(''), 'Informe sua senha.');
      expect(validateCurrentPassword(null), 'Informe sua senha.');
    });

    test('senha nova exige tamanho, sem regras de composição', () {
      expect(validateNewPassword('somente letras minusculas'), isNull);
      expect(validateNewPassword('12345678'), isNull);
      expect(validateNewPassword(''), 'Crie uma senha.');
      expect(validateNewPassword('1234567'), 'Use pelo menos 8 caracteres.');
      expect(validateNewPassword('x' * 129), 'Use no máximo 128 caracteres.');
      expect(
        validateNewPassword(' ' * 10),
        'A senha não pode ser só de espaços.',
      );
    });

    test('confirmação precisa ser igual', () {
      expect(validatePasswordConfirmation('abc12345', 'abc12345'), isNull);
      expect(
        validatePasswordConfirmation('abc12346', 'abc12345'),
        'As senhas não conferem.',
      );
      expect(validatePasswordConfirmation('', 'abc12345'), 'Repita a senha.');
    });
  });

  group('validação de nome e telefone', () {
    test('nome precisa ter entre 2 e 120 caracteres', () {
      expect(validateFullName('Ana'), isNull);
      expect(validateFullName(' '), 'Informe seu nome.');
      expect(validateFullName('A'), 'Nome muito curto.');
      expect(validateFullName('a' * 121), 'Nome muito longo.');
    });

    test('telefone é opcional; se informado, precisa de DDD', () {
      expect(validatePhone(''), isNull);
      expect(validatePhone(null), isNull);
      expect(validatePhone('(21) 99999-8888'), isNull);
      expect(validatePhone('2133334444'), isNull);
      expect(validatePhone('99999-8888'), 'Informe o telefone com DDD.');
    });

    test('formata celular e fixo, e devolve o resto como veio', () {
      expect(formatPhone('21999998888'), '(21) 99999-8888');
      expect(formatPhone('2133334444'), '(21) 3333-4444');
      expect(formatPhone('5521999998888'), '5521999998888');
      expect(formatPhone(null), '');
    });
  });
}
