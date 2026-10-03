---
title: Party Maker — próximos passos
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker — próximos passos

Nada aqui tem data. Os números `PM-n` são os de [known-issues](known-issues.md).

## Decisões que são dos donos

| OPEN QUESTION | O que depende dela |
|---|---|
| As escolhas de negócio do [ADR-019](../../05-decisions/ADR-019-festa-como-composicao-de-evento.md) valem? | PM-20 a PM-26: cada uma diz o que muda se a resposta for outra |
| Um orçamento respondido vale por quanto tempo? | PM-4 |
| Aceitar o orçamento deve reservar a data, virar contrato, cobrar? | PM-3, PM-5 |
| O fornecedor deve aparecer para o cliente com um nome? Qual (não há nome público no cadastro)? | PM-24 |
| O cliente e o fornecedor devem poder conversar antes do valor? | PM-2 |
| Como a pessoa fica sabendo de uma resposta: notificação, e-mail? | PM-1 |
| O que cada categoria deve perguntar | PM-25: a tabela atual é uma primeira versão |

## `[PROPOSTA]` O que dá para fazer sem esperar decisão

1. **Tela para o fornecedor indicar parceiros** (PM-7): a API já aceita
   `partner_listing_ids`.
2. **Página de detalhe do anúncio** (PM-6): a rota `GET /catalog/listings/{id}`
   existe e a ponte `PartyItemCatalog` já a usa; é uma tela do catálogo.
3. **Uma chamada só para os parceiros de uma festa** (PM-14), quando as festas
   crescerem.
4. **Paginação** das festas e dos pedidos (PM-15).

## Quando mexer nas regras

Qualquer regra nova entra nos dois lados (PM-10), nesta ordem:

1. teste em `backend/tests/test_parties_domain.py` e a regra em `reconcile`;
2. teste em `test/features/party_maker/domain/` e a regra em `Party`;
3. o mesmo `code` de erro nos dois;
4. um cenário em `test/integration/` se a regra depender do catálogo, de
   concorrência ou da resposta de um fornecedor;
5. a linha em [business-rules](business-rules.md).

Um campo novo em uma categoria: a entrada em `_SPECS`
(`parties/configuration.py`) e em `_categorySpecs`
(`item_configuration_spec.dart`), e a **mesma linha** na tabela literal dos
dois testes (`test_party_configuration.py` e
`item_configuration_spec_test.dart`). A tela não muda.

Um jeito novo de cobrar: `PricingModel` nos dois lados, a conta em
`estimate_cents` (`catalog/pricing.py`) e em `Pricing.estimate`, e o caso na
tabela de `test_pricing.py` e de `value_objects_test.dart`.
