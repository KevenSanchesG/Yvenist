---
title: "ADR-008: Dois laranjas; contraste testado pelos tokens"
type: adr
status: substituída por ADR-017
date: 2026-10-02
---

# ADR-008: Dois laranjas; contraste testado pelos tokens

**Status:** **substituída pelo
[ADR-017](ADR-017-um-laranja-e-tema-escuro.md)** no mesmo dia: os donos
escolheram `#C2410C` como tom único e pediram o tema escuro. O contraste
conferido por teste e as superfícies neutras continuam valendo, e estão lá. O
texto abaixo fica como registro do que tinha sido decidido · **Data:**
2026-10-02 · **Decidida por:** evolução técnica (commits `790377a`, `948339e`,
`68a8c8d`)

## Contexto

O laranja da marca, `#FF6600`, tem contraste **2,94:1** sobre branco. O mínimo
da WCAG AA para texto é 4,5:1. O protótipo usava esse laranja em texto,
botões e links, e fontes de 8 a 10.

## Problema

Como tornar o app legível sem trocar a cor da marca, que é decisão dos donos?

## Decisão

- **Dois tokens**: `primary` (`#FF6600`) só para ícones e áreas grandes;
  `primaryStrong` (`#C2410C`, 5,2:1) para texto, links, botões e, no tema do
  Material, para os controles.
- **O contraste é conferido por teste sobre os pares de tokens**
  (`theme_contrast_test.dart`), e não sobre telas renderizadas.
- **Superfícies neutras** no tema: o Material 3 tinge cartões, menus e listas
  com a cor da marca, e com laranja eles saem rosados.
- Área de toque de 48×48, rótulo em todo controle, nenhuma tela estourando com
  a fonte em 200%: conferidos nas telas reais (`accessibility_test.dart`).
- Nenhum texto abaixo de 11.

## Consequências

- Texto e botões passam em AA sem mudar a identidade.
- Quem cria uma tela tem de saber que `primary` não é cor de texto, e
  acrescentar ao teste qualquer par novo de cores.
- Ícones e a borda de foco em `primary` ficam em 2,94:1, logo abaixo dos 3:1
  pedidos para elementos não textuais.
- **Pendência (dos donos):** escolher o tom definitivo da marca. Um laranja um
  pouco mais escuro dispensaria os dois tokens.

## Alternativas consideradas

- **Escurecer a cor da marca**: resolveria de vez, mas não é uma decisão
  técnica.
- **Usar o verificador de contraste do Flutter nas telas**
  (`textContrastGuideline`): foi tentado. Ele mede a imagem na resolução lógica
  e acusa texto pequeno e fino que é legível (1,36 e 2,02 para letras de 11 e
  12). Os problemas reais que ele achou (3,66 de branco sobre o degradê; 4,35
  de legenda sobre cinza) foram corrigidos, e a verificação virou conta exata
  sobre os tokens.
- **Sobrescrever a cor de cada componente do Material, um a um**: foi feito
  primeiro para diálogos e menus; cartões e listas suspensas ficaram de fora e
  apareceram rosados na versão web. Corrigir o esquema de cores resolve a
  causa.

## Atualização de 2026-10-02: a mesma decisão, aplicada até o fim

A decisão não mudou. A revisão visual mostrou que ela tinha sido aplicada só a
uma parte do esquema de cores, e o resto continuava derivado do laranja:

- o segmento escolhido do botão segmentado e o filtro marcado saíam rosados;
- o contorno dos filtros saía rosado e o do botão segmentado, marrom;
- rótulo de campo, de filtro e os números do calendário saíam marrons, ao lado
  do cinza do texto das telas;
- o aviso (SnackBar) saía em marrom escuro com texto rosado;
- a borda do campo em foco ficava em `primary` enquanto o rótulo e o cursor
  usavam `primaryStrong`: dois laranjas no mesmo campo.

Todos passaram a usar tokens do app; a tabela de papéis está em
[design-system](../04-ux/design-system.md). Com isso a consequência "ícones e a
borda de foco em `primary` ficam em 2,94:1" vale agora **só para ícones e
áreas grandes**: a borda de foco tem 5,2:1. O item selecionado segue o destaque
que o app já usava no seletor de modo do perfil, então nenhuma cor nova foi
criada. A pendência dos donos (o tom da marca) continua a mesma.
