---
paths:
  - "lib/features/party_maker/**"
  - "backend/app/modules/parties/**"
  - "test/features/party_maker/**"
  - "test/app/party_flow_test.dart"
  - "backend/tests/test_parties*.py"
---

# Party Maker

Contexto completo: `docs/03-features/party-maker/README.md` (o índice da
pasta diz qual documento ler para cada assunto).

- As regras existem em dois lugares que **têm de concordar**: o agregado
  `Party` no app e `reconcile` em `backend/app/modules/parties/domain.py`.
  Mudou uma regra, mude nos dois, com o mesmo `code` de erro.
- Ordem ao mudar uma regra: teste e regra na API
  (`backend/tests/test_parties_domain.py`), teste e regra no app
  (`test/features/party_maker/domain/`), cenário em `test/integration/` se
  depender do catálogo ou de concorrência.
- Só `Party` altera os próprios itens e o próprio status. Fora dela, use os
  casos de uso.
- O app nunca envia nome nem preço de item: o servidor copia do catálogo.
- Um item que já está na festa mantém nome e preço de quando entrou.
- Gravação é o estado desejado inteiro (`PUT /parties/{id}`) com a `version`
  conhecida; 409 significa recarregar.
- `ApiPartyRepository` guarda o JSON confirmado, e não o objeto: `Party` é
  mutável, e uma instância compartilhada ficaria com uma alteração recusada.
- Festa vazia não existe: remover o último item apaga a festa.
- Mensagem de regra é texto para a tela, em português, sem nome de status.
- **Qualquer mudança aqui atualiza `docs/03-features/party-maker/`**: regra →
  `business-rules.md`; status → `domain.md`; campo → `entities.md`; tela →
  `user-flows.md` e `ux.md`; chamada à API → `integrations.md`; limite
  resolvido ou descoberto → `known-issues.md`.
