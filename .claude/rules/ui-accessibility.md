---
paths:
  - "lib/**/presentation/**/*.dart"
  - "lib/core/theme/**/*.dart"
  - "lib/core/widgets/**/*.dart"
  - "lib/app/**/*.dart"
---

# Interface e acessibilidade

Contexto completo: `docs/04-ux/design-system.md` e `docs/04-ux/accessibility.md`.

- Cor, fonte e espaçamento só pelos tokens de `lib/core/theme/`. Nada de
  `Color(0x…)` nem `fontSize` solto em uma tela.
- `AppColors.primary` (`#FF6600`) é para ícone e área grande. Texto, link e
  botão usam `AppColors.primaryStrong`.
- Par novo de cor de texto e fundo → acrescente a
  `test/core/theme_contrast_test.dart` (mínimo 4,5:1).
- Todo `IconButton` tem `tooltip` dizendo o que ele afeta ("Remover Salão
  Glamour 8"). Ícone decorativo fica em `ExcludeSemantics`. Título de seção:
  `Semantics(header: true)`.
- Área de toque mínima de 48×48.
- A tela não pode estourar com a fonte do sistema em 200%: use `OverflowBar`
  ou `Wrap` para botões lado a lado, e rolagem onde o conteúdo pode não caber.
- Um widget desenhado fora dos limites do pai não recebe toque.
- Botão que não pode agir fica desabilitado, em vez de responder com erro.
- Ação destrutiva pede confirmação.
- Tela nova ou alterada → inclua em `test/app/accessibility_test.dart` (grupo
  das diretrizes e grupo das letras grandes) e, se tiver captura em
  `docs/screenshots/`, regenere.
- O tom do laranja da marca é decisão dos donos: não mude `AppColors.primary`.
