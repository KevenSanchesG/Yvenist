---
title: "ADR-016: Identificador do app — br.com.yvenist.app"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-016: Identificador do app — `br.com.yvenist.app`

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** os donos do
projeto (resposta direta à pergunta sobre o identificador). Substitui o
[ADR-013](ADR-013-identificador-do-app.md).

## Contexto

O [ADR-013](ADR-013-identificador-do-app.md) tinha escolhido `com.yvenist.app`
e deixado uma pergunta: a convenção é o domínio ao contrário, e ninguém tinha
conferido se `yvenist.com` era dos donos.

Em 2 de outubro de 2026 os donos confirmaram que o domínio deles é
**`yvenist.com.br`**, e os registros públicos foram consultados no mesmo dia:

| Domínio | Situação |
|---|---|
| `yvenist.com.br` | registrado e ativo desde 6 de janeiro de 2026; sem site apontado |
| `yvenist.com` | não está registrado por ninguém |

O app nunca foi publicado, então o identificador ainda podia mudar.

## Problema

Manter um identificador que aponta para um domínio que não é dos donos, ou
trocar enquanto ainda é possível?

## Decisão

`br.com.yvenist.app`, igual em todas as plataformas:

| Plataforma | Onde |
|---|---|
| Android | `android/app/build.gradle.kts` (`namespace`, `applicationId`) e o pacote de `MainActivity.kt` (`android/app/src/main/kotlin/br/com/yvenist/app/`) |
| iOS | `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`) |
| macOS | `macos/Runner/Configs/AppInfo.xcconfig` e `macos/Runner.xcodeproj/project.pbxproj` |
| Linux | `linux/CMakeLists.txt` (`APPLICATION_ID`) |

## Consequências

- O identificador segue um domínio que é dos donos. Recursos das lojas que
  pedem prova de domínio (links que abrem o app) usarão `yvenist.com.br`.
- **Depois da primeira publicação não muda mais**: é o que identifica o app nas
  lojas para sempre.
- Conferido no artefato: o APK de debug traz o pacote `br.com.yvenist.app` e a
  atividade `br.com.yvenist.app.MainActivity`. iOS, macOS e Linux não foram
  compilados.
- Quem tinha uma versão anterior instalada em um aparelho de teste fica com
  dois apps: o novo não atualiza o `com.yvenist.app`.
- Os endereços de exemplo do projeto passaram a usar o domínio dos donos: a
  conta de demonstração é `demo@yvenist.com.br`.

## Alternativas consideradas

- **Manter `com.yvenist.app` e registrar `yvenist.com`**: nada mudaria no
  código, ao custo de mais um domínio para manter.
- **Manter `com.yvenist.app` sem registrar o `.com`**: funciona, porque as
  lojas não conferem o domínio, mas o identificador ficaria apontando para um
  domínio que outra pessoa pode registrar.
