---
title: "ADR-009: Um formato de erro, em português, com código estável"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-009: Um formato de erro, em português, com código estável

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica
(commits `a12aea5`, `c9afed1`, `5708104`, `6b48a8b`)

## Contexto

O app mostra mensagens para pessoas, em português. Um erro pode nascer no
aparelho (regra da festa, sem rede) ou na API (validação, conflito, permissão).

## Problema

Como garantir que qualquer erro chegue à tela como uma frase que a pessoa
entende, e que o app ainda consiga reagir de forma diferente a cada tipo?

## Decisão

**Na API**, todo erro tem a mesma forma:

```json
{"error": {"code": "venue_already_selected", "message": "…", "details": {…}, "request_id": "…"}}
```

- `message` em português, pronta para a tela; `code` estável, para o app
  decidir; erros de campo em `details.fields`, também em português.
- O valor enviado nunca volta na resposta (pode ser uma senha).
- Erro não previsto vira 500 genérico, com o detalhe só no log.

**No app**, os repositórios lançam `AppFailure`, uma classe selada com um tipo
por situação. `ApiClient` faz a tradução. Erro desconhecido vira
`UnexpectedFailure`, com mensagem genérica.

- Com erros de campo, a mensagem da falha é a do **primeiro campo**, e a tela
  de cadastro mostra cada erro no campo certo.
- Controllers guardam a falha e devolvem `bool`: nenhuma exceção chega a um
  widget.

## Consequências

- A tela nunca mostra `Exception: …`, nome de classe ou texto em inglês.
- Uma regra que existe no app e na API usa o mesmo `code` nos dois.
- Mensagens ficam espalhadas (domínio do app, classes de erro da API, tradução
  dos erros do Pydantic em `core/errors.py`). Não há catálogo único.
- Sem internacionalização: o texto vem pronto do servidor em um idioma.

## Alternativas consideradas

- **A API devolve só códigos e o app traduz**: prepararia a
  internacionalização, mas todo erro novo do servidor exigiria uma versão nova
  do app para ter texto.
- **Erro padrão do FastAPI** (`{"detail": …}`): formato diferente para
  validação e para erros de negócio, e em inglês.
- **RFC 9457 (Problem Details)**: padrão e equivalente; o formato próprio é
  menor e já carrega o que o app usa.
- **Exceções chegando ao widget com `try/catch` na tela**: é fácil esquecer um,
  e o resultado é uma tela vermelha ou um aviso com texto técnico.
