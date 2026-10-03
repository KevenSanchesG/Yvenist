---
title: Catálogo e favoritos
type: domain
updated: 2026-10-03
---

# Catálogo e favoritos

App: `lib/features/catalog` (domínio e dados) e `lib/features/client` (telas).
API: `modules/catalog`, `modules/favorites`. Telas:
[browse-and-search](../03-features/browse-and-search.md).

## Entidades

| Entidade | Campos que importam |
|---|---|
| Anúncio (`Listing`) | título, categoria, bairro/cidade/UF, como cobra (modelo, preço em centavos, mínimo), imagem de capa (uma URL), nota e número de avaliações |
| Detalhe (`ListingDetail`; `GET /catalog/listings/{id}`) | o anúncio mais a capacidade, os serviços próprios e os parceiros. A API devolve também descrição, área, comodidades, tipos de evento e política de cancelamento, que o app só usa na fila de análise |
| Serviço próprio (`ListingOffer`) | categoria, nome, descrição, como cobra, se é obrigatório |
| Categoria (`CatalogCategory`) | `slug`, nome, chave do ícone |
| Tipo de evento (`EventType`) | `slug`, nome |

Categorias e tipos de evento são dados de referência gravados pela migração
inicial (a lista também está em `catalog/reference_data.py`). O app tem o ícone de cada chave
(`catalog_presentation.dart`); chave desconhecida ganha um ícone genérico.

## Como um anúncio cobra

`PricingModel`: `backend/app/modules/catalog/pricing.py` na API,
`lib/core/pricing/pricing_model.dart` no app (fica em `core/` porque o catálogo
e o Party Maker usam o mesmo vocabulário).

| Modelo | O preço é... | No card |
|---|---|---|
| `fixed` | um valor pelo serviço inteiro | "A partir de R$ 1.700" |
| `per_person` | por convidado | "R$ 55 por pessoa" |
| `per_hour` | por hora contratada | "R$ 270 por hora" |
| `per_unit` | por unidade | "R$ 8 por unidade" |
| `on_request` | não publicado | "Sob consulta" |

- `minimum_price_cents` (opcional) é o menor valor cobrado, qualquer que seja a
  conta do modelo.
- **Sob consulta não tem preço.** O banco guarda zero (a coluna ordena a
  vitrine, `CHECK on_request_has_no_price`), a API devolve `null`
  (`public_price`) e o app nunca mostra um número
  (`describePricing`, em `core/utils/money_formatter.dart`).
- Falha fechada: um modelo que o app não conhece, ou um preço que não veio,
  vira "sob consulta" (`PricingModel.fromApi`, `pricingFromJson`).
- A conta da estimativa (`estimate_cents`) é do
  [Party Maker](../03-features/party-maker/business-rules.md).

## Serviços próprios e parceiros

Duas relações que um anúncio declara, e que o Party Maker usa para montar a
festa:

| | Serviço próprio (`listing_offers`) | Parceiro (`listing_partners`) |
|---|---|---|
| O que é | algo que o próprio anunciante oferece junto: o buffet do salão, a animação da casa, uma taxa de limpeza | outro anúncio publicado, de qualquer fornecedor, que este recomenda |
| É um anúncio? | não: não aparece na busca nem passa por análise sozinho | sim |
| Contratado | só com o anúncio a que pertence; pode ser **obrigatório** (`is_required`) | à parte: é uma indicação |
| Limite | 20 por anúncio; não pode ser da categoria `venue` | 20 por anúncio; só anúncios publicados (`unknown_partner_listing`) |

O detalhe público só lista os parceiros que continuam publicados
(`ListingDetail.from_listing`). A indicação tem um sentido só: o parceiro não
passa a recomendar de volta.

## Situação de um anúncio

```
em análise ──aprovado──▶ publicado
     └──────recusado───▶ recusado (com motivo)
```

Só anúncio **publicado** aparece na busca e pode entrar em uma festa. Os status
`draft` e `archived` existem no modelo e nenhum fluxo os usa hoje.

Um anúncio sob consulta entra em uma festa como qualquer outro: fica fora da
estimativa, que diz quantos itens ficaram de fora, e o valor vem na resposta do
fornecedor ([Party Maker](../03-features/party-maker/business-rules.md)).

## Regras

| Regra | Garantida em |
|---|---|
| A busca só devolve anúncios publicados | `catalog/service.py` |
| Texto da busca ignora acentos e maiúsculas | coluna `search_text`, `catalog/text.py` |
| Filtros: categoria, tipo de evento, faixa de preço | `GET /catalog/listings` |
| Um filtro de preço deixa de fora o que é sob consulta | `_apply_filters` |
| Ordenação: mais procurados (padrão), menor preço, maior preço, mais recentes | `ListingSort` |
| Nas duas ordens de preço, o que é sob consulta vai para o fim | `_price_ascending`, `_price_descending` (API); `_comparePrices` (demonstração) |
| A ordem de preço compara o número anunciado, sem converter a unidade: R$ 55 por pessoa vem antes de R$ 600 fixos | — (limite conhecido) |
| Página por cursor; o cursor adulterado é recusado (`invalid_cursor`) | `core/pagination.py` |
| Favoritar é idempotente; no máximo 500 por conta | `favorites/service.py` |
| Favoritar exige conta; o app pede login na hora | `listing_actions.dart` |

## Notas e avaliações

`rating_average` e `rating_count` existem no anúncio e aparecem nos cards, mas
**nenhum fluxo os alimenta**: só os anúncios de demonstração têm valores. Não há
módulo de avaliações.

## Modo demonstração

`InMemoryCatalogRepository` serve o catálogo de `demo_catalog.dart`, com as
mesmas regras de busca, filtro, ordenação e cursor. `python -m app.cli
seed-demo` grava na API um conjunto equivalente (os mesmos nomes e preços), que
é o que os testes de integração esperam encontrar.

Os 32 anúncios de exemplo mostram cada jeito de cobrar:

| Categoria | Cobrança | Além disso |
|---|---|---|
| Salão Glamour 1–8 | valor fixo | capacidade de 100 a 240; três serviços próprios (buffet por pessoa, animação por hora, taxa de limpeza obrigatória); recomenda a decoração e a atração de mesmo número |
| Atração Festiva 1–8 | por hora | — |
| Buffet Sabor & Festa 1–8 | por pessoa, com mínimo de R$ 2.500 | — |
| Decoração Encanto 1–8 | valor fixo; a de número 8 é sob consulta | — |
