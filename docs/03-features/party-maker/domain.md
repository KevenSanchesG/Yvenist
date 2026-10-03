---
title: Party Maker — domínio
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker — domínio

## O agregado

`Party` (`domain/entities/party.dart`) é a raiz. Só ela altera os próprios
itens e o próprio status; quem está de fora chama os métodos dela e recebe uma
exceção de domínio se a regra não deixar.

```
Party
 ├── o evento: PartyTitle, eventType?, EventDate?, GuestCount?
 ├── status: PartyStatus
 ├── budget: PartyBudget ── PartyItem*         (imutável: cada mudança gera outro)
 │                            ├── de onde veio: ExternalRef (anúncio ou serviço próprio)
 │                            ├── cópia do catálogo: nome, categoria, Pricing, capacidade
 │                            ├── o que a pessoa informou: Quantity, ItemConfiguration
 │                            ├── a que item se liga: ItemRelation
 │                            └── o que o fornecedor respondeu: ItemQuote
 ├── quoteRound                                (quantas vezes o orçamento foi pedido)
 ├── quoteSnapshot: QuoteRequestSnapshot?      (só com o orçamento solicitado)
 └── history: PartyHistoryEntry*               (só cresce)
```

Campo a campo: [entities](entities.md).

## Status

| Status | Na tela | Quem leva a festa até ele | O conteúdo pode mudar? |
|---|---|---|---|
| `draft` | Rascunho | só dados antigos (o app não cria mais) | sim |
| `planning` | Em planejamento | a pessoa (criar, voltar a editar) | sim |
| `locked` | Orçamento solicitado | a pessoa (solicitar) | não |
| `quoted` | Orçamento recebido | **a resposta de um fornecedor**: todos os itens têm valor | não |
| `edit_requested` | Edição solicitada | **a resposta de um fornecedor**: um item voltou | não |
| `confirmed` | Orçamento aceito | a pessoa (aceitar) | não |
| `paid` | Pago | ninguém: não há pagamento | não |
| `cancelled` | Cancelado | a pessoa (cancelar) | não |

`PartyStatus` (`domain/enums/party_status.dart`) agrupa: `isEditable` (`draft`,
`planning`), `isSubmitted` (`locked`, `quoted`, `edit_requested`, `confirmed`)
e `acceptsVendorAnswers` (`locked`, `quoted`, `edit_requested`). Na API são
`_EDITABLE`, `SUBMITTED` e `ANSWERABLE` (`parties/domain.py`).

## Ciclo de vida

```
                         solicitar                       todos responderam com valor
  planning ─────────────────────────────▶ locked ─────────────────────────────────▶ quoted ──aceitar──▶ confirmed
     ▲                                      │  ▲                                       │                    │
     │                                      │  └── o fornecedor corrige ───────────────┤                    │
     │              um item voltou (alteração pedida ou recusa)                        │                    │
     │                                      ▼                                          │                    │
     │                                edit_requested ◀─────────────────────────────────┘                    │
     │                                      │                                                               │
     └────────────── voltar a editar ───────┴───────────────────────────────────────────────────────────────┘

  qualquer status, menos paid e cancelled ── cancelar ──▶ cancelled
```

## O que a pessoa pode pedir

A tabela é `_ALLOWED_TRANSITIONS` (API) e os métodos de `Party` (app):

| De | Para | Como | Condição |
|---|---|---|---|
| (não existe) | `planning` | criar | — |
| `draft` | `planning` | `startPlanning` | — |
| `planning` | `locked` | `requestQuote` | sem pendências ([regras](business-rules.md)) |
| `locked`, `quoted`, `edit_requested`, `confirmed` | `planning` | `reopenForEditing` | — |
| `quoted` | `confirmed` | `confirmQuote` | — |
| qualquer, menos `paid` e `cancelled` | `cancelled` | `cancel` | — |

Três destinos **nunca** são aceitos vindos do app: `quoted` e `edit_requested`
(saem da resposta de um fornecedor) e `paid` (sairia de um fluxo de pagamento,
no servidor). O app, quando calcula um desses localmente, envia `locked`
(`_requestedStatus` em `data/party_mapper.dart`) e o servidor decide o resto.

## O que o fornecedor faz com a festa

Ele não vê a festa: vê **um pedido por item** dos próprios anúncios
(`QuoteRequest`). Cada resposta é para um item:

| Resposta | O item fica | A festa fica |
|---|---|---|
| informar o valor | `quoted`, com o valor e um recado opcional | `quoted` se todos os itens têm valor; senão `locked` |
| pedir uma alteração | `changes_requested`, com o motivo | `edit_requested` |
| recusar | `declined`, com o motivo | `edit_requested` |

O status da festa com o orçamento solicitado é sempre **derivado** das
respostas (`Party._statusFromQuotes`; `_status_from_quotes` na API): algum item
devolvido → `edit_requested`; todos com valor → `quoted`; senão `locked`.

Enquanto a pessoa não aceita, o fornecedor pode corrigir a resposta.

## Estados que não são status

A festa tem situações que a tela mostra e que não viraram um status, porque
podem ser calculadas:

| Situação | Como se sabe |
|---|---|
| pronta para pedir o orçamento | `party.quoteBlockers` vazio |
| reenviada | `quoteRound > 1` |
| com itens que pedem a atenção da pessoa | `party.itemsNeedingAttention` |
| com um item cujo anúncio saiu do catálogo | `externalRef.isAvailable` falso |

## Rodadas

Cada `requestQuote` soma 1 a `quoteRound`. Ao pedir de novo depois de editar:

- o item que **já tinha valor e não mudou** continua com ele: o fornecedor não
  responde de novo;
- o item que mudou, o item novo e o que tinha sido devolvido voltam a ser
  pedidos (`pending`).

Voltar a editar retira o pedido de quem ainda não tinha respondido (`pending`
vira `none`) e mantém à vista o que já foi respondido.

## Duas implementações das mesmas regras

| | App | API |
|---|---|---|
| Onde | `Party`, `PartyBudget`, `ItemConfigurationSpec`, `Pricing` | `reconcile` e `apply_vendor_response` em `parties/domain.py`; `configuration.py`; `catalog/pricing.py` |
| Estilo | objeto que muda de estado, um método por operação | funções puras: estado atual + estado desejado → novo estado |
| Papel | resposta imediata, sem rede; é a regra inteira no modo demonstração | a autoridade |
| Itens novos | o app informa de onde o item vem, a quantidade e a configuração | nome, categoria, preço, capacidade, fornecedor e **a própria relação** são copiados do catálogo |

Mudou uma regra em um lado, mude no outro, com o mesmo código de erro. Todas
as regras: [business-rules](business-rules.md).

## Política: uma festa pode ficar vazia

Um evento existe antes de ter itens: a pessoa cria a festa só com o nome e
monta depois. Tirar o último item **não** apaga a festa; apagar é uma ação
própria (`DeletePartyUseCase`), com confirmação. Uma exceção de bom senso: a
festa criada junto com o primeiro item (pelo "+" de um anúncio) só é gravada
se o item entrar (`AddItemToPartyUseCase.intoNewParty`), para não sobrar uma
festa que a pessoa não chegou a montar.
