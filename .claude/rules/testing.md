---
paths:
  - "test/**/*.dart"
  - "backend/tests/**/*.py"
---

# Testes

Contexto completo: `docs/01-architecture/testing.md`.

- Nome do teste em português, dizendo o comportamento ("recusar exige o
  motivo"), não o nome do método.
- Defeito: escreva primeiro o teste que falha, veja falhar, corrija. Deixe o
  comentário `Regressão:` dizendo o que acontecia.
- Teste de fluxo do app: `appTest` e os auxiliares de
  `test/support/app_harness.dart`; troque uma dependência com
  `demoDependencies`. Sem rede: imagens e dados vêm de substitutos.
- Repositório da API: teste contra `FakeApi` (`test/support/fake_api.dart`),
  conferindo caminho, corpo e a tradução do erro.
- Tela nova: também em `test/app/accessibility_test.dart`.
- Nos testes de tela cada letra é um quadrado, mais largo que a letra: eles
  acham o que estoura, não o que é cortado com reticências. Para saber se um
  texto cabe, use a fonte de verdade em um arquivo próprio, como
  `test/app/field_text_fit_test.dart` (a fonte vale para o arquivo inteiro).
- Um toque que não acerta o alvo falha o teste (`appTest`). Botão fora da
  tela: `scrollToAndTap`. Item de lista ainda não montado: `reveal`.
- O erro de um campo sai com uma animação: `pumpAndSettle` antes de conferir
  que ele sumiu.
- Um controle que deveria ter ação e não tem passa pelas diretrizes de
  acessibilidade: exija a ação (`isSemantics(hasTapAction: true)`).
- Não use `find.byType` com tipo abstrato: ele só casa com o tipo exato (use
  `find.bySubtype`).
- Texto lido de um asset em teste de tela: `loadString(..., cache: false)`.
- `flutter test` pula `test/integration/`. Mudou `AppDependencies`, `AppState`
  ou o `ApiClient` → rode a integração contra uma API local antes de enviar
  (`docs/09-guides/development.md`). Esses testes montam o app sem tela: nada
  ali pode tocar em um plugin do aparelho.
- `test/integration/` roda também no navegador: sem `dart:io` direto
  (configuração por `test/support/test_environment.dart`) e sem `1 << 32`.
- Na API: fixtures de `backend/tests/conftest.py`. Teste de concorrência só
  vale com requisições realmente simultâneas (barreira + pool aquecido) e só
  roda em PostgreSQL.
- Nunca marque um teste como pulado nem afrouxe uma verificação para "passar".
- Segredo de teste é uma frase óbvia de teste, em banco descartável.
