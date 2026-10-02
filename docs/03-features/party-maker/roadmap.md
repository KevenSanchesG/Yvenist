---
title: Party Maker — próximos passos
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — próximos passos

Nada aqui foi combinado com os donos: é o que o código e as lacunas indicam. Os
números `PM-n` são os de [known-issues](known-issues.md).

## Decisões que vêm antes do código

| OPEN QUESTION | Destrava |
|---|---|
| O orçamento vira um pedido para o fornecedor? Como ele responde? | PM-1; define se existe uma caixa de entrada do fornecedor |
| O orçamento expira? Em quanto tempo? | PM-7 |
| Data e convidados são obrigatórios para solicitar? | PM-2 |
| Haverá pagamento pelo app? | PM-6; hoje o desenho do domínio supõe que sim |
| Quantidade faz sentido para quais categorias? | PM-4 |

## `[PROPOSTA]` O que dá para fazer sem esperar decisão

Só tela; o domínio e a API já aceitam.

1. **Data e número de convidados** na montagem (PM-2).
2. **Renomear e apagar a festa** pelo hub (PM-3).
3. **Mostrar o orçamento registrado** na festa travada (PM-5).
4. **Editar a quantidade** do item (PM-4), ao menos para categorias que não
   sejam salão.

Cada item: tela, teste de fluxo, verificação de acessibilidade em 200% e a
atualização de [user-flows](user-flows.md) e [ux](ux.md).

## `[PROPOSTA]` Depende de outra funcionalidade

- **Página de detalhe do anúncio** (PM-8): a rota `GET /catalog/listings/{id}`
  existe; é uma tela do catálogo, não do Party Maker.
- **Aviso de item cujo anúncio saiu do catálogo** (PM-14): o app já sabe (a
  referência começa com `removed:`).

## Quando mexer nas regras

Qualquer regra nova entra nos dois lados (PM-9), nesta ordem:

1. teste em `backend/tests/test_parties_domain.py` e a regra em `reconcile`;
2. teste em `test/features/party_maker/domain/` e a regra em `Party`;
3. o mesmo `code` de erro nos dois;
4. um cenário em `test/integration/` se a regra depender do catálogo ou de
   concorrência;
5. a linha em [business-rules](business-rules.md).
