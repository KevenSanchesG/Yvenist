---
title: "ADR-007: Dinheiro em centavos; o item guarda cópia de nome e preço"
type: adr
status: aceita
date: 2026-10-02
tags: [party-maker]
---

# ADR-007: Dinheiro em centavos; o item guarda cópia de nome e preço

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica
(o domínio do protótipo já usava `Money` em centavos; a API seguiu)

## Contexto

Um anúncio pode mudar de preço, mudar de nome ou ser apagado depois que alguém
já o colocou em uma festa. E somar preços com ponto flutuante dá erros de
centavo.

## Problema

O que a festa mostra quando o anúncio muda? E como representar valores?

## Decisão

- **Dinheiro é sempre inteiro, em centavos**, com a moeda ao lado (`Money` no
  app, colunas `*_cents` e `currency` na API). Uma festa tem uma moeda só.
- **O item da festa copia** nome, categoria, preço e imagem do anúncio no
  momento em que entra. Depois disso só a quantidade muda.
- **Apagar o anúncio não apaga o item**: a ligação vira nula e a cópia fica.
- **Solicitar o orçamento tira outra cópia**: o total e as linhas daquele
  momento (`PartySnapshot`).

## Consequências

- O planejamento da pessoa não muda sozinho: o que ela viu é o que fica.
- O total da festa pode estar desatualizado em relação ao catálogo, e a tela
  não avisa. Não há "atualizar preços".
- Depois que um anúncio é apagado, o nome, o preço e a imagem dele continuam
  nas festas de outras contas. A Política de Privacidade diz isso.
- Toda conta de dinheiro é exata. Formatação e interpretação do que a pessoa
  digita ficam em um lugar (`core/utils/money_formatter.dart`).

## Alternativas consideradas

- **Guardar só a referência ao anúncio** e ler o preço atual: a festa mudaria
  de total sozinha e quebraria quando o anúncio saísse do catálogo.
- **`double` ou decimal para dinheiro**: `double` erra centavos; decimal é
  correto, mas inteiro é mais simples e igual nos dois lados (Dart não tem
  decimal nativo).
- **Apagar em cascata os itens do anúncio removido**: a pessoa perderia parte
  do planejamento sem aviso.
