---
title: Party Maker — regras de negócio
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker — regras de negócio

Cada regra, onde é garantida e o código do erro. "App" é
`lib/features/party_maker/domain/`; "API" é `backend/app/modules/parties/`
(`domain.py`, salvo indicação). O código do erro é o mesmo nos dois lados.

## Ciclo

| # | Regra | App | API | Erro |
|---|---|---|---|---|
| R1 | Só as transições do [ciclo de vida](domain.md) são aceitas | métodos de `Party` | `_ALLOWED_TRANSITIONS` | `invalid_party_transition` |
| R2 | Nome, evento e itens só mudam em rascunho ou em planejamento | `Party._ensureEditable` | `_content_changed` | `party_locked_mutation_not_allowed` (orçamento solicitado) ou `invalid_party_transition` (paga, cancelada) |
| R3 | "Orçamento recebido" e "edição solicitada" só saem da resposta de um fornecedor; "paga", de ninguém | o app nunca envia esses status (`_requestedStatus`) | não são destino em `_ALLOWED_TRANSITIONS` | `invalid_party_transition` |
| R4 | Aceitar só depois que todos os itens têm o valor do fornecedor | `confirmQuote` | `quoted → confirmed` é a única entrada | `invalid_party_transition` |
| R5 | Festa paga não é cancelada nem apagada | `cancel`, `ensureCanBeDeleted` | `service.delete_party` | `invalid_party_transition`, `paid_party_cannot_be_deleted` |
| R6 | Festa com o orçamento solicitado só é apagada depois de cancelada | `ensureCanBeDeleted` | `service.delete_party` | `party_has_open_quote` |

## O evento

| # | Regra | App | API | Erro |
|---|---|---|---|---|
| R7 | O nome não fica vazio e tem até 80 caracteres | `PartyTitle` | `PartyInput` | `invalid_party_title` / erro de campo |
| R8 | A data **informada agora** precisa ser no futuro. Uma festa antiga, cuja data já passou, continua podendo ser aberta e renomeada | `updateEventDetails` | `_check_event` | `event_date_in_past` |
| R9 | O tipo de evento informado agora precisa existir no catálogo | a tela só oferece os do catálogo | `_check_event` | `unknown_event_type` |
| R10 | De 1 a 100 000 convidados | `GuestCount` | `PartyInput` | `invalid_guest_count` / erro de campo |
| R11 | Os convidados não passam da capacidade de um item (o salão) | `Party._checkCapacity` | `_reconcile_items` | `guest_count_exceeds_capacity` |
| R12 | Mudar o tipo, a data ou os convidados descarta os valores que os fornecedores informaram; mudar só o nome, não | `updateEventDetails` | `reconcile` (`discard_quotes`) | — |

## Itens

| # | Regra | App | API | Erro |
|---|---|---|---|---|
| R13 | Nome, categoria, preço, forma de cobrança, mínimo, capacidade, imagem e fornecedor de um item novo vêm do catálogo | o app envia só a origem, a quantidade, a configuração e a que item se liga | `_new_item` + `service._CatalogReader` | — |
| R14 | Só anúncio publicado (ou serviço de um anúncio publicado) pode entrar | — | `_catalog_entry` | `listing_not_available` |
| R15 | Item que já está na festa mantém o que foi copiado; só a quantidade e a configuração mudam | `PartyItem.copyWith` | `_updated_item` | — |
| R16 | O que não mudou em um item antigo não é validado de novo | `updateItem` sai cedo se nada mudou | `_updated_item` | — |
| R17 | O mesmo anúncio (ou serviço) não aparece duas vezes | `PartyBudget.add`; a tela abre o item que já está lá | `_reconcile_items` + `UniqueConstraint` | `duplicate_party_item` |
| R18 | No máximo um salão por festa | `PartyBudget.add` | `_reconcile_items` + índice único parcial | `venue_already_selected` |
| R19 | No máximo 50 itens por festa | `PartyBudget.maxItems` | `MAX_ITEMS_PER_PARTY` | `too_many_party_items` |
| R20 | Todos os itens na mesma moeda | `PartyBudget.add` | `_reconcile_items` | `currency_mismatch` |
| R21 | A configuração segue a tabela da categoria ([entidades](entities.md)): campo desconhecido, obrigatório vazio, tipo ou limite errado são recusados, todos de uma vez | `ItemConfigurationSpec.validate` | `configuration.validate_item` | `invalid_item_configuration` (com o erro de cada campo) |
| R22 | Quantidade de 1 a 999, e 1 onde a categoria não tem quantidade | `Quantity`, `checkQuantity` | `validate_item` | `invalid_quantity` |
| R23 | O salão só entra com a data e os convidados informados | `addItems` | `_check_event_requirements` | `event_details_required` |
| R24 | Um item cobrado por pessoa só entra com os convidados informados | `addItems` | `_check_event_requirements` | `guest_count_required` |
| R25 | Alterar a quantidade ou a configuração de um item descarta o valor que o fornecedor tinha dado para ele | `updateItem` | `_updated_item` | — |
| R26 | Uma festa pode ficar sem itens; tirar o último não a apaga | `RemoveItemFromPartyUseCase` | a API aceita festa sem itens | — |

## Itens que dependem de outros

| # | Regra | App | API | Erro |
|---|---|---|---|---|
| R27 | Um serviço do próprio anúncio só entra ligado ao item daquele anúncio | `assembleOwnService` | `_new_item`, `_check_relations` | `parent_item_missing`, `invalid_item_relation` |
| R28 | Se o serviço é obrigatório ou opcional, quem diz é o catálogo, e não o app | — | `_new_item` (`entry.required`) | — |
| R29 | Um anúncio com serviços obrigatórios só entra com eles | `assembleItems` | `_check_relations` | `required_item_missing` |
| R30 | Um serviço obrigatório não sai sozinho | `Party.removeItem`; na tela, o botão fica desabilitado | `_check_relations` | `required_item_missing` |
| R31 | Tirar um anúncio tira os serviços dele | `PartyBudget.remove` | o app os envia fora; senão `parent_item_missing` | — |
| R32 | Um item só é "recomendado por" outro se o catálogo confirma a indicação | a tela só oferece os parceiros do anúncio | `_check_relations` (`partner_listing_ids`) | `invalid_item_relation` |
| R33 | Tirar quem recomendou solta o recomendado, que fica na festa por conta própria | `PartyBudget.remove` | `_check_relations` | — |
| R34 | Sem cadeias: um item ligado a outro não tem itens ligados a ele | `PartyBudget.add` | `_check_relations` | `invalid_item_relation` |

## Estimativa e orçamento

| # | Regra | Onde |
|---|---|---|
| R35 | A estimativa de um item: fixo = valor; por unidade = valor × quantidade; por pessoa = valor × convidados × quantidade; por hora = valor × horas × quantidade; depois, o maior entre isso e o valor mínimo | `Pricing.estimate` (app), `estimate_cents` em `catalog/pricing.py` (API) |
| R36 | Sob consulta, ou sem a medida de que o preço depende (convidados, horas), **não há estimativa**. Nunca um número no lugar do que não se sabe | os mesmos; `null`/`None` |
| R37 | A estimativa da festa soma o que dá para estimar e diz quantos itens ficaram de fora | `PartyBudget.estimateFor` → `BudgetEstimate`; `estimate_cents` e `unpriced_items` na resposta da API |
| R38 | O orçamento recebido é a soma dos valores que os fornecedores informaram; não existe enquanto ninguém respondeu com um valor | `PartyBudget.quotedTotal`; `quoted_cents` |
| R39 | A estimativa e o orçamento são guardados e mostrados separados | `PartyItem.estimate` × `PartyItem.quote` |

A conta do app e a da API são conferidas com a mesma tabela de casos
(`value_objects_test.dart` e `backend/tests/test_pricing.py`).

## Pedir o orçamento

| # | Regra | App | API | Erro |
|---|---|---|---|---|
| R40 | Exige ao menos um item | `quoteBlockers` | `_request_quote` | `cannot_lock_without_items` |
| R41 | Exige a data, no futuro | `quoteBlockers` | `_request_quote` | `event_date_required`, `event_date_in_past` |
| R42 | Exige o número de convidados | `quoteBlockers` | `_request_quote` | `guest_count_required` |
| R43 | Exige que todo item ainda esteja disponível no catálogo | `quoteBlockers` (origem que saiu) | `_still_available` (também o anúncio despublicado) | `item_no_longer_available` |
| R44 | Quem já deu o valor, e nada mudou para ele, não é pedido de novo; os outros itens ficam aguardando | `requestQuote` | `_request_quote` | — |
| R45 | Cada pedido é uma rodada (`quote_round + 1`) e registra a estimativa do momento | `requestQuote` | `_request_quote`, `service._build_snapshot` | — |
| R46 | Voltar a editar retira o pedido de quem não respondeu e mantém o que já foi respondido | `reopenForEditing` | `_with_status` | — |

`quoteBlockers` devolve **todas** as pendências, cada uma com a frase da regra:
é o que a tela mostra em "Falta para pedir o orçamento", antes de a pessoa
tentar.

## A resposta do fornecedor

Garantidas por `Party.registerVendorResponse` (app, usado pelo modo
demonstração) e `apply_vendor_response` + `quotes/service.py` (API).

| # | Regra | Erro |
|---|---|---|
| R47 | O fornecedor só vê e só responde os itens dos próprios anúncios; o de outro "não existe" | `quote_request_not_found` (404) |
| R48 | Só enxerga festas com o orçamento solicitado, ou canceladas depois disso; a que voltou para a edição some | — |
| R49 | Só responde enquanto a pessoa não aceitou nem cancelou, e só a um item que foi pedido | `quote_request_closed` |
| R50 | O valor vai de 0 a R$ 10 milhões; o recado é opcional, com até 500 caracteres | `invalid_quote_response` |
| R51 | Pedir alteração ou recusar exige o motivo, com pelo menos 5 caracteres | `invalid_quote_response` |
| R52 | Pode corrigir a resposta enquanto o pedido está aberto | — |
| R53 | Cada resposta fica no histórico, com o nome do item, o recado e o valor | — |
| R54 | O fornecedor não recebe o nome da festa nem quem a pediu | `QuoteRequestResponse` não tem esses campos |

## Dono e concorrência

| # | Regra | Onde | Erro |
|---|---|---|---|
| R55 | A festa de outra conta "não existe" | `PartyService._find` filtra pelo dono | `party_not_found` (404) |
| R56 | No máximo 100 festas por conta | `MAX_PARTIES_PER_USER` | `party_limit_reached` |
| R57 | Gravação com versão antiga é recusada, mesmo quando a recusa viria de uma regra: a cópia do app ficou para trás | `version` + `SELECT … FOR UPDATE` | `party_version_conflict` (409) |
| R58 | A resposta de um fornecedor trava a linha da festa e avança a versão: resposta e gravação da pessoa acontecem uma depois da outra | `QuoteInboxService.respond` (`with_for_update`) | — |
| R59 | Repetir uma gravação idêntica não muda nada nem conta como conflito | `save_party` | — |
| R60 | Id de festa ou de item já usado por outro registro | chave primária | `party_id_conflict` |
| R61 | Gravar, com versão, uma festa que foi apagada é "não encontrada", e não uma criação | `save_party` | `party_not_found` |

## Onde app e API diferem

| Assunto | App | API |
|---|---|---|
| Anúncio que continua no banco, mas saiu do ar | não sabe: deixa pedir | recusa (`item_no_longer_available`) |
| Tipo de evento que saiu do catálogo | não confere | recusa se foi informado agora (`unknown_event_type`) |
| Serviço próprio de outro anúncio, parceiro que não é parceiro | não confere: a tela só oferece o que o catálogo listou | recusa (`invalid_item_relation`) |

Nos três casos a API recusa algo que o app deixou passar: o erro volta com a
mensagem do servidor e aparece na tela.

## Mensagens

As frases que o usuário lê estão em `domain/rules/party_domain_exceptions.dart`
(app) e nas classes de erro de `parties/domain.py`, `configuration.py` e
`service.py` (API). São escritas para a tela: sem nome de status, sem termo
interno.
