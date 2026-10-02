---
title: "Regra: {{title}}"
type: domain
updated: "{{date}}"
---

# Regra: {{title}}

> Uma regra simples é uma linha na tabela do documento do assunto. Use este
> modelo só quando a regra precisa de mais do que uma linha.

## A regra

Em português, como uma pessoa do negócio diria.

## Por quê

O motivo. Se houve escolha entre alternativas, link para o ADR.

## Onde é garantida

| Lugar | Arquivo |
|---|---|
| App | `lib/features/…` |
| API | `backend/app/modules/…` |
| Banco | índice, constraint ou trava |

## Erro

| Código | Mensagem para o usuário |
|---|---|
| `codigo_estavel` | "…" |

## Casos de borda

- O que acontece nas situações-limite.

## Testes

Os testes que reproduzem a regra, nos dois lados.
