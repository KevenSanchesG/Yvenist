import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  bool failOnWrite = false;

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
        if (failOnWrite) {
          throw PlatformException(code: 'WriteFailed', message: 'No space');
        }
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
