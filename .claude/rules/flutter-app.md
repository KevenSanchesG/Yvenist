---
paths:
  - "lib/**/*.dart"
---

# App Flutter

Contexto completo: `docs/01-architecture/clean-architecture.md`.

- Dentro de `lib/features/<x>/`: `domain/` não importa Flutter nem rede;
  `presentation/` conhece só contratos de `domain/`; `data/` implementa.
- Contrato novo → `Api…Repository` **e** `InMemory…Repository`, registrados em
  `lib/app/app_dependencies.dart` (construtor e fábricas `api` e `demo`) e em
  `test/support/app_harness.dart`. O modo demonstração segue as mesmas regras
  da API.
- Repositório lança `AppFailure`; controller devolve `bool`/valor e guarda a
  falha. Nenhuma exceção chega a um widget. Mensagem em português, sem termo
  técnico.
- Dado assíncrono tem os três estados na tela: carregando, erro com "Tentar
  novamente", conteúdo (`LoadState<T>`).
- Controller que carrega para uma conta descarta a resposta se a conta mudou
  no meio; depois de `dispose` não notifica (`_disposed`).
- Controller do app inteiro entra em `AppState`; o de uma tela é criado pela
  própria página com `ChangeNotifierProvider(create:)`.
- Falhar fechado: valor desconhecido vindo da API nunca libera nada.
- Sem `dart:io` em `lib/`: o app também compila para a web.
- Função prevista e não construída: item visível com "Em breve", sem `onTap`.
- Antes de concluir: `dart format lib test`, `flutter analyze` sem
  apontamentos, `flutter test`.
