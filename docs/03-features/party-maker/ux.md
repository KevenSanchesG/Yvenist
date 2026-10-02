---
title: Party Maker — telas e experiência
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — telas e experiência

Tokens, componentes e regras gerais: [design-system](../../04-ux/design-system.md)
e [accessibility](../../04-ux/accessibility.md). Aqui só o que é do Party Maker.

## Telas

| Tela | Arquivo | Captura |
|---|---|---|
| Entrada da aba (decide o que mostrar) | `pages/party_maker_entry_page.dart` | — |
| Hub "Minhas Festas" | `pages/my_parties_page.dart` | ![Minhas festas](../../screenshots/minhas-festas.png) |
| Montagem da festa | `pages/party_builder_page.dart` | ![Montagem](../../screenshots/party-maker.png) |
| Folha "Em qual festa…?" e diálogo "Nome da nova festa" | `widgets/select_party_bottom_sheet.dart` | ![Adicionar](../../screenshots/adicionar-a-festa.png) |
| Item da lista | `widgets/party_budget_item_tile.dart` | — |

## O botão central

A aba do Party Maker é o botão redondo no meio da barra inferior
(`PartyTabButton` em `app/widgets/app_bottom_nav_bar.dart`). Ele ocupa o lugar
do botão flutuante do `Scaffold`, e não um desenho por cima da barra: o que é
desenhado fora dos limites de um widget não recebe toques. Sobe 19 pontos
acima da barra (`AppSpacing.navButtonOverlap`), e por isso o rodapé da montagem
tem essa folga a mais embaixo. Rótulo para leitor de tela: "Minhas festas".

## Como cada status aparece

`presentation/party_status_presentation.dart`:

| Status | Texto | Cor |
|---|---|---|
| `draft`, `planning` | Rascunho, Em planejamento | `textSecondary` |
| `locked` | Orçamento solicitado | `primaryStrong` |
| `paid` | Pago | `success` |
| `cancelled` | Cancelado | `danger` |

## Estados da tela

| Estado | O que aparece |
|---|---|
| carregando | "Carregando suas festas" |
| falha na carga, sem nada em memória | erro com "Tentar novamente" |
| sem nenhuma festa | "Nenhuma festa aberta" + "Ver anúncios" |
| festa sem itens | "Sua festa está vazia" + "Ver anúncios" |
| operação em andamento | botão do rodapé desabilitado, com indicador |
| festa travada | selo "Orçamento solicitado"; remover desabilitado; botão vira "Editar festa" |

Um botão que não pode agir fica **desabilitado**, em vez de aceitar o toque e
responder com um erro.

## Avisos

| Quando | Texto |
|---|---|
| item entrou | "… adicionado a …." |
| item saiu | "… removido." |
| orçamento solicitado | "Orçamento solicitado! A festa fica travada enquanto isso." |
| festa liberada | "Festa liberada para edição." |
| operação falhou | a mensagem da regra ou da falha (`controller.error`) |

O aviso fica 4 segundos por cima do rodapé; os testes esperam ele sair antes de
tocar no botão que está embaixo.

## Acessibilidade específica

- O **+** e o ✓ do card têm rótulo com o nome do anúncio ("Adicionar Salão
  Glamour 8 a uma festa"): sem isso um leitor de tela ouviria só "botão".
- O ícone de remover também: "Remover …".
- A montagem e a folha de escolha passam nas verificações de área de toque e de
  rótulo, e não estouram com a fonte em 200% (`test/app/accessibility_test.dart`).

## Em aberto

- OPEN QUESTION: a quantidade aparece ("qtd 1") e não pode ser editada. Faz
  sentido para salão; e para itens como cadeiras ou garçons?
- `[PROPOSTA]` Mostrar o orçamento registrado (data e linhas) quando a festa
  está travada: o dado existe em `paymentSnapshot` e a tela mostra só o total.
