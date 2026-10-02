import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/storage/theme_preference_storage.dart';
import 'package:yvenist/core/theme/theme_mode_controller.dart';

import '../support/fake_keystore.dart';

/// Um lugar de guardar cuja leitura só volta quando o teste manda.
class _SlowStorage implements ThemePreferenceStorage {
  final Completer<ThemeMode?> pending = Completer();
  ThemeMode? written;

  @override
  Future<ThemeMode?> read() => pending.future;

  @override
  Future<void> write(ThemeMode mode) async => written = mode;
}

/// O pacote como ele se comporta na web fora de um contexto seguro (uma página
/// em `http` que não é `localhost`): ler e gravar lançam `UnsupportedError`,
/// que é um `Error`, e não uma `Exception`.
class _InsecureContextStorage extends FlutterSecureStorage {
  const _InsecureContextStorage();

  static const _message =
      'FlutterSecureStorageWeb only works in secure contexts';

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw UnsupportedError(_message);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw UnsupportedError(_message);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeController', () {
    test('sem escolha guardada, vale o tema do aparelho', () async {
      final controller = ThemeModeController(InMemoryThemePreferenceStorage());

      await controller.load();

      expect(controller.mode, ThemeMode.system);
    });

    test('ao abrir, lê a escolha guardada e avisa quem ouve', () async {
      final controller = ThemeModeController(
        InMemoryThemePreferenceStorage(ThemeMode.dark),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.load();

      expect(controller.mode, ThemeMode.dark);
      expect(notifications, 1);
    });

    test('escolher muda na hora, avisa e guarda', () async {
      final storage = InMemoryThemePreferenceStorage();
      final controller = ThemeModeController(storage);
      final seen = <ThemeMode>[];
      controller.addListener(() => seen.add(controller.mode));

      final saving = controller.select(ThemeMode.dark);

      // Antes mesmo de a gravação terminar a tela já mudou.
      expect(controller.mode, ThemeMode.dark);
      expect(seen, [ThemeMode.dark]);
      await saving;
      expect(await storage.read(), ThemeMode.dark);
    });

    test('escolher o tema que já vale não avisa de novo', () async {
      final controller = ThemeModeController(InMemoryThemePreferenceStorage());
      await controller.select(ThemeMode.light);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.select(ThemeMode.light);

      expect(notifications, 0);
    });

    test(
      'uma escolha feita antes de a leitura voltar vale mais que ela',
      () async {
        final storage = _SlowStorage();
        final controller = ThemeModeController(storage);

        final loading = controller.load();
        await controller.select(ThemeMode.light);
        storage.pending.complete(ThemeMode.dark);
        await loading;

        expect(controller.mode, ThemeMode.light);
        expect(storage.written, ThemeMode.light);
      },
    );

    test('ler duas vezes não desfaz uma escolha', () async {
      final controller = ThemeModeController(
        InMemoryThemePreferenceStorage(ThemeMode.dark),
      );
      await controller.load();
      await controller.select(ThemeMode.light);

      await controller.load();

      expect(controller.mode, ThemeMode.light);
    });

    test('depois de descartado não avisa ninguém', () async {
      final storage = _SlowStorage();
      final controller = ThemeModeController(storage);
      final loading = controller.load();

      controller.dispose();
      storage.pending.complete(ThemeMode.dark);

      // Sem o cuidado, avisar depois do dispose lança uma exceção.
      await expectLater(loading, completes);
    });
  });

  group('DeviceThemePreferenceStorage', () {
    late FakeKeystore keystore;

    setUp(() => keystore = FakeKeystore());
    tearDown(() => keystore.dispose());

    /// Um app recém-aberto: só o que está guardado no aparelho.
    DeviceThemePreferenceStorage freshStorage() {
      return DeviceThemePreferenceStorage(const FlutterSecureStorage());
    }

    test('sem nada guardado, não há escolha', () async {
      expect(await freshStorage().read(), isNull);
    });

    test('a escolha sobrevive a fechar e abrir o app', () async {
      await freshStorage().write(ThemeMode.dark);

      expect(await freshStorage().read(), ThemeMode.dark);
      expect(keystore.values, {'yvenist.theme_mode': 'dark'});
    });

    test('cada tema é guardado e lido de volta', () async {
      for (final mode in ThemeMode.values) {
        await freshStorage().write(mode);

        expect(await freshStorage().read(), mode);
      }
    });

    test('um valor que o app não conhece é como não ter escolhido', () async {
      keystore.values['yvenist.theme_mode'] = 'roxo';

      expect(await freshStorage().read(), isNull);
    });

    test(
      'se o aparelho falhar ao ler, o app abre no tema do sistema',
      () async {
        await freshStorage().write(ThemeMode.dark);
        keystore.failOnRead = true;

        expect(await freshStorage().read(), isNull);
      },
    );

    test('se o aparelho falhar ao gravar, a escolha vale até fechar o '
        'app', () async {
      keystore.failOnWrite = true;
      final controller = ThemeModeController(freshStorage());

      await controller.select(ThemeMode.dark);

      expect(controller.mode, ThemeMode.dark);
      expect(keystore.values, isEmpty);
    });

    test('na web fora de um contexto seguro, o app abre e a escolha vale até '
        'fechar', () async {
      // Regressão: ali o pacote lança UnsupportedError, que não é uma
      // Exception. A falha escapava: ao gravar, como erro sem tratamento; ao
      // ler, antes da primeira tela, impedindo o app de abrir.
      final controller = ThemeModeController(
        DeviceThemePreferenceStorage(const _InsecureContextStorage()),
      );

      await controller.load();
      expect(controller.mode, ThemeMode.system);

      await controller.select(ThemeMode.dark);
      expect(controller.mode, ThemeMode.dark);
    });
  });
}
