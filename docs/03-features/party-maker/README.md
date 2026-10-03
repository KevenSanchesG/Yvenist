---
title: Party Maker
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker

O núcleo do Yvenist: onde a pessoa **compõe um evento**. Ela escolhe anúncios,
configura cada um do jeito que a categoria pede, vê a estimativa, pede o
orçamento aos fornecedores e acompanha as respostas. É a aba do meio da
navegação. Não é um carrinho: nada é comprado aqui.

## Em uma tela

- Uma **festa** é um evento (nome, tipo, data, convidados) e os **itens**
  escolhidos para ele.
- Cada item é um anúncio, ou um serviço do próprio anúncio, **configurado**:
  um salão pede a duração; uma decoração, o tema. Os campos vêm de uma tabela
  de regras, e não da tela.
- **Estimativa** e **orçamento** são coisas diferentes e nunca se misturam: a
  estimativa é a conta do app com o preço do anúncio; o orçamento é o valor que
  cada fornecedor respondeu. O que é "sob consulta" nunca vira um número.
- Itens podem depender uns dos outros: o buffet do salão só existe com o
  salão; uma taxa obrigatória não sai sozinha; um parceiro recomendado fica.
- O ciclo: em planejamento → orçamento solicitado → (edição solicitada) →
  orçamento recebido → orçamento aceito. Em qualquer ponto a pessoa pode
  voltar a editar e pedir de novo.
- As regras existem em dois lugares que precisam concordar: o agregado `Party`
  no app e `reconcile` na API. O app decide na hora; a API decide de verdade.

Por que é assim: [ADR-019](../../05-decisions/ADR-019-festa-como-composicao-de-evento.md).

## Documentos

| Preciso saber... | Leia |
|---|---|
| para que serve e o que não é | [vision](vision.md) |
| o agregado, os status e o ciclo de vida | [domain](domain.md) |
| cada entidade e objeto de valor, campo a campo | [entities](entities.md) |
| todas as regras, com onde cada uma é garantida | [business-rules](business-rules.md) |
| o que a pessoa consegue fazer, passo a passo | [user-flows](user-flows.md) |
| telas, textos, estados e acessibilidade | [ux](ux.md) |
| camadas, arquivos, como uma gravação acontece | [architecture](architecture.md) |
| como conversa com catálogo, sessão, fornecedor e API | [integrations](integrations.md) |
| o que falta, o que é limitado | [known-issues](known-issues.md) |
| próximos passos | [roadmap](roadmap.md) |

## Onde está o código

| Parte | Caminho |
|---|---|
| Domínio (app) | `lib/features/party_maker/domain/` |
| Dados (app) | `lib/features/party_maker/data/` |
| Telas e controllers | `lib/features/party_maker/presentation/` |
| Entrada a partir de um anúncio | `lib/features/party_maker/presentation/add_to_party_flow.dart`, chamado por `lib/features/client/shared/listing_actions.dart` |
| Ponte com o catálogo | `lib/features/client/shared/listing_party_item_catalog.dart` |
| Regras (API) | `backend/app/modules/parties/domain.py`, `configuration.py` |
| Persistência e rotas (API) | `backend/app/modules/parties/` (`service.py`, `router.py`, `schemas.py`, `models.py`, `mapping.py`) |
| Pedidos do fornecedor (API) | `backend/app/modules/quotes/` |
| Conta da estimativa | `backend/app/modules/catalog/pricing.py` e `lib/features/party_maker/domain/value_objects/pricing.dart` |
| Testes (app) | `test/features/party_maker/`, `test/app/party_flow_test.dart`, `test/support/party_harness.dart` |
| Testes (API) | `backend/tests/test_parties.py`, `test_parties_domain.py`, `test_party_configuration.py`, `test_quotes.py`, `test_pricing.py` |

## Quando atualizar esta pasta

Sempre que algo do Party Maker mudar. A tabela diz qual arquivo:

| Mudou... | Atualize |
|---|---|
| uma regra, um limite, uma mensagem de regra | [business-rules](business-rules.md) |
| um status ou transição | [domain](domain.md) |
| um campo de entidade, de objeto de valor ou da configuração de uma categoria | [entities](entities.md) |
| o que a tela deixa fazer | [user-flows](user-flows.md) e [ux](ux.md) |
| o formato de uma chamada à API | [integrations](integrations.md) |
| a organização do código | [architecture](architecture.md) |
| uma limitação foi resolvida ou descoberta | [known-issues](known-issues.md) |
