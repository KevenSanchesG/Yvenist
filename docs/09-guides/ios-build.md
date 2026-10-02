---
title: iOS — preparação para o primeiro build em um Mac
type: guide
updated: 2026-10-02
---

# iOS: preparação para o primeiro build em um Mac

**O app nunca foi compilado para iOS.** Compilar exige um Mac com Xcode, e o
projeto é escrito em Windows ([KI-05](../07-known-issues/README.md)). Este guia
separa o que já está pronto, conferido lendo os arquivos em 2 de outubro de
2026, do que só dá para fazer no Mac. Nada aqui foi executado em iOS.

## O que já está pronto

| Item | Como está | Onde |
|---|---|---|
| Identificador | `com.yvenist.app` nas três configurações; os testes usam `com.yvenist.app.RunnerTests` | `ios/Runner.xcodeproj/project.pbxproj` |
| Nome na tela inicial | `Yvenist` | `CFBundleDisplayName` em `ios/Runner/Info.plist` |
| Versão | vem do `pubspec.yaml` (`FLUTTER_BUILD_NAME` e `FLUTTER_BUILD_NUMBER`) | `ios/Runner/Info.plist` |
| iOS mínimo | 13.0, igual ao mínimo do único plugin nativo (`flutter_secure_storage_darwin` 0.4.3) | `IPHONEOS_DEPLOYMENT_TARGET` |
| Ícones | as 19 entradas têm arquivo; o de 1024×1024 é RGB, **sem canal alfa** (a App Store recusa transparência) | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Permissões | nenhuma descrição de uso, porque o app não usa câmera, fotos, localização nem contatos | `ios/Runner/Info.plist` |
| Rede | sem exceção de segurança de transporte: só `https`, como no release do Android | `ios/Runner/Info.plist` (não há `NSAppTransportSecurity`) |
| Fonte, textos legais, tema | são arquivos e código do Flutter, iguais em todas as plataformas | `pubspec.yaml`, `lib/` |
| Relógio sobre o cabeçalho escuro do perfil | já tem o valor do iOS (`statusBarBrightness`) | `lib/core/theme/app_theme.dart` |
| Código sem `dart:io` em `lib/` | nada do app depende de uma plataforma | regra em `.claude/rules/flutter-app.md` |
| Exclusão de conta dentro do app | existe (Perfil → Segurança). A App Store a exige de todo app que cria conta, desde 30 de junho de 2022 | `security_page.dart` |

## O que só o Mac resolve

Em ordem. Cada item é uma pendência até ser feito e conferido.

1. **Ferramentas**: Xcode, e `flutter doctor` sem apontamento em iOS.
2. **Primeira resolução de dependências**: `flutter pub get` e
   `flutter build ios --debug --no-codesign`. O Flutter cria `ios/Podfile` e
   `ios/Podfile.lock` (ou resolve o plugin pelo Swift Package Manager, que ele
   também oferece) e pode propor atualizações do projeto do Xcode. **Versione o
   que for criado ou alterado.** `[INFERÊNCIA]` quais arquivos mudam depende da
   versão do Flutter e do Xcode.
3. **Rodar no simulador** contra a API:
   `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`.
   `[INFERÊNCIA]` o endereço da própria máquina deve ser aceito em debug; em
   um iPhone de verdade, uma API em `http` na rede local é barrada. Use uma
   API em `https`.
4. **Passar pelos fluxos**: criar conta, entrar, fechar e reabrir (a sessão
   volta do Keychain), favoritar, montar uma festa, anunciar um salão, excluir
   a conta. No Android esses passos foram feitos em um emulador.
5. **Keychain** ([KI-40](../07-known-issues/README.md)): hoje os tokens usam o
   padrão do pacote (`KeychainAccessibility.unlocked`), que entra no backup
   cifrado do aparelho e pode ir para um aparelho novo. No Android o backup
   foi desligado de propósito. Decidir se o iOS deve usar uma opção "só neste
   aparelho" (`IOSOptions` em `lib/core/storage/token_storage.dart`) e conferir
   o comportamento ao reinstalar e ao restaurar.
6. **iPad e orientação**: o projeto declara iPhone e iPad
   (`TARGETED_DEVICE_FAMILY = "1,2"`) e aceita paisagem. O desenho é de celular
   em pé ([KI-32](../07-known-issues/README.md)). OPEN QUESTION: publicar só
   para iPhone, ou testar no iPad.
7. **Leitor de tela**: VoiceOver nas telas principais
   ([KI-41](../07-known-issues/README.md)).
8. **Assinatura**: conta no Apple Developer Program (dos donos), a equipe
   escolhida no Xcode (hoje não há `DEVELOPMENT_TEAM` no projeto) e o
   identificador `com.yvenist.app` registrado na conta.
9. **App Store Connect**: a URL da política de privacidade
   ([legal](../03-features/legal.md)), as respostas de privacidade (o
   levantamento está em [personal-data](../01-architecture/personal-data.md)),
   a declaração sobre criptografia (o app só usa `https` e o cofre do
   sistema), capturas de tela e classificação etária.
10. **CI**: um job em um executor macOS, se os donos quiserem que o iOS seja
    compilado a cada envio. Hoje o [CI](ci.md) não cobre iOS.

## O que não fazer sem um Mac

- Não marcar nenhum item de iOS como verificado.
- Não editar `project.pbxproj` à mão para "preparar" assinatura: o Xcode
  reescreve o arquivo, e um erro ali só aparece no build.
