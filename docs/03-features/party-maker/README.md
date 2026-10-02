---
title: Party Maker
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker

A funcionalidade central do Yvenist: a pessoa escolhe anúncios, reúne em uma
**festa**, vê o total e solicita o orçamento. É a aba do meio da navegação.

## Em uma tela

- Uma festa é um nome e uma lista de itens. Cada item é um anúncio com o nome e
  o preço copiados na hora em que entrou.
- A festa tem um ciclo: em planejamento → orçamento solicitado (travada) → de
  volta ao planejamento, se a pessoa quiser editar.
- As regras existem em dois lugares que precisam concordar: o agregado `Party`
  no app e `reconcile` na API. O app decide na hora; a API decide de verdade.
- O orçamento é uma estimativa. Não chega a nenhum fornecedor.

## Documentos

| Preciso saber... | Leia |
|---|---|
| para que serve e o que não é | [vision](vision.md) |
| o agregado e o ciclo de vida | [domain](domain.md) |
| cada entidade e objeto de valor | [entities](entities.md) |
| todas as regras, com onde cada uma é garantida | [business-rules](business-rules.md) |
| o que a pessoa consegue fazer hoje, passo a passo | [user-flows](user-flows.md) |
| telas, textos, estados e acessibilidade | [ux](ux.md) |
| camadas, arquivos, como uma gravação acontece | [architecture](architecture.md) |
| como conversa com catálogo, sessão e API | [integrations](integrations.md) |
| o que falta, o que é limitado | [known-issues](known-issues.md) |
| próximos passos | [roadmap](roadmap.md) |

## Onde está o código

| Parte | Caminho |
|---|---|
| Domínio (app) | `lib/features/party_maker/domain/` |
| Dados (app) | `lib/features/party_maker/data/` |
| Telas e controller | `lib/features/party_maker/presentation/` |
| Entrada a partir de um anúncio | `lib/features/client/shared/listing_actions.dart`, `listing_card.dart` |
| Regras (API) | `backend/app/modules/parties/domain.py` |
| Persistência e rotas (API) | `backend/app/modules/parties/service.py`, `router.py`, `schemas.py`, `models.py` |
| Testes (app) | `test/features/party_maker/`, `test/app/party_flow_test.dart` |
| Testes (API) | `backend/tests/test_parties.py`, `test_parties_domain.py` |

## Quando atualizar esta pasta

Sempre que algo do Party Maker mudar. A tabela diz qual arquivo:

| Mudou... | Atualize |
|---|---|
| uma regra, um limite, uma mensagem de regra | [business-rules](business-rules.md) |
| um status ou transição | [domain](domain.md) |
| um campo de entidade ou objeto de valor | [entities](entities.md) |
| o que a tela deixa fazer | [user-flows](user-flows.md) e [ux](ux.md) |
| o formato da chamada à API | [integrations](integrations.md) |
| a organização do código | [architecture](architecture.md) |
| uma limitação foi resolvida ou descoberta | [known-issues](known-issues.md) |
