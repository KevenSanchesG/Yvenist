---
title: Acessibilidade
type: ux
updated: 2026-10-02
---

# Acessibilidade

O que é garantido e por qual teste, **nos dois temas** (claro e escuro).
Motivos: [ADR-017](../05-decisions/ADR-017-um-laranja-e-tema-escuro.md).

## O que é conferido automaticamente

| Critério | Mínimo | Teste |
|---|---|---|
| Contraste de texto | 4,5:1 (WCAG AA) em cada par de cor usado, em cada tema | `test/core/theme_contrast_test.dart` |
| Contraste do que não é texto | 3:1 no contorno de um controle e na borda do campo em foco | mesmo arquivo, grupo "componentes do Material" |
| Área de toque | 48×48 | `androidTapTargetGuideline` em `test/app/accessibility_test.dart` |
| Rótulo em todo controle tocável | sempre | `labeledTapTargetGuideline`, mesmo arquivo |
| Fonte do sistema em 200% | nenhuma tela estoura | grupo "letras grandes", mesmo arquivo |
| Semântica de botões e títulos | contadores do perfil são botões acionáveis; títulos de seção são cabeçalhos | grupo "leitores de tela" |
| Tema escuro | os fluxos principais de novo, com as mesmas conferências; nenhuma tela estoura | grupo "tema escuro", mesmo arquivo |
| Cor só pelo tema | nenhuma cor escrita à mão fora de `lib/core/theme/` | `test/core/theme_usage_test.dart` |
| Nada escondido pelas barras do sistema | o último item de uma lista e os botões de um rodapé ficam acima da barra de navegação; no perfil, o conteúdo não passa por baixo do relógio | `test/app/system_bars_test.dart` |

Telas cobertas: início, explorar, busca, escolha da festa, montagem, minhas
festas, favoritos, perfil (com conta e de visitante), dados pessoais,
aparência, segurança, entrar, criar conta, convite e cadastro do salão,
termos, fila de análise e seus diálogos.

## Por que o contraste é testado pelas cores, e não pelas telas

O verificador do Flutter (`textContrastGuideline`) mede a imagem na resolução
lógica e erra em letras pequenas e finas (acusou 1,36 em um texto de 12 que
era legível). O teste calcula o contraste de cada **par de tokens** que o app
usa, pela fórmula da WCAG, uma vez para cada tema. Ao usar um par novo (um
texto colorido sobre um fundo tingido, por exemplo), acrescente-o à lista do
teste.

## Regras ao criar uma tela

1. Cor: só pelas cores do tema em uso (`context.colors`, `context.text`), nos
   pares que o teste cobre. Uma cor escrita à mão vale para um tema só.
2. Todo `IconButton` tem `tooltip` com o nome do que ele afeta ("Favoritar
   Salão Glamour 8"), não só "Favoritar".
3. Ícone decorativo fica dentro de `ExcludeSemantics`.
4. Título de seção: `Semantics(header: true)`.
5. Mensagem que aparece sozinha (erro de formulário, carregando):
   `Semantics(liveRegion: true)`.
6. Nada de `Row` com dois botões largos sem saída: use `OverflowBar` ou
   `Wrap`, que empilham quando a fonte cresce.
7. Tela que pode não caber em 200%: rolável (`SingleChildScrollView`, ou
   `_FillOrScroll` como em `vendor_welcome_page.dart`).
8. Um widget desenhado **fora dos limites do pai não recebe toque**. Para
   sobrepor (o seletor do perfil, o botão central), reserve o espaço dentro da
   pilha ou use o lugar do botão flutuante do `Scaffold`.
9. Acrescente a tela ao `accessibility_test.dart`: uma vez nas diretrizes, uma
   vez no grupo de letras grandes e, se ela tiver cartões, bordas ou sombras
   próprias, uma vez no grupo do tema escuro.
10. A tela vai até a borda de baixo, por baixo da barra de navegação do
    sistema. Uma lista soma esse espaço à margem
    (`context.withSystemBottomInset`); um rodapé fixo vai até a borda e guarda
    o espaço dentro dele. Tela nova que vai até a borda entra em
    `test/app/system_bars_test.dart`.
11. No tema escuro uma borda substitui a sombra. Em um cartão de altura fixa,
    desenhe a borda por cima (`foregroundDecoration`): como borda do fundo ela
    tira espaço do conteúdo, e o card de anúncio estourava por um pixel.

## Limites conhecidos

- A borda de um campo **sem foco** é `divider` (1,2:1 no tema claro, 1,4:1 no
  escuro): o campo é reconhecido pelo rótulo, não pelo contorno.
- Não foi testado com TalkBack ou VoiceOver em um aparelho de verdade: o que há
  são as verificações de semântica dos testes.
- O tema escuro foi conferido pelos testes e por imagem (as capturas), e em um
  emulador Android; não em um aparelho de verdade.
- Idioma único: português do Brasil.
