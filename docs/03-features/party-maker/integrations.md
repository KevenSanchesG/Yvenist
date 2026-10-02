---
title: Party Maker — integrações
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — integrações

Com o que o Party Maker conversa, e por onde.

## Catálogo

O Party Maker **não importa nada do catálogo**. A tradução fica do lado de quem
chama (`lib/features/client/shared/listing_actions.dart`):

```dart
listing.toPartyItemDraft()   // Listing → PartyItemDraft
```

| Do anúncio | Para o item |
|---|---|
| `id` | `ExternalRef.listing(id)` |
| `categorySlug` | `PartyItemCategory.fromSlug` (desconhecida vira `other`) |
| `title` | `name` |
| `priceFromCents`, `currency` | `unitPrice` |
| `coverImageUrl` | `imageUrl` |

No caminho inverso, os cards perguntam ao controller se o anúncio já está em
alguma festa (`isInAnyParty(listing.id)`) para trocar o **+** pelo ✓. Festas
canceladas não contam.

## Sessão

`AppState` chama `parties.setOwner(userId)` a cada mudança de sessão (login,
logout, sessão expirada). Sem conta, a lista fica vazia e as operações falham
com "Entre na sua conta para criar festas.". A aba só é mostrada para quem
entrou (`_RequiresAccount` em `app_shell.dart`).

## Perfil

A aba Perfil lê as festas para os contadores: "Festas em planejamento"
(`draft` + `planning`) e "Orçamentos solicitados" (`locked`). Tocar leva à aba
do Party Maker com `clearActiveParty()` (abre o hub).

## API

| Chamada | Uso |
|---|---|
| `GET /parties` | lista do dono, da mais recente para a mais antiga (até 100) |
| `GET /parties/{id}` | uma festa |
| `PUT /parties/{id}` | cria ou atualiza com o **estado desejado** |
| `DELETE /parties/{id}` | apaga (não uma festa paga) |

O que o app envia no `PUT` (`partyToJson`):

```json
{
  "title": "15 anos da Maria",
  "event_at": null,
  "guest_count": null,
  "status": "planning",
  "items": [{"id": "<uuid do item>", "listing_id": "<uuid do anúncio>", "quantity": 1}],
  "version": 3
}
```

- **Sem nome nem preço**: o servidor copia do catálogo.
- `version` é a do último estado confirmado; vai omitida na criação.
- Resposta: a festa completa (itens com nome, preço e imagem; `total_cents`;
  `snapshot` quando travada; `version` nova). `201` se criou, `200` se atualizou.
- `409 party_version_conflict`: outro aparelho gravou antes. O app esquece a
  cópia, mostra a mensagem e recarrega.
- Repetir um `PUT` idêntico é seguro: se nada mudou, nada é gravado.

Erros de regra chegam com o mesmo `code` do domínio do app
([business-rules](business-rules.md)).

## Banco

Tabelas `parties`, `party_items`, `party_snapshots`
([data-model](../../01-architecture/data-model.md)). Apagar um anúncio não apaga
o item: `listing_id` vira nulo e a cópia de nome e preço fica.

## Navegação

`AppTabController.goTo(AppTab.partyMaker)` abre a aba. `activePartyId` do
controller decide entre hub e montagem; o botão "voltar" das duas telas leva ao
Início.

## Com o que ainda não conversa

Fornecedores (o orçamento não chega a ninguém), pagamentos, notificações e
chat. Nenhum deles existe.
