---
title: Party Maker — arquitetura
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker — arquitetura

É a única funcionalidade do app com a camada de domínio completa (entidades,
objetos de valor, regras, casos de uso), porque é a única com regras de verdade
([princípio 10](../../01-architecture/principles.md)).

## Arquivos

```
lib/features/party_maker/
  domain/
    entities/        party · party_budget · party_item · party_history_entry
                     quote_request_snapshot · quote_request
    value_objects/   money · pricing · quantity · party_title · guest_count · event_date
                     event_details · external_ref · item_configuration · item_relation
                     item_quote · vendor_response · party_item_draft · configured_item
                     party_id · party_item_id
    enums/           party_status · party_item_category
    rules/           item_configuration_spec    ← o que cada categoria pede
                     item_assembly              ← do formulário para os itens
                     party_domain_exceptions    ← as regras violadas, com a frase da tela
    repositories/    party_repository           ← as festas
                     quote_inbox_repository     ← os pedidos do fornecedor
                     party_item_catalog         ← o que o Party Maker precisa saber de um anúncio
    use_cases/       create_party · add_item_to_party · update_party_item
                     remove_item_from_party · update_event_details · request_quote
                     reopen_party · confirm_quote · cancel_party · delete_party
  data/
    party_mapper.dart                              JSON ⇄ Party e QuoteRequest
    repositories/api_party_repository.dart         · in_memory_party_repository.dart
    repositories/api_quote_inbox_repository.dart   · in_memory_quote_inbox_repository.dart
  presentation/
    add_to_party_flow.dart        ← a porta de entrada para o resto do app
    party_presentation.dart       ← textos, ícones e cores de cada conceito
    controllers/                  party_maker_controller · quote_inbox_controller
    pages/                        party_maker_entry · my_parties · party_builder
                                  item_configuration · event_details · party_history
                                  quote_inbox
    widgets/                      select_party_bottom_sheet · party_item_tile
                                  partner_suggestions · event_details_fields · event_type_name
    models/party_target.dart      ← festa escolhida: uma que existe, ou uma nova
```

`PricingModel` fica em `lib/core/pricing/`, e não aqui: é o mesmo vocabulário
no catálogo (como um anúncio cobra) e na festa (como um item é estimado).

## Onde cada responsabilidade mora

| Responsabilidade | Onde | Não mora em |
|---|---|---|
| o que pode e o que não pode | `Party`, `PartyBudget` | telas, controller |
| o que cada categoria pede | `ItemConfigurationSpec` | a tela de configuração, que só percorre os campos |
| a conta da estimativa | `Pricing.estimate`, `PartyBudget.estimateFor` | telas |
| transformar o formulário em itens | `assembleItems` | controller |
| a sequência "ler, aplicar a regra, gravar" | os casos de uso | controller |
| ocupado, mensagem de erro, festa aberta | `PartyMakerController` | telas |
| textos, ícones, cores | `party_presentation.dart` | domínio |
| traduzir um anúncio para o Party Maker | `ListingPartyItemCatalog` (em `client/shared`) | o Party Maker, que não importa o catálogo |

## Os três contratos

| Contrato | O que oferece | Implementações |
|---|---|---|
| `PartyRepository` | `listByOwner`, `getById`, `save` (devolve a festa **como ficou gravada**), `deleteById` | `ApiPartyRepository`, `InMemoryPartyRepository` |
| `QuoteInboxRepository` | `list`, `respond(itemId, VendorResponse)` | `ApiQuoteInboxRepository`, `InMemoryQuoteInboxRepository` |
| `PartyItemCatalog` | `draftFor(listingId)` (o anúncio com os serviços próprios e os parceiros), `eventTypes()` | `ListingPartyItemCatalog`, sobre o `CatalogRepository` |

Quem escolhe as implementações é `lib/app/app_dependencies.dart`; o
`PartyItemCatalog` é montado em `lib/app/yvenist_app.dart`. No modo
demonstração a caixa de pedidos trabalha sobre o **mesmo**
`InMemoryPartyRepository` das festas, e implementa a marca `DemoVendorAnswers`:
é por ela que a tela sabe que pode oferecer "Responder como fornecedor (demo)".

O armazenamento é a autoridade: o que volta de `save` pode diferir do que foi
enviado.

## Os controllers

`PartyMakerController` vive o app inteiro (criado em `AppState`).

| Responsabilidade | Como |
|---|---|
| festas da conta | `setOwner(id)` descarta o que estava carregado e chama `load()` quando a sessão muda |
| festa aberta | `activePartyId`: `null` = a lista; preenchido = aquela festa |
| operações | `createParty`, `addItem`, `addItemToNewParty`, `updateItem`, `removeItem`, `updateEventDetails`, `requestQuote`, `reopen`, `confirmQuote`, `cancelParty`, `deleteParty` |
| para a tela | `parties`, `partyById`, `editableParties`, `isInAnyParty`, `isBusy`, `error`, `hasLoaded`, `loadError` |

Toda operação passa por `_guard`, que:

1. espera uma carga em andamento, para o resultado dela não sobrescrever o que
   a operação gravar;
2. traduz qualquer falha em `error` (a mensagem da regra ou da falha);
3. em conflito ou "não encontrado" vindos do servidor, recarrega as festas: a
   cópia local estava desatualizada (outro aparelho gravou, ou um fornecedor
   respondeu).

`load()` é também como a tela fica sabendo da resposta de um fornecedor.

`QuoteInboxController` é da tela de pedidos (criado por ela): `load`,
`respond`, e o estado em `LoadState`. Depois de cada resposta a lista é buscada
de novo, porque uma resposta pode mudar a situação dos outros pedidos do mesmo
evento.

Os ids de festa e de item são gerados no app por `IdGenerator` (UUID v4).

## O caminho de um anúncio até a festa

```
card do anúncio ──▶ addListingToParty (client/shared/listing_actions.dart)   pede login
                      └─▶ startAddToPartyFlow (add_to_party_flow.dart)
                            ├─▶ showSelectPartySheet        escolhe: festa existente ou nova
                            └─▶ ItemConfigurationPage       PartyItemCatalog.draftFor
                                  └─▶ PartyMakerController.addItem / addItemToNewParty
                                        └─▶ AddItemToPartyUseCase
                                              ├─ assembleItems          valida a configuração
                                              ├─ Party.addItems         regras da festa
                                              └─ PartyRepository.save
```

A vitrine só informa o id e o nome do anúncio. Tudo o que é da festa acontece
dentro do Party Maker.

## Uma gravação, passo a passo (modo API)

1. O caso de uso lê a festa com `getById`. `ApiPartyRepository` devolve uma
   **instância nova** montada a partir do último JSON confirmado pelo servidor
   (`_confirmed`).
2. Aplica a regra no agregado (por exemplo `party.addItems(…)`).
3. `save` envia `PUT /parties/{id}` com o estado desejado e a `version` do JSON
   confirmado.
4. A resposta substitui o JSON confirmado e vira a festa devolvida.
5. Se a gravação falha, a instância alterada é descartada: a próxima leitura
   volta ao que o servidor tem. Em 409 ou 404 o JSON confirmado é esquecido.

Guardar o JSON, e não o objeto, é o que garante o passo 5: `Party` é mutável, e
uma instância compartilhada ficaria com uma alteração que o servidor recusou.
O repositório em memória faz o equivalente guardando e devolvendo cópias
(`Party.clone`).

Motivo do desenho: [ADR-005](../../05-decisions/ADR-005-festa-gravada-por-estado.md).

## Na API

`parties/router.py` → `PartyService.save_party` → `reconcile` (regras, sem
banco) → `_apply` (grava). Detalhes que importam:

- `_CatalogReader` busca cada anúncio e cada serviço uma vez por gravação; ao
  solicitar o orçamento, todos de uma vez (`preload`);
- a linha da festa é sempre tocada (`updated_at`), para a versão avançar mesmo
  quando só os itens mudaram;
- os itens que saíram são apagados **antes** de os novos entrarem (`flush`),
  para trocar um salão por outro na mesma gravação sem esbarrar no índice de
  salão único; os novos entram em duas fases, para a ligação entre eles
  apontar para uma linha que já existe;
- o retrato do pedido é criado ao solicitar e apagado ao voltar a editar;
- cada mudança de status deixa um registro em `party_events`
  (`describe_transition`).

`quotes/router.py` → `QuoteInboxService`: lista os itens do fornecedor
autenticado e aplica cada resposta com `apply_vendor_response`, travando a
linha da festa.

## Testes

| Arquivo | Cobre |
|---|---|
| `test/features/party_maker/domain/party_test.dart` | o agregado: evento, itens, pendências, pedido, respostas, rodadas, aceite, cancelamento |
| `…/domain/party_budget_test.dart` | a composição, a estimativa, o orçamento recebido, os itens ligados |
| `…/domain/item_configuration_spec_test.dart` | a tabela de cada categoria (a mesma tabela literal do teste da API) e a validação |
| `…/domain/value_objects_test.dart` | os objetos de valor e a conta de `Pricing` |
| `…/domain/use_cases_test.dart` | a montagem dos itens e cada caso de uso, com o repositório em memória |
| `…/data/api_party_repository_test.dart` | o mapeamento do JSON, o formato das chamadas, versão, conflito |
| `…/data/quote_inbox_repository_test.dart` | a caixa de pedidos, na API e em memória |
| `…/presentation/*_controller_test.dart` | os dois controllers |
| `test/app/party_flow_test.dart` | os fluxos de tela, do anúncio ao orçamento aceito |
| `test/app/accessibility_test.dart`, `system_bars_test.dart` | as telas com letras em 200%, no tema escuro e com as barras do sistema |
| `backend/tests/test_parties_domain.py`, `test_party_configuration.py`, `test_pricing.py` | as regras, sem banco |
| `backend/tests/test_parties.py`, `test_quotes.py` | rotas, dono, versão, limites, a caixa do fornecedor |
| `backend/tests/test_concurrency.py` | a mesma festa criada duas vezes ao mesmo tempo; edições simultâneas; resposta de fornecedor junto com gravação do cliente |
| `test/integration/` | o app real contra a API: dois aparelhos em conflito, um fornecedor respondendo, edição solicitada |
