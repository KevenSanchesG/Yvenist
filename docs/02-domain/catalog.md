---
title: Catálogo e favoritos
type: domain
updated: 2026-10-02
---

# Catálogo e favoritos

App: `lib/features/catalog` (domínio e dados) e `lib/features/client` (telas).
API: `modules/catalog`, `modules/favorites`. Telas:
[browse-and-search](../03-features/browse-and-search.md).

## Entidades

| Entidade | Campos que importam |
|---|---|
| Anúncio (`Listing`) | título, categoria, bairro/cidade/UF, preço "a partir de" em centavos, imagem de capa (uma URL), nota e número de avaliações |
| Detalhe (só na API e na fila de análise) | descrição, capacidade, área, comodidades, tipos de evento, política de cancelamento |
| Categoria (`CatalogCategory`) | `slug`, nome, chave do ícone |
| Tipo de evento (`EventType`) | `slug`, nome |

Categorias e tipos de evento são dados de referência gravados pela migração
inicial (a lista também está em `catalog/reference_data.py`). O app tem o ícone de cada chave
(`catalog_presentation.dart`); chave desconhecida ganha um ícone genérico.

## Situação de um anúncio

```
em análise ──aprovado──▶ publicado
     └──────recusado───▶ recusado (com motivo)
```

Só anúncio **publicado** aparece na busca e pode entrar em uma festa. Os status
`draft` e `archived` existem no modelo e nenhum fluxo os usa hoje.

## Regras

| Regra | Garantida em |
|---|---|
| A busca só devolve anúncios publicados | `catalog/service.py` |
| Texto da busca ignora acentos e maiúsculas | coluna `search_text`, `catalog/text.py` |
| Filtros: categoria, tipo de evento, faixa de preço | `GET /catalog/listings` |
| Ordenação: mais procurados (padrão), menor preço, maior preço, mais recentes | `ListingSort` |
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
