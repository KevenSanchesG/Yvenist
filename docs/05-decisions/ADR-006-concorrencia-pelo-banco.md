---
title: "ADR-006: Corridas são decididas pelo banco"
type: adr
status: aceita
date: 2026-10-02
---

# ADR-006: Corridas são decididas pelo banco

**Status:** aceita · **Data:** 2026-10-02 · **Decidida por:** evolução técnica
(commits `a12aea5`, `47ea6cc`, `4595f67`)

## Contexto

Várias regras são do tipo "só pode existir um": um e-mail por conta, um
documento por fornecedor, um salão por festa, uma decisão por cadastro. A API
atende várias requisições ao mesmo tempo.

## Problema

"Consultar se já existe e, se não, gravar" deixa uma janela: duas requisições
consultam juntas, as duas veem que não existe, as duas gravam.

## Decisão

Quem decide é o banco:

- **índice único** para o que só pode existir uma vez (e parcial, para "um
  salão por festa");
- **trava de linha** (`SELECT … FOR UPDATE`) para ler-decidir-gravar sobre o
  mesmo registro (token de renovação, festa, item da fila);
- **versão** na festa, para detectar gravação concorrente.

A consulta antes de gravar continua existindo, só para dar a mensagem certa no
caso comum. A violação do índice é capturada e vira **409 com um código
estável**, nunca 500.

Os testes disparam requisições simultâneas de verdade, com um banco de verdade
(`tests/test_concurrency.py`, só em PostgreSQL).

## Consequências

- As garantias valem com qualquer número de instâncias da API.
- Cada regra tem dois lugares: a consulta (mensagem) e a constraint (garantia).
- SQLite não exercita essas corridas: os testes de concorrência só rodam em
  PostgreSQL, no CI ou com um banco local.
- Um teste de concorrência mal escrito passa mesmo com o defeito. Aconteceu:
  as requisições saíam escalonadas pelo tempo de abrir a conexão. Por isso o
  arquivo aquece o pool antes e usa uma barreira para largar todas juntas; e
  cada teste foi visto falhar sem a correção.

## Alternativas consideradas

- **Só a consulta antes de gravar**: é o defeito descrito acima. O cadastro de
  fornecedor respondia 500 quando a mesma conta enviava duas vezes.
- **Trava na aplicação** (mutex em memória): só vale dentro de um processo.
- **Trava distribuída** (Redis): mais uma peça, para o que o banco já faz.
- **Nível de isolamento serializável em tudo**: correto, mas troca um 409 claro
  por erros de serialização que pedem nova tentativa em toda transação.
