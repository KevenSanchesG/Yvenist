---
paths:
  - "lib/**/presentation/**/*.dart"
  - "lib/core/theme/**/*.dart"
  - "lib/core/widgets/**/*.dart"
  - "lib/app/**/*.dart"
---

# Interface e acessibilidade

Contexto completo: `docs/04-ux/design-system.md` e `docs/04-ux/accessibility.md`.

- O app tem dois temas, claro e escuro. **Toda tela funciona nos dois.**
- Cor e estilo de texto só pelo tema em uso: `context.colors` e `context.text`
  (`lib/core/theme/app_theme.dart`). Nada de `Color(0x…)`, `Colors.white` nem
  `fontSize` solto em uma tela: `test/core/theme_usage_test.dart` falha.
- `AppColors` é só para o que é igual nos dois temas (degradês com texto
  branco, película sobre foto).
- O laranja (`colors.primary`) é a cor de ação: o que se toca, o que está
  selecionado, o preço. Não é cor de texto corrido nem de fundo de tela.
- Par novo de cor de texto e fundo → acrescente a
  `test/core/theme_contrast_test.dart` (mínimo 4,5:1), que confere os dois
  temas. `textTertiary` não vai sobre `surfaceMuted`; `tint(primary)` só sobre
  `background` e `surface`.
- No tema escuro a sombra não se vê: o que se destacava por sombra ganha
  borda (`colors.isDark`). Em cartão de altura fixa, a borda vai em
  `foregroundDecoration`, para não tirar espaço do conteúdo.
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
  das diretrizes, grupo das letras grandes e, se tiver cartões ou bordas
  próprias, grupo do tema escuro) e, se tiver captura em `docs/screenshots/`,
  regenere. Olhe a captura do tema escuro: a suíte normal roda no claro.
- O tom do laranja da marca é decisão dos donos (`#C2410C`, ADR-017): não mude
  `AppColors.brand`.
