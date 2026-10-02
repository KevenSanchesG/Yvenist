import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registra as licenças de terceiros que não vêm de pacotes Dart, para que
/// apareçam em "Licenças de código aberto" junto com as demais.
///
/// Hoje é só a da fonte Inter: a licença dela (OFL) exige que o texto
/// acompanhe o programa que a distribui.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/Inter-OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Inter (fonte)'], license);
  });
}
