---
title: Party Maker — arquitetura
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — arquitetura

É a única funcionalidade do app com a camada de domínio completa (entidades,
objetos de valor, casos de uso), porque é a única com regras de verdade
([princípio 10](../../01-architecture/principles.md)).

## Arquivos

```
lib/features/party_maker/
  domain/
    entities/        party.dart · party_budget.dart · party_item.dart · party_payment_snapshot.dart
    value_objects/   money · quantity · party_title · guest_count · event_date · external_ref
                     party_id · party_item_id · party_item_draft · cancellation_result
    enums/           party_status · party_item_category
    rules/           party_domain_exceptions.dart
    repositories/    party_repository.dart              ← o contrato
    use_cases/       create · add_item · remove_item · lock · unlock        ← usados
                     start_planning · rename_title · cancel                 ← ainda sem tela
  data/
    party_mapper.dart                    JSON ⇄ Party
    repositories/api_party_repository.dart
    repositories/in_memory_party_repository.dart
  presentation/
    controllers/party_maker_controller.dart
    pages/           party_maker_entry_page · my_parties_page · party_builder_page
    widgets/         select_party_bottom_sheet · party_budget_item_tile
    models/party_budget_item_view.dart
    party_status_presentation.dart
```

## O contrato

`PartyRepository`: `listByOwner`, `getById`, `save` (devolve a festa **como
ficou gravada**), `deleteById`. O armazenamento é a autoridade: o que volta de
`save` pode diferir do que foi enviado.

## O controller

`PartyMakerController` vive o app inteiro (criado em `AppState`).

| Responsabilidade | Como |
|---|---|
| festas da conta | `setOwner(id)` descarta o que estava carregado e chama `load()` quando a sessão muda |
| festa aberta | `activePartyId`: `null` = hub; preenchido = montagem daquela festa |
| operações | `startNewParty`, `addItemToParty`, `addItemToNewParty`, `removeItemFromActiveParty`, `lockActivePartyForPayment`, `unlockActiveParty` |
| para a tela | `parties`, `editableParties`, `budgetItemViews`, `activePartyTotalCents`, `isInAnyParty`, `isBusy`, `error`, `hasLoaded`, `loadError` |

Toda operação passa por `_guard`, que:

1. espera uma carga em andamento, para o resultado dela não sobrescrever o que
   a operação gravar;
2. traduz qualquer falha em `error` (a mensagem da regra ou da falha);
3. em conflito ou "não encontrado" vindos do servidor, recarrega as festas: a
   cópia local estava desatualizada.

Os ids de festa e de item são gerados no app por `IdGenerator` (UUID v4).

## Uma gravação, passo a passo (modo API)

1. O caso de uso lê a festa com `getById`. `ApiPartyRepository` devolve uma
   **instância nova** montada a partir do último JSON confirmado pelo servidor
   (`_confirmed`).
2. Aplica a regra no agregado (por exemplo `party.addItem(…)`).
3. `save` envia `PUT /parties/{id}` com o estado desejado e a `version` do JSON
   confirmado.
4. A resposta substitui o JSON confirmado e vira a festa devolvida.
5. Se a gravação falha, a instância alterada é descartada: a próxima leitura
   volta ao que o servidor tem. Em 409 ou 404 o JSON confirmado é esquecido.

Guardar o JSON, e não o objeto, é o que garante o passo 5: `Party` é mutável, e
uma instância compartilhada ficaria com uma alteração que o servidor recusou.

Motivo do desenho: [ADR-005](../../05-decisions/ADR-005-festa-gravada-por-estado.md).

## Na API

`router.py` → `PartyService.save_party` → `reconcile` (regras, sem banco) →
`_apply` (grava). Detalhes da gravação que importam:

- a linha da festa é sempre tocada (`updated_at`), para a versão avançar mesmo
  quando só os itens mudaram;
- os itens que saíram são apagados **antes** de os novos entrarem
  (`flush`), para trocar um salão por outro na mesma gravação sem esbarrar no
  índice de salão único;
- o snapshot é criado ao travar e apagado ao destravar.

## Testes

| Arquivo | Cobre |
|---|---|
| `test/features/party_maker/domain/*` | agregado, orçamento, objetos de valor, casos de uso |
| `…/data/api_party_repository_test.dart` | formato das chamadas, versão, conflito, item órfão |
| `…/presentation/party_maker_controller_test.dart` | o controller, com o repositório em memória |
| `test/app/party_flow_test.dart` | os fluxos de tela |
| `backend/tests/test_parties_domain.py` | `reconcile`, sem banco |
| `backend/tests/test_parties.py` | rotas, dono, versão, limites |
| `backend/tests/test_concurrency.py` | a mesma festa criada duas vezes ao mesmo tempo; duas edições simultâneas da mesma versão |
| `test/integration/` | o app real contra a API, inclusive dois aparelhos em conflito |
