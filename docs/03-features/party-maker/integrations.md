---
title: Party Maker — integrações
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker — integrações

Com o que o Party Maker conversa, e por onde.

## Catálogo

O Party Maker **não importa nada do catálogo**. Ele declara o que precisa saber
de um anúncio em um contrato próprio, `PartyItemCatalog`
(`domain/repositories/party_item_catalog.dart`), e quem conhece os dois lados
traduz: `ListingPartyItemCatalog`, em
`lib/features/client/shared/listing_party_item_catalog.dart`.

| Do catálogo (`ListingDetail`) | Para o Party Maker (`PartyItemDraft`) |
|---|---|
| `listing.id` | `ExternalRef.listing(id)` |
| `listing.categorySlug` | `PartyItemCategory.fromSlug` (desconhecida vira `other`) |
| `listing.title` | `name` |
| `pricingModel`, `priceFromCents`, `minimumPriceCents`, `currency` | `Pricing` (sem valor vira "sob consulta") |
| `listing.coverImageUrl` | `imageUrl` |
| `capacity` | `capacity` |
| `offers` (os serviços do próprio anunciante) | `ownServices`, cada um com `ExternalRef.offer(id)` e `isRequired` |
| `partners` (os anúncios que ele recomenda) | `partners` |
| `eventTypes()` | `EventTypeOption` (o `slug` que a festa guarda e o nome que a pessoa lê) |

O que é copiado para a festa de verdade (nome, preço, capacidade) é decidido
pelo servidor quando o item entra; o `PartyItemDraft` serve para montar o
formulário e a estimativa antes disso.

No caminho inverso, os cards perguntam ao controller se o anúncio já está em
alguma festa (`isInAnyParty(listing.id)`) para trocar o **+** pelo ✓. Festas
canceladas não contam.

A tela da festa consulta o catálogo de novo para listar os parceiros de cada
anúncio (`PartnerSuggestions`): uma chamada por anúncio, uma vez por visita à
festa. Se o catálogo não responder, as sugestões simplesmente não aparecem.

## Vitrine, busca e favoritos

Só **começam** o fluxo: `addListingToParty` (`client/shared/listing_actions.dart`)
pede o login e chama `startAddToPartyFlow` com o id e o nome do anúncio. A
escolha da festa, a configuração, a validação e a gravação são do Party Maker
(`presentation/add_to_party_flow.dart`).

## Sessão

`AppState` chama `parties.setOwner(userId)` a cada mudança de sessão (login,
logout, sessão expirada). Sem conta, a lista fica vazia e as operações falham
com "Entre na sua conta para criar festas.". A aba só é mostrada para quem
entrou (`_RequiresAccount` em `app_shell.dart`).

## Perfil

A aba Perfil lê as festas para os contadores: "Festas em planejamento"
(`status.isEditable`) e "Orçamentos solicitados" (`status.isSubmitted`: do
pedido até o aceite). Tocar leva à aba do Party Maker com `clearActiveParty()`
(abre a lista). No **Modo Fornecedor**, o item "Pedidos de orçamento" abre
`QuoteInboxPage`.

## Cadastro do salão

O fluxo "anunciar um salão" (`vendor/onboarding/.../hall_creation_flow_page.dart`)
é onde o fornecedor define o que a festa vai usar: como cobra (valor fixo, por
convidado, por hora, sob consulta), o valor mínimo e os **serviços do próprio
espaço**, com a marca de obrigatório. Detalhes:
[vendor-onboarding](../vendor-onboarding.md).

## API

| Chamada | Uso |
|---|---|
| `GET /parties` | as festas do dono, da mais recente para a mais antiga (até 100) |
| `GET /parties/{id}` | uma festa |
| `PUT /parties/{id}` | cria ou atualiza com o **estado desejado** |
| `DELETE /parties/{id}` | apaga (não uma festa paga, nem uma com o orçamento solicitado) |
| `GET /vendors/me/quote-requests` | os pedidos dos anúncios do fornecedor autenticado (até 100) |
| `POST /vendors/me/quote-requests/{item_id}/quote` | informa o valor: `amount_cents`, `message?` |
| `POST /vendors/me/quote-requests/{item_id}/request-changes` | pede uma alteração: `message` |
| `POST /vendors/me/quote-requests/{item_id}/decline` | recusa: `message` |

O que o app envia no `PUT` (`partyToJson`):

```json
{
  "title": "15 anos da Maria",
  "event_type": "debutante",
  "event_at": "2027-01-01T22:00:00.000Z",
  "guest_count": 80,
  "status": "planning",
  "items": [
    {
      "id": "<uuid do item>",
      "listing_id": "<uuid do anúncio>",
      "offer_id": null,
      "parent_item_id": null,
      "quantity": 1,
      "configuration": {"duration_hours": 4}
    },
    {
      "id": "<uuid do item>",
      "listing_id": null,
      "offer_id": "<uuid do serviço>",
      "parent_item_id": "<uuid do item do anúncio>",
      "quantity": 1,
      "configuration": {}
    }
  ],
  "version": 3
}
```

- **Sem nome, preço, forma de cobrança nem relação**: o servidor copia do
  catálogo e decide se um serviço é obrigatório.
- `status` nunca vai como `quoted` nem `edit_requested`: o app envia `locked` e
  o servidor decide pelo que cada fornecedor já respondeu.
- `version` é a do último estado confirmado; vai omitida na criação.
- Resposta: a festa completa. Cada item traz o que foi copiado, a
  configuração, `estimate_cents` e `quote`; a festa traz `estimate_cents`,
  `unpriced_items`, `quoted_cents`, `quote_round`, `snapshot` (com o orçamento
  solicitado), `history` e a `version` nova. `201` se criou, `200` se
  atualizou.
- `409 party_version_conflict`: outro aparelho gravou antes, ou um fornecedor
  respondeu. O app esquece a cópia, mostra a mensagem e recarrega.
- Repetir um `PUT` idêntico é seguro: se nada mudou, nada é gravado.

A resposta de um fornecedor devolve o pedido como ficou
(`QuoteRequestResponse`): o evento, o item, a resposta e `party_status`.

Erros de regra chegam com o mesmo `code` do domínio do app
([business-rules](business-rules.md)).

## Banco

Tabelas `parties`, `party_items`, `party_snapshots` e `party_events`
([data-model](../../01-architecture/data-model.md)). Apagar um anúncio ou um
serviço não apaga o item: a ligação vira nula e a cópia fica.

## Navegação

`AppTabController.goTo(AppTab.partyMaker)` abre a aba. `activePartyId` do
controller decide entre a lista e a festa. O aviso "… adicionado a …" tem o
atalho "Ver festa", que fecha as telas empilhadas, abre a festa e troca de aba.

## Com o que ainda não conversa

Pagamentos, notificações, chat e agenda dos fornecedores. Nenhum deles existe.
