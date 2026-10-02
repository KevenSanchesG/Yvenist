import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/storage/token_storage.dart';

/// O cofre do sistema, visto pelo canal que o plugin usa para falar com o
/// Android/iOS. Guarda os valores em um mapa e pode ser mandado falhar.
class FakeKeystore {
  FakeKeystore() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _handle);
  }

  static const MethodChannel _channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  final Map<String, String> values = {};
  final List<String> calls = [];
  bool failOnRead = false;

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call.method);
    final arguments = (call.arguments as Map).cast<String, Object?>();
    final key = arguments['key'] as String?;

    switch (call.method) {
      case 'read':
        if (failOnRead) {
          throw PlatformException(
            code: 'InvalidKeyException',
            message: 'Failed to unwrap key',
          );
        }
        return values[key];
      case 'write':
        values[key!] = arguments['value']! as String;
        return null;
      case 'delete':
        values.remove(key);
        return null;
      default:
        return null;
    }
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tokens = AuthTokens(accessToken: 'acesso', refreshToken: 'renovacao');
  late FakeKeystore keystore;

  setUp(() => keystore = FakeKeystore());
  tearDown(() => keystore.dispose());

  /// Um app recém-aberto: nada em memória ainda, só o que está no cofre.
  SecureTokenStorage freshStorage() {
    return SecureTokenStorage(const FlutterSecureStorage());
  }

  test('sem nada guardado, não há sessão', () async {
    expect(await freshStorage().read(), isNull);
  });

  test('os tokens gravados sobrevivem a fechar e abrir o app', () async {
    await freshStorage().write(tokens);

    final restored = await freshStorage().read();

    expect(restored!.accessToken, 'acesso');
    expect(restored.refreshToken, 'renovacao');
  });

  test('guarda cada token em uma chave própria do Yvenist', () async {
    await freshStorage().write(tokens);

    expect(keystore.values, {
      'yvenist.access_token': 'acesso',
      'yvenist.refresh_token': 'renovacao',
    });
  });

  test('depois da primeira leitura não volta ao cofre', () async {
    await freshStorage().write(tokens);
    final storage = freshStorage();

    await storage.read();
    final readsAfterFirst = keystore.calls.where((c) => c == 'read').length;
    await storage.read();
    await storage.read();

    expect(keystore.calls.where((c) => c == 'read').length, readsAfterFirst);
  });

  test('um par incompleto não é uma sessão', () async {
    keystore.values['yvenist.access_token'] = 'acesso';

    expect(await freshStorage().read(), isNull);
  });

  test('apagar remove do cofre e da memória', () async {
    final storage = freshStorage();
    await storage.write(tokens);

    await storage.clear();

    expect(await storage.read(), isNull);
    expect(keystore.values, isEmpty);
    expect(await freshStorage().read(), isNull);
  });

  test('se o cofre falhar na leitura, o app abre sem sessão', () async {
    // Acontece, por exemplo, quando os dados do app são restaurados em outro
    // aparelho: os tokens cifrados vêm, a chave que os decifra não.
    await freshStorage().write(tokens);
    keystore.failOnRead = true;
    final storage = freshStorage();

    expect(await storage.read(), isNull);

    // Nada foi apagado por causa da falha...
    expect(keystore.values, hasLength(2));
    // ...e entrar de novo regrava os tokens e segue a vida.
    await storage.write(
      const AuthTokens(accessToken: 'novo', refreshToken: 'nova'),
    );
    expect((await storage.read())!.accessToken, 'novo');
    keystore.failOnRead = false;
    expect((await freshStorage().read())!.refreshToken, 'nova');
  });
}
