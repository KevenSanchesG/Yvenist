import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Apoio para renderizar telas como imagens reais: fontes de verdade (os
/// testes normalmente desenham quadrados no lugar das letras) e fotos de
/// mentira no lugar das imagens da rede.

/// Tamanho lógico de um celular Android comum.
const Size phoneSize = Size(360, 780);
const double phonePixelRatio = 3;

Uint8List? _placeholderPng;

/// Carrega Roboto (registrada também como "Inter", a família que o app pede e
/// que cai em Roboto no Android) e a fonte de ícones do Material.
Future<void> loadRealFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT não definido: rode com "flutter test".');
  }
  final fontsDir = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<ByteData> font(String name) async {
    final bytes = await File('$fontsDir/$name').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  for (final family in ['Inter', 'Roboto']) {
    final loader = FontLoader(family)
      ..addFont(font('Roboto-Regular.ttf'))
      ..addFont(font('Roboto-Medium.ttf'))
      ..addFont(font('Roboto-Bold.ttf'));
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(font('MaterialIcons-Regular.otf'));
  await icons.load();
}

/// Gera a "foto" usada no lugar de qualquer imagem da rede.
Future<void> prepareNetworkImages() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(120, 120);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD9C3A5), Color(0xFF8E7B6B)],
      ).createShader(Offset.zero & size),
  );
  canvas.drawCircle(
    const Offset(60, 52),
    22,
    Paint()..color = const Color(0x55FFFFFF),
  );
  final image = await recorder.endRecording().toImage(120, 120);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  _placeholderPng = data!.buffer.asUint8List();
}

/// Roda [body] com toda imagem da rede recebendo a foto de mentira, sem sair
/// para a internet.
///
/// O Flutter exige que a variável de depuração volte ao normal antes de o
/// teste terminar (um `addTearDown` já seria tarde), por isso o `finally`.
Future<void> withFakeNetworkImages(Future<void> Function() body) async {
  debugNetworkImageHttpClientProvider = () => _FakeHttpClient(_placeholderPng!);
  try {
    await body();
  } finally {
    debugNetworkImageHttpClientProvider = null;
  }
}

/// Define a tela do teste como a de um celular.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = phoneSize * phonePixelRatio;
  tester.view.devicePixelRatio = phonePixelRatio;
  addTearDown(tester.view.reset);
}

/// Espera as imagens visíveis terminarem de carregar e a tela estabilizar.
///
/// A decodificação de imagem é assíncrona de verdade, e os testes de widget
/// rodam com relógio falso; por isso o `runAsync`.
Future<void> settleWithImages(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final widget = element.widget as Image;
      await precacheImage(widget.image, element);
    }
  });
  await tester.pumpAndSettle();
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this._bytes);

  final Uint8List _bytes;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeRequest(_bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this._bytes);

  final Uint8List _bytes;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeResponse(_bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this._bytes);

  final Uint8List _bytes;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
