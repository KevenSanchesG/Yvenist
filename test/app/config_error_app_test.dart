import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/app/config_error_app.dart';
import 'package:yvenist/core/config/app_config.dart';

void main() {
  testWidgets('um build mal configurado diz o que está errado', (tester) async {
    // O que o main() faz quando a API_BASE_URL do build não serve.
    late final String message;
    try {
      AppConfig.fromRaw('api.yvenist.com.br/api/v1', isRelease: true);
    } on FormatException catch (error) {
      message = error.message;
    }

    await tester.pumpWidget(ConfigErrorApp(message: message));

    expect(find.text('App configurado incorretamente'), findsOneWidget);
    expect(find.textContaining('API_BASE_URL inválida'), findsOneWidget);
    expect(find.textContaining('api.yvenist.com.br/api/v1'), findsOneWidget);
  });
}
