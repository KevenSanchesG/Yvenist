---
title: "ADR-003: API própria — FastAPI síncrono, monólito modular"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-003: API própria — FastAPI síncrono, monólito modular

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica,
com a autorização "pode criar backend também" (commit `a12aea5`)

## Contexto

O app não tinha servidor. Contas, festas em mais de um aparelho, fornecedores
e análise de anúncios precisam de um.

## Problema

Que servidor construir para um marketplace que ainda não tem usuários, mantido
por duas pessoas?

## Decisão

- Uma API em Python: **FastAPI + SQLAlchemy 2 síncrono + Alembic**, PostgreSQL
  em produção e SQLite para desenvolver sem instalar nada.
- **Monólito modular**: módulos `accounts`, `catalog`, `favorites`, `parties`,
  `vendors`, cada um com `router → service → models`.
- Onde há regra de negócio de verdade (festas), ela fica em um `domain.py`
  puro, sem banco nem HTTP.
- Sem fila, cache distribuído ou microsserviços.

## Consequências

- Um processo, um banco, um deploy.
- Síncrono: cada requisição ocupa uma thread; o gargalo é o banco. Simples de
  escrever, testar e depurar.
- O autor do projeto já trabalha com Python (o README o apresenta como
  desenvolvedor Flutter e Python).
- Tempo real (chat, notificações) vai pedir outra peça quando existir.
- As regras das festas existem duas vezes: no app (Dart) e na API (Python).

## Alternativas consideradas

- **Firebase/Supabase**: mais rápido para começar, mas as regras (um salão por
  festa, preço copiado do catálogo, fila de análise, rotação de tokens)
  iriam para regras de segurança ou funções, difíceis de testar; e prende o
  projeto a um fornecedor.
- **FastAPI assíncrono**: exigiria driver e sessão assíncronos em todo lugar,
  por um ganho que só aparece com muitas conexões ociosas.
- **Backend em Dart**: compartilharia as regras com o app, com um ecossistema
  de servidor bem menor.
- **Microsserviços**: nenhum problema atual pede.
