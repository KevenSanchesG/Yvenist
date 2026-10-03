---
title: Modelo de dados
type: architecture
updated: 2026-10-03
---

# Modelo de dados

Catorze tabelas. Os modelos ficam no `models.py` de cada módulo; as migrações,
em `backend/migrations/versions/`:

| Migração | O que faz |
|---|---|
| `20261002_0001_initial_schema.py` | as onze tabelas da primeira versão e os dados de referência |
| `20261003_0002_listing_pricing_and_offers.py` | como o anúncio cobra (`pricing_model`, `minimum_price_cents`), `listing_offers` e `listing_partners`. Não apaga nada: os anúncios que já existiam viram "valor fixo" |
| `20261003_0003_party_composition_and_quotes.py` | a festa como composição de um evento: tipo de evento e rodada de orçamento em `parties`; configuração, forma de cobrança, ligação entre itens, fornecedor e resposta dele em `party_items`; `party_events`. Não apaga nada: um item antigo vira "por unidade" (o total da festa continua o mesmo), e uma festa com orçamento solicitado entra na primeira rodada, com os itens esperando resposta |

```
users ──┬── refresh_tokens
        ├── favorites ──────────────┐
        ├── parties ── party_items ─┼──▶ listings ── listing_event_types ──▶ event_types
        │    │   │        │  │  └───┼──▶ listing_offers ──▶ categories
        │    │   │        │  └──────┼──▶ vendor_profiles (a quem o pedido vai)
        │    │   │        └── party_items (o item a que este está ligado)
        │    │   ├──── party_snapshots
        │    │   └──── party_events
        │    └──▶ event_types
        └── vendor_profiles ── listings ──┬── listing_offers
                                          └── listing_partners ──▶ listings
```

## Tabelas

| Tabela | Guarda | Pontos que importam |
|---|---|---|
| `users` | conta | `email` único e em minúsculas; `password_hash`; `is_admin`; `token_version`; `terms_version` e `terms_accepted_at` (registro do aceite) |
| `refresh_tokens` | uma sessão por aparelho | só o hash do token; `family_id`; `user_agent`; `expires_at`; `revoked_at` |
| `categories` | categorias de anúncio | chave é o `slug`; `icon`, `sort_order`, `is_active` |
| `event_types` | tipos de evento | chave é o `slug` |
| `listings` | anúncio | `vendor_id`; `category_slug`; preço em centavos; `pricing_model` (a que o preço se refere) e `minimum_price_cents`; sob consulta guarda preço zero (`CHECK`); `status`; `rejection_reason`; `search_text`; `rating_average`/`rating_count` (ainda sem quem os alimente); `published_at` obrigatório quando publicado |
| `listing_event_types` | tipos de evento de um anúncio | N para N |
| `listing_offers` | serviço que o anunciante oferece junto com o anúncio | `listing_id`; `category_slug`; `name`; `pricing_model`, `price_cents`, `minimum_price_cents` (as mesmas regras do anúncio); `is_required`; `position` |
| `listing_partners` | anúncios que um anúncio recomenda | N para N entre anúncios (`listing_id`, `partner_listing_id`); um anúncio não é parceiro de si mesmo (`CHECK`) |
| `favorites` | favorito | chave composta (`user_id`, `listing_id`) |
| `parties` | festa (o evento) | `id` gerado pelo app; `owner_id`; `title`; `event_type`; `event_at`; `guest_count`; `status`; `quote_round` (quantas vezes o orçamento foi solicitado); `version`, que também avança quando um fornecedor responde |
| `party_items` | item da festa | **origem**: `listing_id` (um anúncio) ou `offer_id` (um serviço próprio), nunca os dois (`CHECK single_source`); os dois nulos, a origem saiu do catálogo. **Cópia do catálogo** na entrada: `category`, `name`, `pricing_model`, `unit_price_cents` (zero quando sob consulta), `minimum_cents`, `currency`, `image_url`, `capacity`, `vendor_id`. **Da pessoa**: `quantity`, `configuration` (JSON, os campos da categoria). **Ligação**: `relation` e `parent_item_id`. **Resposta do fornecedor**: `quote_status`, `quoted_cents`, `quote_message`, `quote_responded_at`. Único por (`party_id`, `listing_id`) e por (`party_id`, `offer_id`); **índice único parcial: um salão por festa** |
| `party_snapshots` | retrato da estimativa no momento em que o orçamento foi solicitado | `generated_at`, `expires_at` (nunca preenchido), `total_cents`, `breakdown` (JSON, uma linha por item, com `subtotal_cents` nulo para o que não tem como ser estimado). Existe enquanto a festa está com o orçamento solicitado; some ao voltar para a edição ou cancelar |
| `party_events` | histórico da festa | só se acrescenta. `sequence` (1, 2, 3... por festa, única); `kind` (pedido, reabertura, resposta do fornecedor, aceite, cancelamento); `actor` (cliente ou fornecedor); `quote_round`; `item_id` e `item_name` (sem chave estrangeira: o registro sobrevive ao item); `message`; `amount_cents` |
| `vendor_profiles` | cadastro de fornecedor | um por conta (`user_id` único); `document` único; `person_type`; `legal_name`; `status`; `rejection_reason`; `reviewed_at`/`reviewed_by` |

## O que acontece ao apagar

- Apagar a conta apaga em cascata sessões, favoritos, festas (com itens e
  orçamento) e o cadastro de fornecedor, que por sua vez apaga os anúncios.
- Apagar um anúncio apaga os serviços próprios dele e as indicações de
  parceiro em que ele aparece, dos dois lados.
- Apagar um anúncio **não** apaga o item das festas que o tinham:
  `party_items.listing_id` vira nulo e a cópia de nome, preço e imagem fica. O
  mesmo vale para um serviço próprio (`offer_id`) e para o fornecedor
  (`vendor_id`): o item fica, sem ter mais a quem pedir orçamento.
- Tirar de uma festa o item a que outro está ligado deixa `parent_item_id`
  nulo no banco (`SET NULL`). Quem decide o que sai junto são as regras
  ([business-rules](../03-features/party-maker/business-rules.md)): o banco só
  garante que a ligação nunca aponta para uma linha que não existe.
- Apagar a festa apaga os itens, o retrato e o histórico dela.
- Apagar o administrador que analisou um cadastro deixa `reviewed_by` nulo.

## Convenções

- Enums são texto + `CHECK`, não o tipo `ENUM` do PostgreSQL: acrescentar um
  valor é trocar a constraint (`str_enum` em `core/database.py`).
- Datas gravadas em UTC (`UTCDateTime`).
- Migrações escritas à mão e conferidas por teste: o banco criado por elas tem
  de ser idêntico ao que os modelos descrevem, em SQLite e em PostgreSQL
  (`tests/test_migrations.py`).
- Coluna obrigatória nova em tabela que já tem linhas entra em três passos:
  aceita nulo, recebe o valor, fica obrigatória. Trocar `CHECK` ou
  obrigatoriedade no SQLite pede o modo batch do Alembic
  (`op.batch_alter_table`), que recria a tabela; no PostgreSQL o mesmo bloco
  vira `ALTER TABLE`.
- Um índice parcial sai antes de um bloco batch e volta depois, escrito por
  extenso: recriado sem a condição, o de "um salão por festa" viraria "um item
  por festa" e a migração falharia em qualquer banco com festas.
- Uma migração que leva dados para um formato novo tem um teste que monta o
  banco na versão anterior, insere linhas, migra e confere
  (`test_existing_parties_are_carried_to_the_new_format`).
- Mudou um modelo → migração nova. Nunca editar uma migração já enviada.
