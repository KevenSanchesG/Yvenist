---
title: "ADR-002: Estado com Provider e ChangeNotifier"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-002: Estado com Provider e ChangeNotifier

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica
(mantém a biblioteca do protótipo)

## Contexto

O protótipo usava `provider`. Ao ligar o app a dados reais foi preciso tratar
carregamento, erro, troca de conta e respostas atrasadas, que o protótipo não
tinha.

## Problema

Trocar de biblioteca de estado antes de crescer, ou organizar o que já existe?

## Decisão

Manter `provider` com controllers `ChangeNotifier`, em dois tipos:

- **do app inteiro**, criados em `AppState` antes do `runApp` e ligados à
  sessão fora da árvore de widgets;
- **de uma tela**, criados pela própria página.

Com três regras: operação devolve resultado e guarda a falha; dado assíncrono
tem estado explícito (`LoadState<T>`); controller descartado não notifica.

## Consequências

- Nenhuma dependência nova nem geração de código.
- A ligação sessão → favoritos, festas, fornecedor fica em um lugar
  (`AppState._onSessionChanged`) e não notifica durante a construção de uma tela.
- `ChangeNotifier` avisa tudo ou nada: uma tela que usa um pedaço do estado
  precisa de `context.select` para não reconstruir à toa (é o que o card faz).
- Não há ferramenta de inspeção de estado nem reprodução de eventos.

## Alternativas consideradas

- **Riverpod**: resolveria a injeção e o descarte, mas pediria reescrever todas
  as telas para ganhar o que a raiz de composição já dá.
- **Bloc**: eventos e estados explícitos; cerimônia demais para telas que, na
  maioria, carregam uma lista.
- **`setState` nas telas**: era o protótipo; não sobrevive a dados
  compartilhados entre abas.
