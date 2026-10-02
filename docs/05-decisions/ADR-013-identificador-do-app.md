---
title: "ADR-013: Identificador do app — com.yvenist.app"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-013: Identificador do app — `com.yvenist.app`

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** os donos do
projeto (resposta direta à pergunta sobre o identificador; commit `a74d68c`)

## Contexto

O projeto ainda usava o identificador do modelo do Flutter,
`com.example.yvenist`. A Play Store recusa `com.example`.

## Problema

Qual identificador usar? Ele **não pode mudar depois da primeira publicação**:
é o que identifica o app nas lojas para sempre.

## Decisão

`com.yvenist.app`, igual em todas as plataformas:

| Plataforma | Onde |
|---|---|
| Android | `android/app/build.gradle.kts` (`namespace`, `applicationId`) e o pacote de `MainActivity.kt` |
| iOS | `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`) |
| macOS | `macos/Runner/Configs/AppInfo.xcconfig` |
| Linux | `linux/CMakeLists.txt` (`APPLICATION_ID`) |

## Consequências

- O app pode ser enviado à Play Store.
- Conferido no artefato: o APK de debug traz `package: name='com.yvenist.app'`.
- A convenção é o domínio ao contrário: o identificador pressupõe que
  `yvenist.com` é dos donos. OPEN QUESTION: o domínio está registrado? As lojas
  pedem essa comprovação em alguns recursos (links que abrem o app).
- Quem tinha a versão antiga instalada em um aparelho de teste fica com dois
  apps: o novo não atualiza o `com.example.yvenist`.

## Alternativas consideradas

- **`br.com.yvenist.app`** (sugerido no guia de publicação antes da decisão):
  pressupõe o domínio `yvenist.com.br`.
- **Manter `com.example.yvenist`**: impede a publicação.
