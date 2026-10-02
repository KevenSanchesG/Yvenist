---
title: Vitrine, explorar, busca e favoritos
type: feature
updated: 2026-10-02
---

# Vitrine, explorar, busca e favoritos

Regras do catálogo: [catalog](../02-domain/catalog.md). Funciona sem conta,
menos favoritar.

## Telas

| Tela | Arquivo | O que faz |
|---|---|---|
| Início | `client/home/presentation/pages/home_page.dart` | busca no topo, categorias em carrossel, faixas "Salões muito procurados" e "Atrações que estão em alta nas festas" (8 anúncios cada) |
| Explorar | `client/explore/presentation/pages/explore_page.dart` | filtros por categoria e tipo de evento, ordenação, lista com rolagem infinita |
| Busca | `client/search/presentation/pages/search_page.dart` | texto livre; ignora acentos e maiúsculas |
| Favoritos | `client/favorites/presentation/pages/favorites_page.dart` | os anúncios guardados pela conta |

![Início](../screenshots/home.png) ![Explorar](../screenshots/explorar.png)

## O card de anúncio

`client/shared/listing_card.dart`. Mostra capa, preço "a partir de", título,
nota e local, e duas ações (`listing_actions.dart`):

| Ação | Comportamento |
|---|---|
| **+** | abre a escolha da festa ([Party Maker](party-maker/user-flows.md)); vira ✓ quando o anúncio já está em alguma |
| ♥ | favorita ou desfavorita; visitante é levado ao login e a ação continua depois |

O card **não abre uma página de detalhe**: ela não existe.

## Comportamentos que valem conhecer

- Tocar em uma categoria no Início aplica o filtro e abre a aba Explorar. Por
  isso o `ExploreController` é criado acima das abas (`app_shell.dart`).
- A busca descarta a resposta de um termo que já foi trocado
  (`ListingSearchController`).
- Rolagem infinita por cursor: a próxima página é pedida ao chegar perto do fim.
- Favoritar é otimista: o coração muda na hora e volta atrás se o servidor
  recusar (`FavoritesController.toggle`), com um aviso.
- Atualizar puxando a tela mantém o conteúdo atual; se a atualização falhar,
  ele continua lá.
- Com a fonte do sistema grande, os cards da vitrine alargam até 40%
  (`horizontal_card_list.dart`) para o título não ser cortado.

## Imagens

`core/widgets/app_network_image.dart`: carrega a URL do anúncio, com um ícone
no lugar enquanto carrega ou se falhar. Em testes a rede é substituída.

## Testes

`test/app/browsing_flow_test.dart`, `test/features/client/*`,
`test/features/catalog/catalog_repositories_test.dart`.

## O que não existe

Página de detalhe, filtro por preço na tela (a API aceita `min_price_cents` e
`max_price_cents`), filtro por cidade, mapa, notificações (o sino do Início
abre uma tela "Nenhuma notificação").
