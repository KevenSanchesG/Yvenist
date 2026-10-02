---
title: "ADR-001: App em camadas por funcionalidade, com contratos e raiz de composição"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-001: App em camadas por funcionalidade, com contratos e raiz de composição

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica
(commits `c9afed1`, `42630a4`, `653648f`)

## Contexto

O protótipo já tinha pastas por funcionalidade (`features/`) e o Party Maker
com um domínio próprio. Mas todas as telas liam dados de exemplo escritos nelas
mesmas, e o controller do Party Maker dependia da classe concreta do
repositório em memória.

## Problema

Como ligar o app a uma API de verdade sem reescrever as telas, e sem perder a
possibilidade de abri-lo sem backend?

## Decisão

- Dentro de cada funcionalidade: `domain/` (entidades e o **contrato** do
  repositório), `data/` (implementações), `presentation/`.
- Cada contrato tem duas implementações completas: `Api…Repository` e
  `InMemory…Repository`.
- Um único arquivo, `lib/app/app_dependencies.dart`, escolhe quais usar.
- O domínio só é "completo" (objetos de valor, casos de uso) onde há regra de
  negócio: o Party Maker.

## Consequências

- As telas não sabem se estão no modo demonstração ou falando com a API.
- Os testes de tela rodam sem rede, com as mesmas regras de produção.
- Cada funcionalidade nova custa duas implementações de repositório.
- Uma regra que existe no repositório em memória e na API pode divergir: os
  testes de integração são a conferência.

## Alternativas consideradas

- **Camadas no topo** (`data/`, `domain/`, `presentation/` na raiz): espalha
  cada funcionalidade por três árvores. O protótipo já era por funcionalidade.
- **Casos de uso em toda funcionalidade**: viraria uma classe por chamada, só
  repassando para o repositório.
- **Mock só nos testes, sem modo demonstração**: o app deixaria de abrir sem
  backend, que é como ele é mostrado e desenvolvido hoje.
- **Injeção com `get_it` ou gerador de código**: um único arquivo pequeno
  (`app_dependencies.dart`) resolve, sem dependência nova.
