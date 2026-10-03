---
title: Party Maker — visão
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker — visão

## Para que serve

Substituir a planilha e as mensagens: em vez de anotar salão, buffet e atração
em lugares diferentes e pedir o preço de cada um por telefone, a pessoa compõe
o evento em um lugar só, vê quanto ele deve custar e pede o orçamento de tudo
de uma vez.

O texto que o próprio app usa (`lib/app/app_shell.dart`): *"Entre para reunir
salão, atrações e serviços em um só lugar e pedir o orçamento."*

## O que entrega hoje

- Criar quantas festas quiser (até 100 por conta), cada uma com nome, tipo de
  evento, data, horário e número de convidados.
- Colocar anúncios na festa a partir de qualquer card (vitrine, explorar,
  busca, favoritos), configurando cada um pelo que a categoria pede.
- Levar junto os serviços do próprio anunciante (o buffet do salão, uma taxa
  obrigatória) e ver os parceiros que ele recomenda.
- Alterar e remover itens, sabendo antes o que sai junto.
- Ver a **estimativa** do evento, calculada pelo jeito que cada anúncio cobra
  (valor fixo, por pessoa, por hora, por unidade, com valor mínimo).
- Saber o que falta para pedir o orçamento, antes de tentar.
- **Solicitar o orçamento**: cada fornecedor recebe o pedido do item dele.
- Acompanhar as respostas: o valor informado, um pedido de alteração ou uma
  recusa, com o recado do fornecedor.
- Voltar a editar, ajustar e reenviar (uma nova rodada).
- Aceitar o orçamento recebido, cancelar, apagar.
- Ver o histórico de pedidos e respostas.
- Como fornecedor: ver os pedidos dos próprios anúncios e respondê-los.
- Ter as mesmas festas em qualquer aparelho onde a conta entrar (com a API).

## O que não é

- **Não é um carrinho nem um checkout.** Nada é comprado nem pago aqui.
- **Não é reserva nem contrato.** Aceitar o orçamento não garante a data: o
  app não tem agenda nem disponibilidade dos fornecedores.
- **A estimativa não é o preço.** É a conta feita com o preço publicado. O
  valor que vale é o que o fornecedor responde.
- **Não avisa ninguém em tempo real.** Não há notificação: a resposta de um
  fornecedor aparece quando a pessoa atualiza a festa, e o pedido aparece para
  o fornecedor quando ele abre a caixa de pedidos.
- **Não põe as duas pontas em contato.** Não há chat nem dados de contato: a
  conversa é o recado que acompanha cada resposta.

A tela "Formas de Pagamento" continua dizendo: *"Por enquanto, você solicita o
orçamento da festa e combina o pagamento direto com cada fornecedor."*

## Em aberto

As perguntas que só os donos respondem estão em [roadmap](roadmap.md) e, as
decisões de negócio tomadas sem eles nesta versão, no
[ADR-019](../../05-decisions/ADR-019-festa-como-composicao-de-evento.md).
