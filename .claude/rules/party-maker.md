---
paths:
  - "lib/features/party_maker/**"
  - "lib/features/client/shared/listing_party_item_catalog.dart"
  - "lib/core/pricing/**"
  - "backend/app/modules/parties/**"
  - "backend/app/modules/quotes/**"
  - "backend/app/modules/catalog/pricing.py"
  - "test/features/party_maker/**"
  - "test/app/party_flow_test.dart"
  - "test/support/party_harness.dart"
  - "backend/tests/test_parties*.py"
  - "backend/tests/test_party_configuration.py"
  - "backend/tests/test_quotes.py"
  - "backend/tests/test_pricing.py"
---

# Party Maker

Contexto completo: `docs/03-features/party-maker/README.md` (o índice da
pasta diz qual documento ler para cada assunto). Por que é assim: ADR-019.

- É onde se compõe um evento, e não um carrinho. Uma festa é o evento (tipo,
  data, convidados) e os itens configurados para ele.
- As regras existem em dois lugares que **têm de concordar**: o agregado
  `Party` no app e `reconcile` em `backend/app/modules/parties/domain.py`.
  Mudou uma regra, mude nos dois, com o mesmo `code` de erro.
- Ordem ao mudar uma regra: teste e regra na API
  (`backend/tests/test_parties_domain.py`), teste e regra no app
  (`test/features/party_maker/domain/`), cenário em `test/integration/` se
  depender do catálogo, de concorrência ou da resposta de um fornecedor.
- O que cada categoria pede é uma tabela, e não código de tela: `_SPECS` em
  `parties/configuration.py` e `ItemConfigurationSpec` no app. Mudou um campo,
  mude nas duas e na **tabela literal** dos dois testes
  (`test_party_configuration.py`, `item_configuration_spec_test.dart`).
- A conta da estimativa também existe duas vezes: `estimate_cents`
  (`catalog/pricing.py`) e `Pricing.estimate`. Os mesmos casos nos dois testes.
- **Nunca invente um valor.** Sob consulta, ou sem a medida de que o preço
  depende, a estimativa é nula e a tela diz "Sob consulta".
- **Estimativa e orçamento não se misturam**: a estimativa é a conta do app; o
  orçamento é o que o fornecedor respondeu (`ItemQuote`). Na tela, em linhas
  separadas, cada uma com o seu nome.
- Só `Party` altera os próprios itens e o próprio status. Fora dela, use os
  casos de uso. A tela não calcula nem decide: mostra e dispara.
- O app nunca envia nome, preço, forma de cobrança nem a relação de um item: o
  servidor copia do catálogo. Um item que já está na festa mantém o que foi
  copiado quando entrou.
- "Orçamento recebido" e "edição solicitada" só saem da resposta de um
  fornecedor: o app nunca os envia como status.
- Gravação é o estado desejado inteiro (`PUT /parties/{id}`) com a `version`
  conhecida; 409 significa recarregar. A resposta de um fornecedor também
  avança a versão.
- `ApiPartyRepository` guarda o JSON confirmado, e não o objeto: `Party` é
  mutável, e uma instância compartilhada ficaria com uma alteração recusada.
  O repositório em memória guarda e devolve cópias (`Party.clone`).
- Uma festa pode ficar vazia: tirar o último item não a apaga.
- O Party Maker não importa o catálogo: o que ele precisa saber de um anúncio
  vem por `PartyItemCatalog`. A vitrine só chama `startAddToPartyFlow`.
- O fornecedor não vê o nome da festa nem quem pediu; o cliente não vê quem é
  o fornecedor. Não exponha um nem outro sem decisão dos donos.
- Mensagem de regra é texto para a tela, em português, sem nome de status.
- Regra que depende do "agora" usa o relógio recebido (`Clock`), nunca
  `DateTime.now()` direto.
- Na tela da festa a lista monta os itens conforme rolam: em teste, role até o
  item (`reveal`, em `test/support/party_harness.dart`).
- **Qualquer mudança aqui atualiza `docs/03-features/party-maker/`**: regra →
  `business-rules.md`; status → `domain.md`; campo ou tabela de categoria →
  `entities.md`; tela → `user-flows.md` e `ux.md`; chamada à API →
  `integrations.md`; limite resolvido ou descoberto → `known-issues.md`.
