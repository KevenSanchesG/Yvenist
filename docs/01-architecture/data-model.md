---
title: Modelo de dados
type: architecture
updated: 2026-10-03
---

# Modelo de dados

Treze tabelas. Os modelos ficam no `models.py` de cada módulo; as migrações, em
`backend/migrations/versions/`:

| Migração | O que faz |
|---|---|
| `20261002_0001_initial_schema.py` | as onze tabelas da primeira versão e os dados de referência |
| `20261003_0002_listing_pricing_and_offers.py` | como o anúncio cobra (`pricing_model`, `minimum_price_cents`), `listing_offers` e `listing_partners`. Não apaga nada: os anúncios que já existiam viram "valor fixo" |

```
users ──┬── refresh_tokens
        ├── favorites ──────────────┐
        ├── parties ── party_items ─┼──▶ listings ── listing_event_types ──▶ event_types
        │        └──── party_snapshots       │  ├── listing_offers ──▶ categories
        └── vendor_profiles ─────────────────┘  └── listing_partners ──▶ listings
                                                listings ──▶ categories
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
| `parties` | festa | `id` gerado pelo app; `owner_id`; `title`; `event_at`; `guest_count`; `status`; `version` |
| `party_items` | item da festa | cópia de `category`, `name`, `unit_price_cents`, `currency`, `image_url`; `quantity`; `position`; único por (`party_id`, `listing_id`); **índice único parcial: um salão por festa** |
| `party_snapshots` | orçamento travado | `generated_at`, `expires_at`, `total_cents`, `breakdown` (JSON) |
| `vendor_profiles` | cadastro de fornecedor | um por conta (`user_id` único); `document` único; `person_type`; `legal_name`; `status`; `rejection_reason`; `reviewed_at`/`reviewed_by` |

## O que acontece ao apagar

- Apagar a conta apaga em cascata sessões, favoritos, festas (com itens e
  orçamento) e o cadastro de fornecedor, que por sua vez apaga os anúncios.
- Apagar um anúncio apaga os serviços próprios dele e as indicações de
  parceiro em que ele aparece, dos dois lados.
- Apagar um anúncio **não** apaga o item das festas que o tinham:
  `party_items.listing_id` vira nulo e a cópia de nome, preço e imagem fica. No
  app esse item aparece com a referência `removed:<id>` (`party_mapper.dart`).
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
- Mudou um modelo → migração nova. Nunca editar uma migração já enviada.
