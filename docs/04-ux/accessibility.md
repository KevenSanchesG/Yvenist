---
title: Acessibilidade
type: ux
updated: 2026-10-02
---

# Acessibilidade

O que é garantido e por qual teste. Motivos:
[ADR-008](../05-decisions/ADR-008-acessibilidade-e-cores.md).

## O que é conferido automaticamente

| Critério | Mínimo | Teste |
|---|---|---|
| Contraste de texto | 4,5:1 (WCAG AA) em cada par de cor usado | `test/core/theme_contrast_test.dart` |
| Contraste do que não é texto | 3:1 no contorno de um controle e na borda do campo em foco | mesmo arquivo, grupo "componentes do Material" |
| Área de toque | 48×48 | `androidTapTargetGuideline` em `test/app/accessibility_test.dart` |
| Rótulo em todo controle tocável | sempre | `labeledTapTargetGuideline`, mesmo arquivo |
| Fonte do sistema em 200% | nenhuma tela estoura | grupo "letras grandes", mesmo arquivo |
| Semântica de botões e títulos | contadores do perfil são botões acionáveis; títulos de seção são cabeçalhos | grupo "leitores de tela" |

Telas cobertas: início, explorar, busca, escolha da festa, montagem, minhas
festas, favoritos, perfil, dados pessoais, segurança, entrar, criar conta,
convite e cadastro do salão, termos, fila de análise e seus diálogos.

## Por que o contraste é testado pelas cores, e não pelas telas

O verificador do Flutter (`textContrastGuideline`) mede a imagem na resolução
lógica e erra em letras pequenas e finas (acusou 1,36 em um texto de 12 que
era legível). O teste calcula o contraste de cada **par de tokens** que o app
usa, pela fórmula da WCAG. Ao usar um par novo (um texto colorido sobre um
fundo tingido, por exemplo), acrescente-o à lista do teste.

## Regras ao criar uma tela

1. Cor de texto: só os tokens que o teste cobre. `primary` (`#FF6600`) nunca é
   cor de texto.
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
   vez no grupo de letras grandes.

## Limites conhecidos

- `primary` (`#FF6600`) em ícones, na barra de progresso e nos indicadores de
  carregamento tem 2,94:1, logo abaixo dos 3:1 pedidos para elementos não
  textuais. Depende da decisão sobre o tom da marca.
- A borda de um campo **sem foco** é `divider` (1,2:1 com o branco): o campo é
  reconhecido pelo rótulo, não pelo contorno.
- Não foi testado com TalkBack ou VoiceOver em um aparelho de verdade: o que há
  são as verificações de semântica dos testes.
- Sem modo escuro.
- Idioma único: português do Brasil.
