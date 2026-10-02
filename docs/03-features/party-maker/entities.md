---
title: Party Maker — entidades
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — entidades

Tudo em `lib/features/party_maker/domain/`. Na API as mesmas coisas estão em
`parties/models.py` (tabelas) e `parties/domain.py` (`PartyState`, `ItemState`).

## Entidades

| Classe | Campos | Observação |
|---|---|---|
| `Party` | `id`, `ownerId`, `title`, `eventDate?`, `guestCount?`, `status`, `budget`, `paymentSnapshot?`, `createdAt`, `updatedAt` | raiz do agregado; `ownerId` ainda é uma `String` simples |
| `PartyBudget` | lista imutável de `PartyItem` | `total`, `hasVenue()`, `addOrMergeItem`, `removeItem`, `updateQuantity`, `updateUnitPrice`; `restore` reconstrói sem revalidar |
| `PartyItem` | `id`, `externalRef`, `category`, `nameSnapshot`, `unitPriceSnapshot`, `quantity`, `imageUrlSnapshot?` | `subtotal` = preço × quantidade |
| `PartyPaymentSnapshot` | `partyId`, `generatedAt`, `expiresAt?`, `totalAmount`, `breakdown` | o orçamento no momento em que a festa foi travada |
| `SnapshotLineItem` | uma linha do `breakdown` | cópia do item, com o subtotal |

## Objetos de valor

| Classe | Regra que carrega | Erro |
|---|---|---|
| `PartyId`, `PartyItemId` | ids gerados no app (UUID v4) | — |
| `PartyTitle` | sem espaços nas pontas; não pode ficar vazio | `invalid_party_title` |
| `EventDate` | nenhuma: só guarda a data (passado é aceito) | — |
| `GuestCount` | pelo menos 1 | `invalid_guest_count` |
| `Quantity` | pelo menos 1 | `invalid_quantity` |
| `Money` | centavos inteiros + moeda (`BRL`); somar moedas diferentes é erro | `currency_mismatch` |
| `ExternalRef` | de onde o item veio: `source` + `id`. Para anúncios, `ExternalRef.listing(id)` | — |
| `PartyItemDraft` | o que o catálogo informa de um anúncio na hora de colocá-lo na festa | — |
| `CancellationResult` | total, reembolso e multa de um cancelamento (os dois últimos sempre zero) | — |

## Enums

| Enum | Valores |
|---|---|
| `PartyStatus` | `draft`, `planning`, `locked`, `paid`, `cancelled` |
| `PartyItemCategory` | `venue`, `buffet`, `dj`, `decoration`, `security`, `staff`, `kids`, `attraction`, `beauty`, `other` — os mesmos slugs das categorias do catálogo; slug desconhecido vira `other` |

## Como aparece para a tela

`PartyBudgetItemView` (`presentation/models/`) é o item achatado para o
widget: `id`, `name`, `unitPriceCents`, `quantity`, `imageUrl`, `category`.

## Na API e no banco

| App | API | Tabela |
|---|---|---|
| `Party` | `PartyState` / `PartyResponse` | `parties` (com `version`, que o app não tem como campo) |
| `PartyItem` | `ItemState` / `PartyItemResponse` | `party_items` |
| `PartyPaymentSnapshot` | `PartySnapshotResponse` | `party_snapshots` |
| `ExternalRef.listing(id)` | `listing_id` | `party_items.listing_id` (nulo se o anúncio foi apagado) |

A tradução entre os dois é `data/party_mapper.dart`. Um item cujo anúncio foi
apagado chega sem `listing_id`; o app cria a referência `removed:<id do item>`
para o domínio continuar tendo uma, e não a envia de volta.
