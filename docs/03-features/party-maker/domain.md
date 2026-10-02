---
title: Party Maker — domínio
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — domínio

## O agregado

`Party` (`domain/entities/party.dart`) é a raiz. Só ela altera os próprios
itens e o próprio status; quem está de fora chama os métodos dela e recebe uma
exceção de domínio se a regra não deixar.

```
Party
 ├── PartyTitle, EventDate?, GuestCount?
 ├── status: PartyStatus
 ├── budget: PartyBudget ── PartyItem*      (imutável: cada mudança gera outro)
 └── paymentSnapshot: PartyPaymentSnapshot? (só enquanto travada)
```

Campo a campo: [entities](entities.md).

## Ciclo de vida

```
              startPlanning          lockForPayment
  draft ─────────────────▶ planning ───────────────▶ locked ─ ─ confirmPayment ─ ─▶ paid
    │                         │  ▲                      │
    │                         │  └────── unlock ────────┘
    └──────── cancel ─────────┴────────── cancel ───────┴──────▶ cancelled
```

| Status | Na tela | Itens podem mudar? |
|---|---|---|
| `draft` | Rascunho | sim |
| `planning` | Em planejamento | sim |
| `locked` | Orçamento solicitado | não |
| `paid` | Pago | não |
| `cancelled` | Cancelado | não |

## Transições

| De | Para | Como | Condição |
|---|---|---|---|
| (não existe) | `draft` ou `planning` | criar | — |
| `draft` | `planning` | `startPlanning` | — |
| `planning` | `locked` | `lockForPayment` | ao menos um item; gera o snapshot |
| `locked` | `planning` | `unlock` | apaga o snapshot |
| `locked` | `paid` | `confirmPayment` | só no domínio do app; **a API não aceita** `paid` vindo do cliente |
| qualquer, menos `paid` e `cancelled` | `cancelled` | `cancel` | — |

Na API a mesma tabela é `_ALLOWED_TRANSITIONS` (`parties/domain.py`). Diferença
proposital: lá `paid` nunca é destino de uma gravação do cliente ("só o fluxo de
pagamento, no servidor, poderá marcar uma festa como paga").

## O que acontece na prática

O app nunca cria um `draft`: `PartyMakerController` cria toda festa já em
`planning` (`CreatePartyUseCase(startPlanning: true)`), em uma gravação só. O
status `draft` existe e é aceito, mas nenhum fluxo o usa.

## Duas implementações das mesmas regras

| | App | API |
|---|---|---|
| Onde | `Party` e `PartyBudget` | `reconcile` em `parties/domain.py` |
| Estilo | objeto que muda de estado, método por operação | função pura: estado atual + estado desejado → novo estado |
| Papel | resposta imediata, sem rede | a autoridade |
| Itens novos | o app informa nome e preço | **copiados do catálogo**, ignorando o que o app mandou |

Mudou uma regra em um lado, mude no outro. Os códigos de erro são os mesmos
nos dois (`venue_already_selected`, `cannot_lock_without_items`...). Todas as
regras: [business-rules](business-rules.md).

## Política: festa vazia não existe

Remover o último item apaga a festa (`RemoveItemFromPartyUseCase`). E uma festa
criada junto com o primeiro item é descartada se o item não puder entrar
(`addItemToNewParty`). É uma regra do caso de uso, não do agregado: a API
aceita gravar uma festa sem itens.
