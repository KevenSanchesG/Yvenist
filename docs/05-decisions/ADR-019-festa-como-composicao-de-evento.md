---
title: "ADR-019: A festa é a composição de um evento, com estimativa e orçamento separados"
type: adr
status: aceita, aguardando confirmação dos donos
date: 2026-10-03
tags: [party-maker]
---

# ADR-019: A festa é a composição de um evento, com estimativa e orçamento separados

**Status:** aceita, aguardando confirmação dos donos · **Data:** 2026-10-03 ·
**Decidida por:** os donos pediram o Party Maker como núcleo de composição de
eventos e delegaram as decisões técnicas ("decida e implemente"); as escolhas
de negócio da seção "O que os donos precisam confirmar" foram tomadas sem
eles. Commits `144c0f5`, `cab63f3`, `b137669`.

Estende o [ADR-005](ADR-005-festa-gravada-por-estado.md) e o
[ADR-007](ADR-007-dinheiro-e-snapshots.md), que continuam valendo: a festa
segue gravada inteira, com versão, e o item segue guardando uma cópia do
catálogo.

## Contexto

Até 2 de outubro de 2026 uma festa era um nome e uma lista de anúncios; o
total era preço × quantidade. "Solicitar orçamento" travava a festa e não
chegava a ninguém. Um salão, um buffet e um brinquedo entravam do mesmo jeito,
sem nada que dissesse a duração, o tema ou o cardápio. Todo anúncio tinha um
preço "a partir de"; não havia cobrança por pessoa, por hora, nem "sob
consulta". Data e convidados existiam no domínio e nenhuma tela os pedia.

O pedido dos donos: o Party Maker é o lugar onde se **compõe e gerencia um
evento**, e não um carrinho. Elementos de naturezas diferentes, configurados
antes de entrar; vários jeitos de cobrar; estimativa separada de orçamento, sem
nunca inventar um valor; itens que dependem de outros; pedido de orçamento com
"edição solicitada" e reenvio; histórico.

## Problema

Como representar um evento feito de coisas diferentes, que cobram de jeitos
diferentes e dependem umas das outras, e o que "orçamento" passa a significar?

## Decisão

1. **A festa é um evento.** Tem tipo, data, horário e número de convidados, e
   os itens escolhidos para ele. Pode existir sem itens.
2. **Cada item é configurado, e a configuração é dado.** Um mapa simples de
   chave para inteiro ou texto, gravado em `party_items.configuration` (JSON).
   O que cada categoria pede fica em uma tabela de regras: `_SPECS`
   (`backend/app/modules/parties/configuration.py`) e `ItemConfigurationSpec`
   (`lib/features/party_maker/domain/rules/`). A tela monta o formulário a
   partir dela. Categoria nova = uma entrada na tabela.
3. **O preço tem um modelo**: fixo, por pessoa, por hora, por unidade ou sob
   consulta, com um valor mínimo opcional. A estimativa é uma conta, a mesma
   nos dois lados; quando falta o valor ou a medida, o resultado é "não há
   estimativa", e nunca um número.
4. **Estimativa e orçamento são duas coisas.** A estimativa é do app. O
   orçamento é **por item**: cada fornecedor responde o valor do item dele, e
   a resposta fica guardada no item, ao lado da estimativa.
5. **Itens podem se ligar, em um nível só.** Serviço do próprio anúncio
   (opcional ou obrigatório) e parceiro recomendado. Quem diz qual é a relação
   é o catálogo, e não o app.
6. **O ciclo do orçamento**: solicitado → recebido ou edição solicitada →
   aceito, com volta para a edição a qualquer momento. "Recebido" e "edição
   solicitada" são **derivados** das respostas, nunca pedidos pelo app. Cada
   novo pedido é uma rodada, e só o que mudou volta a ser pedido.
7. **O histórico só cresce** (`party_events`): pedidos, respostas, voltas para
   a edição, aceite e cancelamento.
8. **O fornecedor responde por uma caixa de pedidos** (módulo `quotes`): vê um
   pedido por item dos próprios anúncios, com o evento e a configuração, sem o
   nome da festa nem de quem pediu.
9. **As situações que dá para calcular não viram status**: "pronta para
   pedir", "reenviada", "aguardando ajustes".
10. **No modo demonstração** a própria conta responde como fornecedor
    (`DemoVendorAnswers`), para o caminho inteiro poder ser visto sem API.

## O que os donos precisam confirmar

Decisões de negócio tomadas para a funcionalidade existir. Cada uma está em
[known-issues](../03-features/party-maker/known-issues.md) (PM-20 a PM-26),
com o que muda se a resposta for outra.

- O orçamento é por item, um valor por fornecedor, e não um valor para a festa.
- Pedir o orçamento exige data no futuro e número de convidados.
- Uma festa pode ficar vazia.
- "Orçamento aceito" existe, e não reserva nem cobra nada.
- Nenhuma das pontas vê quem é a outra.
- O que cada categoria pergunta (a tabela de campos).
- Um serviço do próprio anunciante pede só o que o preço dele usa.

## Consequências

- A pessoa vê quanto o evento deve custar antes de falar com alguém, e o que
  falta para pedir o orçamento.
- O pedido chega a quem pode responder. Fecha a maior lacuna do produto.
- Um anúncio sob consulta pode entrar em uma festa sem virar "R$ 0,00".
- A tabela de categorias existe duas vezes (Dart e Python), como as outras
  regras da festa. Os testes dos dois lados a comparam com a **mesma tabela
  literal**: mudar um lado só faz o teste dele falhar.
- A configuração em JSON não tem coluna por campo: não dá para filtrar no
  banco por "tema" sem ler o JSON. Hoje ninguém precisa.
- O orçamento vive no item. Quando a pessoa altera o item, o valor antigo é
  descartado; o que **foi pedido** em uma rodada anterior não fica guardado
  campo a campo, só as respostas, no histórico.
- Não há aviso: a resposta aparece quando a pessoa atualiza a festa.
- "Aceito" pode ser lido como compromisso. Os textos da tela e os Termos dizem
  que não é reserva nem pagamento.
- Uma festa antiga, gravada antes disto, continua abrindo: os itens dela viram
  "por unidade" e só são validados quando a pessoa os altera.
- A regra antiga "festa vazia não existe" deixou de valer.

## Alternativas consideradas

- **Manter preço × quantidade e acrescentar um campo de observações**: não
  estima o que é por pessoa ou por hora, e "sob consulta" continuaria sendo um
  preço zero.
- **Uma coluna (ou uma tabela) por campo de cada categoria**: tipado no banco,
  mas cada categoria nova seria uma migração e um formulário escrito à mão.
- **A API enviar a descrição do formulário** (a tabela em um lugar só): o app
  precisa validar sem rede e funcionar no modo demonstração, e os rótulos são
  texto de tela. Ficaram duas tabelas, presas uma à outra pelos testes.
- **Um orçamento único para a festa**: uma festa reúne vários fornecedores; um
  valor só não teria quem o respondesse.
- **Um "pedido de orçamento" como registro à parte, com cópia dos itens a cada
  rodada**: guardaria exatamente o que foi pedido em cada rodada. Mais tabelas
  e mais uma cópia para manter coerente; o histórico de respostas atende o que
  as telas mostram hoje.
- **Um status para cada situação** ("pronta", "em análise", "reenviada"): mais
  transições para manter iguais nos dois lados, para dizer o que já se sabe
  olhando os itens.
- **Negociação por conversa**: não existe chat no app.
- **Apagar a festa quando o último item sai** (a regra anterior): um evento
  existe antes de ter itens, e a pessoa perderia a data e os convidados
  informados.
