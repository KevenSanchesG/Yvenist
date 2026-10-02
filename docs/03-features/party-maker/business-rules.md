---
title: Party Maker — regras de negócio
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — regras de negócio

Cada regra, onde é garantida e o código do erro. "App" é
`lib/features/party_maker/domain/`; "API" é `backend/app/modules/parties/`.

## Ciclo e conteúdo

| # | Regra | App | API | Erro |
|---|---|---|---|---|
| R1 | Só as transições do [ciclo de vida](domain.md#transições) são aceitas | métodos de `Party` | `_ALLOWED_TRANSITIONS` | `invalid_party_transition` |
| R2 | Título, data, convidados e itens só mudam em `draft` ou `planning` | `_ensureMutable`, guardas de `addItem`/`removeItem` | `_content_changed` | `party_locked_mutation_not_allowed` (travada) ou `invalid_party_transition` |
| R3 | No máximo um salão por festa | `PartyBudget.addOrMergeItem` | `_reconcile_items` + índice único parcial `uq_party_items_one_venue_per_party` | `venue_already_selected` |
| R4 | Solicitar orçamento exige ao menos um item | `lockForPayment` | `reconcile` | `cannot_lock_without_items` |
| R5 | Travar gera o snapshot (total e linhas); destravar o apaga | `lockForPayment`, `unlock` | `PartyService._apply` | — |
| R6 | Festa paga não pode ser cancelada nem apagada | `cancel` | `delete_party` | `cannot_cancel_after_paid_mvp`, `paid_party_cannot_be_deleted` |
| R7 | O título não pode ficar vazio | `PartyTitle` | `PartyInput` (também: no máximo 80 caracteres) | `invalid_party_title` / erro de campo |
| R8 | Todos os itens na mesma moeda | `Money` | `_reconcile_items` | `currency_mismatch` |
| R9 | O total nunca é negativo | `PartyBudget.total` | preço não negativo (`CHECK`) | `budget_total_negative` |

## Itens

| # | Regra | App | API | Erro |
|---|---|---|---|---|
| R10 | Nome, categoria, preço e imagem de um item novo vêm do catálogo | o app envia só `id`, `listing_id` e `quantity` | `_reconcile_items` + `_lookup_listing` | — |
| R11 | Só anúncio publicado pode entrar | — | `_lookup_listing` | `listing_not_available` |
| R12 | Item que já está na festa mantém nome e preço de quando entrou; só a quantidade muda | `PartyItem` guarda as cópias | `_reconcile_items` | — |
| R13 | O mesmo anúncio não aparece duas vezes na festa | o app soma a quantidade no item que já existe | `UniqueConstraint(party_id, listing_id)` | `duplicate_party_item` |
| R14 | Quantidade de 1 a 999 | `Quantity` (mínimo 1) | `PartyItemInput` | `invalid_quantity` / erro de campo |
| R15 | No máximo 50 itens por festa | — | `MAX_ITEMS_PER_PARTY` | `too_many_party_items` |
| R16 | Remover o último item apaga a festa | `RemoveItemFromPartyUseCase` | — (a API aceita festa sem itens) | — |

## Dono e concorrência

| # | Regra | Onde | Erro |
|---|---|---|---|
| R17 | A festa de outra conta "não existe" | `PartyService._find` filtra pelo dono | `party_not_found` (404) |
| R18 | No máximo 100 festas por conta | `MAX_PARTIES_PER_USER` | `party_limit_reached` |
| R19 | Gravação com versão antiga é recusada | `version` + `SELECT … FOR UPDATE` + `version_id_col` | `party_version_conflict` (409) |
| R20 | Repetir uma gravação idêntica não muda nada nem conta como conflito | `if new_state == current` | — |
| R21 | Gravar com versão uma festa que foi apagada é "não encontrada", e não uma criação | `save_party` | `party_not_found` |
| R22 | Id de festa ou de item já usado por outro registro | chave primária | `party_id_conflict` |

## Onde app e API diferem (de propósito ou não)

| Assunto | App | API |
|---|---|---|
| Tamanho do título | sem limite | 80 caracteres |
| Quantidade máxima | sem limite | 999 |
| Convidados | pelo menos 1 | de 1 a 100 000 |
| Data do evento | qualquer | qualquer, com fuso (gravada em UTC) |
| Marcar como paga | `confirmPayment` existe | recusado: `paid` não é destino aceito |
| Festa sem itens | apagada pelo caso de uso | aceita |
| Preço de um item | pode ser alterado (`updateItemPrice`) | nunca muda depois que o item entra |

As quatro primeiras linhas significam que a API pode recusar algo que o app
aceitou: o erro volta com a mensagem do servidor e aparece no aviso da tela.

## Mensagens

As frases que o usuário lê estão em `domain/rules/party_domain_exceptions.dart`
(app) e nas classes de erro de `parties/domain.py` e `parties/service.py`
(API). São escritas para a tela: sem nome de status, sem termo interno.
