---
title: Party Maker — entidades
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker — entidades

Tudo em `lib/features/party_maker/domain/`. Na API as mesmas coisas estão em
`parties/models.py` (tabelas) e `parties/domain.py` (`PartyState`, `ItemState`).

## Entidades

| Classe | Campos | Observação |
|---|---|---|
| `Party` | `id`, `ownerId`, `title`, `eventType?`, `eventDate?`, `guestCount?`, `status`, `budget`, `quoteSnapshot?`, `quoteRound`, `history`, `createdAt`, `updatedAt` | raiz do agregado. Recebe um relógio (`Clock`), para os testes controlarem o "agora". `clone()` devolve uma cópia independente |
| `PartyBudget` | lista imutável de `PartyItem` | a composição: `add`, `replace`, `remove`, `removalOf` (o que sairia, sem tirar), `childrenOf`, `venue`, `estimateFor(guests)`, `quotedTotal`, `withQuotes`; `restore` reconstrói sem revalidar |
| `PartyItem` | `id`, `externalRef`, `category`, `nameSnapshot`, `pricing`, `quantity`, `configuration`, `relation`, `quote`, `imageUrlSnapshot?`, `capacity?`, `vendorId?` | `spec` (o que o item pede) e `estimate(guests)` |
| `PartyHistoryEntry` | `kind`, `actor`, `round`, `at`, `itemId?`, `itemName?`, `message?`, `amount?` | um acontecimento; o nome do item é uma cópia, para o registro continuar legível depois que o item sai |
| `QuoteRequestSnapshot` | `requestedAt`, `estimatedTotal`, `unpricedItems` | a estimativa que a pessoa viu ao pedir o orçamento |
| `QuoteRequest` | `itemId`, `partyId`, `partyStatus`, `round`, `updatedAt`, o evento (`eventType`, `eventDate`, `guestCount`), o item (`name`, `category`, `pricing`, `quantity`, `configuration`, `relation`, `parentName`, `estimate`), `quote` | o pedido como o **fornecedor** o vê. Não tem o nome da festa nem nada de quem pediu |

As três partes de um item não se misturam:

| Parte | Campos | Quem define |
|---|---|---|
| cópia do catálogo | `nameSnapshot`, `category`, `pricing`, `imageUrlSnapshot`, `capacity`, `vendorId` | o servidor, quando o item entra; não muda depois |
| o que a pessoa informou | `quantity`, `configuration` | a pessoa, conferido pelas regras da categoria |
| a resposta do fornecedor | `quote` | o fornecedor |

`vendorId` agrupa os itens do mesmo fornecedor e não identifica ninguém.

## Objetos de valor

| Classe | Regra que carrega | Erro |
|---|---|---|
| `PartyId`, `PartyItemId` | ids gerados no app (UUID v4) | — |
| `PartyTitle` | sem espaços nas pontas nem repetidos; de 1 a 80 caracteres | `invalid_party_title` |
| `EventDate` | só guarda o instante; comparada pelo instante. "No futuro" é regra da festa | — |
| `GuestCount` | de 1 a 100 000 | `invalid_guest_count` |
| `Quantity` | de 1 a 999 | `invalid_quantity` |
| `Money` | centavos inteiros + moeda (`BRL`); somar moedas diferentes é erro | `currency_mismatch` |
| `Pricing` | `model`, `amount?`, `minimum?`, `currency`; sem valor, ou com modelo desconhecido, vira "sob consulta". `estimate(guests, hours, quantity)` devolve `null` quando não há como estimar | — |
| `ItemConfiguration` | chave → inteiro ou texto, imutável; igual a outra com os mesmos valores | — |
| `ItemRelation` | `kind` + `parentId?`; sem o item a que se liga, só pode ser independente | — |
| `ItemQuote` | `status`, `amount?`, `message?`, `respondedAt?` | — |
| `ExternalRef` | de onde o item veio: `listing(id)`, `offer(id)` ou `unavailable(itemId)` | — |
| `EventDetails` | `title`, `eventType?`, `eventDate?`, `guestCount?`: os dados do evento como a pessoa os informa | — |
| `PartyItemDraft` | o que o catálogo diz de um anúncio agora: referência, categoria, nome, `pricing`, imagem, descrição, capacidade, `isRequired`, `ownServices`, `partners` | — |
| `ConfiguredItem` | um `PartyItemDraft` do jeito que a pessoa o configurou: `quantity`, `configuration`, `ownServices`, `recommendedBy?` | — |
| `VendorResponse` | o que um fornecedor responde: `quote(valor, recado?)`, `requestChanges(motivo)`, `decline(motivo)` | — |

## Enums

| Enum | Valores |
|---|---|
| `PartyStatus` | `draft`, `planning`, `locked`, `quoted`, `editRequested`, `confirmed`, `paid`, `cancelled`. Um valor desconhecido vindo da API é erro de leitura (`FormatException`): sem saber em que pé a festa está, o app não a mostra |
| `PartyItemCategory` | `venue`, `buffet`, `dj`, `decoration`, `security`, `staff`, `kids`, `attraction`, `beauty`, `other`: os mesmos slugs do catálogo; desconhecido vira `other` |
| `PricingModel` (`lib/core/pricing/`) | `fixed`, `perPerson`, `perHour`, `perUnit`, `onRequest`; desconhecido vira `onRequest` |
| `ItemRelationKind` | `independent`, `linked`, `required`, `recommended`; desconhecido vira `independent` |
| `QuoteStatus` | `none`, `pending`, `quoted`, `changesRequested`, `declined`; desconhecido vira `pending` |
| `PartyHistoryKind` | `quoteRequested`, `reopened`, `vendorQuoted`, `vendorRequestedChanges`, `vendorDeclined`, `confirmed`, `cancelled`; desconhecido fica fora da lista |

Em todos, o desconhecido cai no valor que **não libera nada** (falhar fechado).

## A relação entre itens

| `ItemRelationKind` | O que é | Ao remover o item a que se liga |
|---|---|---|
| `independent` | um anúncio escolhido por conta própria | — |
| `linked` | serviço do próprio anúncio (o buffet do salão) | sai junto |
| `required` | serviço do próprio anúncio que é obrigatório (uma taxa) | sai junto; **não sai sozinho** |
| `recommended` | outro anúncio, indicado por este | fica, e passa a `independent` |

Não há cadeias: um item ligado a outro não tem itens ligados a ele.

## O que cada categoria pede

`ItemConfigurationSpec` (`domain/rules/item_configuration_spec.dart`); a mesma
tabela na API é `_SPECS` (`parties/configuration.py`). Incluir uma categoria é
acrescentar uma entrada nas duas tabelas.

| Categoria | Campos (obrigatório em **negrito**) | Quantidade | Pede data e convidados |
|---|---|---|---|
| `venue` | **`duration_hours`** (1–24), `requirements` (300), `notes` | não | sim |
| `buffet` | **`service_style`** (`plated`, `self_service`, `cocktail`, `barbecue`), `menu` (200), `duration_hours`, `notes` | não | não |
| `kids` | **`duration_hours`**, `age_range` (`up_to_3`, `from_4_to_7`, `from_8_to_12`, `all_ages`), `notes` | sim | não |
| `attraction` | **`duration_hours`**, `notes` | não | não |
| `decoration` | **`theme`** (80), `environment` (`indoor`, `outdoor`, `both`), `items` (300), `customization` (300), `notes` | sim | não |
| `dj` | **`duration_hours`**, `notes` | não | não |
| `staff`, `security` | **`duration_hours`**, `notes` | sim | não |
| `beauty` | `notes` | sim | não |
| `other` | `variation` (80), `notes` | sim | não |

`notes` tem até 500 caracteres. O jeito de cobrar ajusta a tabela:

- **por hora**: `duration_hours` passa a ser obrigatório e vai para o topo,
  mesmo na categoria que não o tinha (sem ele não há estimativa);
- **por unidade**: a quantidade aparece, mesmo na categoria que não a tinha;
- **por pessoa**: o item não entra sem o número de convidados da festa;
- **serviço do próprio anúncio**: só `notes` (mais a duração ou a quantidade
  que o preço dele usar). Os detalhes da categoria são combinados com o mesmo
  fornecedor.

As duas tabelas são conferidas contra **a mesma tabela literal** nos testes
dos dois lados (`item_configuration_spec_test.dart` e
`test_party_configuration.py`).

## Na API e no banco

| App | API | Tabela |
|---|---|---|
| `Party` | `PartyState` / `PartyResponse` | `parties` (com `version`, que o app não tem como campo) |
| `PartyItem` | `ItemState` / `PartyItemResponse` | `party_items` |
| `ItemQuote` | `Quote` / `QuoteResponse` | colunas `quote_*` e `quoted_cents` de `party_items` |
| `QuoteRequestSnapshot` | `PartySnapshotResponse` | `party_snapshots` |
| `PartyHistoryEntry` | `HistoryEntry` / `HistoryEntryResponse` | `party_events` |
| `QuoteRequest` | `QuoteRequestResponse` (`quotes/schemas.py`) | — (uma leitura de `party_items` com a festa) |
| `ExternalRef.listing(id)` / `.offer(id)` | `listing_id` / `offer_id` | `party_items.listing_id`, `party_items.offer_id` |

A tradução entre os dois é `data/party_mapper.dart`. Um item cuja origem saiu
do catálogo chega sem `listing_id` e sem `offer_id`; o app cria
`ExternalRef.unavailable(<id do item>)` para o domínio continuar tendo uma
referência, e não a envia de volta.
