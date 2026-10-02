---
title: "ADR-005: A festa é gravada inteira, por estado desejado, com versão"
type: adr
status: aceita
date: 2026-10-02
tags: [party-maker]
---

# ADR-005: A festa é gravada inteira, por estado desejado, com versão

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica
(commits `a12aea5`, `42630a4`, `653648f`)

## Contexto

O app já tinha o agregado `Party`, com as regras aplicadas no aparelho. A
mesma conta pode abrir a festa em dois aparelhos. E o preço de um item não
pode ser o que o app disser.

## Problema

Que formato a API oferece para salvar uma festa: uma rota por operação
(adicionar item, remover, travar…) ou a festa inteira?

## Decisão

- **Uma rota**: `PUT /parties/{id}` recebe o **estado que o app quer gravar**
  (título, data, convidados, status, e os itens só com id, anúncio e
  quantidade).
- O servidor compara o estado atual com o desejado (`reconcile`), aceita só o
  que as regras permitem e **copia nome, categoria e preço do catálogo**.
- A resposta é a festa como ficou; ela substitui a cópia do app.
- Cada gravação leva a `version` conhecida. Versão antiga → 409, e o app
  recarrega.
- Os ids da festa e dos itens são **gerados no app**. Repetir uma requisição
  cuja resposta se perdeu não cria duplicata; uma gravação idêntica à atual não
  grava nada.

## Consequências

- O app mantém as regras no aparelho e responde na hora; a API é a autoridade.
- A API tem uma rota de escrita em vez de uma por operação, e as regras ficam
  em uma função pura, testada sem banco.
- As regras existem duas vezes (Dart e Python) e precisam mudar juntas.
- Cada gravação envia a festa inteira. Com o teto de 50 itens, é pouco.
- Dois aparelhos editando ao mesmo tempo: o segundo perde a alteração e
  precisa refazê-la sobre o estado novo. Não há mesclagem.

## Alternativas consideradas

- **Uma rota por operação** (`POST /parties/{id}/items`…): espelharia cada
  caso de uso do app no servidor e obrigaria o app a esperar a rede para cada
  toque, ou a manter uma fila de operações pendentes.
- **Sincronização com mesclagem (CRDT)**: resolveria a edição simultânea sem
  conflito; complexidade desproporcional para uma lista de itens.
- **Confiar no preço enviado pelo app**: qualquer pessoa montaria uma festa
  com o preço que quisesse.
- **Ids gerados pelo servidor**: a criação deixaria de ser repetível com
  segurança, e o app teria de trocar ids provisórios pelos definitivos.
