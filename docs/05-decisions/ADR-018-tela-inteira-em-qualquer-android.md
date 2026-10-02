---
title: "ADR-018: O app desenha a tela inteira em qualquer Android"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-018: O app desenha a tela inteira em qualquer Android

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica,
a partir do que foi visto em um emulador ao conferir o tema escuro
([ADR-017](ADR-017-um-laranja-e-tema-escuro.md)).

## Contexto

O Android tem dois jeitos de dividir a tela com um app:

- **o clássico**: o app termina acima da barra de navegação do sistema (os
  três botões ou a barra de gestos), e o app só escolhe a cor dessa barra;
- **de borda a borda**: o app desenha a tela inteira, por baixo da barra de
  status e da barra de navegação, e o sistema diz quanto espaço cada uma
  ocupa.

O que valia no projeto, conferido em um emulador com Android 13 e na
documentação do Flutter 3.41 (`SystemUiMode`, em `system_chrome.dart`):

- do Android 15 em diante o sistema **impõe** o segundo jeito a um app que mira
  a API 35 ou mais nova, e a cor pedida para a barra de navegação é ignorada.
  O projeto mira a API 36, que a Play Store exige
  ([android-release](../09-guides/android-release.md));
- do Android 14 para trás valia o jeito clássico. O app pedia a barra na cor
  dos cartões (`surface`).

Ou seja: o app tinha dois leiautes, e o que a maior parte dos aparelhos novos
recebe (borda a borda) não era o que se via na máquina de desenvolvimento, que
só tem a imagem do Android 13. Dois defeitos apareceram ao olhar:

- no tema escuro, nas telas empilhadas, a barra do sistema ficava em um tom
  diferente do fundo da tela: uma faixa;
- no perfil, o conteúdo rolava por baixo do relógio da barra de status.

## Problema

Manter dois leiautes, um deles sem como ser visto, ou ter um só?

## Decisão

**Um leiaute só: borda a borda em todo Android que permite** (do 10 em
diante).

- `lib/main.dart` pede esse modo ao Android ao abrir
  (`SystemUiMode.edgeToEdge`). No iOS já é assim.
- A barra de navegação do sistema é **transparente**
  (`AppTheme.systemUi`, em `lib/core/theme/app_theme.dart`): o que aparece ali
  é o que a tela desenha. O estilo é aplicado uma vez, em volta do app inteiro
  (`AppTheme.systemBars`, no `builder` do `MaterialApp`); a barra do topo de
  cada tela pede só o estilo da barra de status.
- Cada tela cuida da borda de baixo:
  - a barra inferior do app e os rodapés fixos vão até a borda e guardam,
    dentro deles, o espaço da barra do sistema;
  - uma lista que vai até a borda soma esse espaço à margem
    (`context.withSystemBottomInset`, em `lib/core/widgets/system_insets.dart`):
    o conteúdo passa por baixo da barra ao rolar, e o último item para acima
    dela.
- No perfil, um fundo na cor da tela cobre a barra de status assim que o
  cabeçalho sai de baixo dela (`_StatusBarBackdrop`, em `profile_page.dart`).
- **No Android 9 ou mais antigo** o pedido não tem efeito e o leiaute é o
  clássico. O app percebe isso pelo espaço que o sistema informa (zero) e,
  nesse caso, pede a barra de navegação na cor `surface`: transparente, ela
  mostraria o fundo da janela, que é branco e não acompanha o tema escolhido
  (com o tema escuro, botões brancos sobre fundo branco).

A barra de três botões continua com a película de contraste que o próprio
Android põe por baixo deles; o app não a desliga.

## Consequências

- O que é conferido no emulador (Android 13) é o leiaute que o Android 15 e os
  seguintes impõem. A faixa do tema escuro e o conteúdo por baixo do relógio
  deixaram de existir.
- **Toda tela nova tem de cuidar da borda de baixo.** Uma lista com margem
  fixa esconde o último item por baixo dos botões do sistema. Os testes de
  tela rodam sem barras do sistema e não veem isso; `test/app/system_bars_test.dart`
  dá ao teste as barras de um aparelho e confere as telas que vão até a borda.
- Não há mais como escolher a cor da barra de navegação por tela, e nem
  precisa: ela mostra a tela.
- O Android 9 e os anteriores ficam com o leiaute clássico, que não foi visto
  em um aparelho nem em um emulador dessas versões
  ([KI-45](../07-known-issues/README.md)). No Android 7, a cor da barra de
  navegação não é alterada pelo Flutter: fica a padrão do sistema.

## Alternativas consideradas

- **Manter o leiaute clássico até o Android 14 e acertar a cor da barra tela
  por tela**: resolveria a faixa, mas manteria dois leiautes, e o do Android
  15 em diante continuaria sem ser visto antes de chegar aos aparelhos.
- **Barra transparente sem pedir o modo de borda a borda**: foi o primeiro
  teste. No Android 13 a barra mostrou o fundo da janela, branco, por baixo do
  app escuro.
- **Barra transparente sempre, inclusive no leiaute clássico**: no Android 8 e
  9, com o tema escuro, os botões do sistema ficariam brancos sobre o fundo
  branco da janela.
- **`SafeArea` em volta de cada tela**: resolve o último item escondido, mas o
  conteúdo deixa de passar por baixo da barra e sobra uma faixa vazia na borda,
  na cor do fundo, mesmo com a barra de gestos, que é só um traço.
- **Baixar o alvo para a API 34**: evitaria a imposição do Android 15, mas a
  Play Store não aceita.
