import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/core/storage/token_storage.dart';
import 'package:yvenist/core/utils/brazilian_documents.dart';
import 'package:yvenist/core/utils/id_generator.dart';
import 'package:yvenist/core/utils/money_formatter.dart';

void main() {
  group('formatBrl', () {
    test('formata centavos como reais', () {
      expect(formatBrl(123456), r'R$ 1.234,56');
      expect(formatBrl(5), r'R$ 0,05');
      expect(formatBrl(0), r'R$ 0,00');
      expect(formatBrl(100000000), r'R$ 1.000.000,00');
    });

    test('pode esconder os centavos de valores redondos', () {
      expect(formatBrl(100000, hideZeroCents: true), r'R$ 1.000');
      expect(formatBrl(100050, hideZeroCents: true), r'R$ 1.000,50');
    });
  });

  group('parseBrlToCents', () {
    test('entende os formatos que as pessoas digitam', () {
      expect(parseBrlToCents('1500'), 150000);
      expect(parseBrlToCents('1.500'), 150000);
      expect(parseBrlToCents('1500,5'), 150050);
      expect(parseBrlToCents('1.500,50'), 150050);
      expect(parseBrlToCents(r'R$ 1.500,50'), 150050);
      expect(parseBrlToCents('0,99'), 99);
      expect(parseBrlToCents('1.234.567,89'), 123456789);
    });

    test('ponto seguido de um ou dois dígitos é separador decimal', () {
      // Teclados numéricos que só oferecem ponto: "1500.50" são R$ 1.500,50,
      // não cento e cinquenta mil reais.
      expect(parseBrlToCents('1500.50'), 150050);
      expect(parseBrlToCents('12.5'), 1250);
    });

    test('recusa o que não é um valor', () {
      for (final invalid in [
        '',
        '   ',
        'abc',
        '12,345',
        '1,2,3',
        '-5',
        '12a',
      ]) {
        expect(parseBrlToCents(invalid), isNull, reason: 'entrada: "$invalid"');
      }
    });

    test('é o inverso de formatBrl', () {
      for (final cents in [0, 5, 99, 100, 150050, 123456789]) {
        expect(parseBrlToCents(formatBrl(cents)), cents);
      }
    });
  });

  group('CPF', () {
    test('aceita válidos, com ou sem pontuação', () {
      expect(isValidCpf('52998224725'), isTrue);
      expect(isValidCpf('529.982.247-25'), isTrue);
      expect(isValidCpf('111.444.777-35'), isTrue);
    });

    test('recusa inválidos', () {
      for (final invalid in [
        '52998224724',
        '11111111111',
        '5299822472',
        '529982247255',
        '5299822472A',
        '',
      ]) {
        expect(isValidCpf(invalid), isFalse, reason: 'entrada: "$invalid"');
      }
    });
  });

  group('CNPJ', () {
    test('aceita o formato numérico', () {
      expect(isValidCnpj('11222333000181'), isTrue);
      expect(isValidCnpj('11.222.333/0001-81'), isTrue);
    });

    test('aceita o formato alfanumérico de 2026', () {
      // Exemplo da documentação da Receita Federal.
      expect(isValidCnpj('12ABC34501DE35'), isTrue);
      expect(isValidCnpj('12.abc.345/01de-35'), isTrue);
    });

    test('recusa inválidos', () {
      for (final invalid in [
        '11222333000180',
        '12ABC34501DE36',
        '00000000000000',
        '1122233300018',
        '112223330001AB',
        '',
      ]) {
        expect(isValidCnpj(invalid), isFalse, reason: 'entrada: "$invalid"');
      }
    });

    test('CPF não passa como CNPJ e vice-versa', () {
      expect(isValidCnpj('52998224725'), isFalse);
      expect(isValidCpf('11222333000181'), isFalse);
    });
  });

  group('UuidGenerator', () {
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('gera UUIDs v4 bem formados', () {
      final generator = UuidGenerator();

      for (var i = 0; i < 50; i++) {
        expect(generator.newId(), matches(uuidV4));
      }
    });

    test('não repete ids, mesmo gerados em sequência imediata', () {
      final generator = UuidGenerator();

      final ids = {for (var i = 0; i < 5000; i++) generator.newId()};

      expect(ids, hasLength(5000));
    });

    test('é determinístico com um gerador semeado', () {
      expect(
        UuidGenerator(Random(7)).newId(),
        UuidGenerator(Random(7)).newId(),
      );
    });
  });

  group('AppConfig', () {
    test('sem URL configurada o app roda em modo demonstração', () {
      expect(const AppConfig().isDemoMode, isTrue);
      expect(AppConfig.parseBaseUrl(''), isNull);
      expect(AppConfig.parseBaseUrl('   '), isNull);
    });

    test('aceita URLs http(s) e remove a barra final', () {
      expect(
        AppConfig.parseBaseUrl('https://api.yvenist.com/api/v1/'),
        Uri.parse('https://api.yvenist.com/api/v1'),
      );
      expect(
        AppConfig.parseBaseUrl(' http://10.0.2.2:8000/api/v1 '),
        Uri.parse('http://10.0.2.2:8000/api/v1'),
      );
    });

    test('recusa o que não é uma URL de API', () {
      for (final invalid in ['api/v1', 'ftp://x.com', 'javascript:alert(1)']) {
        expect(AppConfig.parseBaseUrl(invalid), isNull, reason: invalid);
      }
    });

    test('a versão exibida é a mesma do pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(
        r'^version:\s*([0-9.]+)',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1);

      expect(AppConfig.appVersion, version);
    });
  });

  group('InMemoryTokenStorage', () {
    test('guarda, devolve e apaga os tokens', () async {
      final storage = InMemoryTokenStorage();
      expect(await storage.read(), isNull);

      await storage.write(
        const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      );
      expect((await storage.read())!.accessToken, 'a');

      await storage.clear();
      expect(await storage.read(), isNull);
    });
  });

  group('LoadState e falhas', () {
    test('valueOrNull só existe no sucesso', () {
      expect(const LoadSuccess(42).valueOrNull, 42);
      expect(const LoadInProgress<int>().valueOrNull, isNull);
      expect(const LoadFailure<int>(NetworkFailure()).valueOrNull, isNull);
      expect(const LoadInProgress<int>().isLoading, isTrue);
    });

    test('erros desconhecidos viram uma mensagem genérica', () {
      expect(toFailure(StateError('interno')), isA<UnexpectedFailure>());
      expect(toFailure(const NetworkFailure()), isA<NetworkFailure>());
      expect(
        describeFailure(StateError('interno')),
        isNot(contains('interno')),
      );
      expect(
        describeFailure(const ConflictFailure('Já existe um salão.')),
        'Já existe um salão.',
      );
    });
  });
}
