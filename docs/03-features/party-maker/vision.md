---
title: Party Maker — visão
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — visão

## Para que serve

Substituir a planilha e as mensagens: em vez de anotar salão, buffet e atração
em lugares diferentes, a pessoa junta tudo em uma festa e vê quanto custa.

O texto que o próprio app usa (`app_shell.dart`): *"Entre para reunir salão,
atrações e serviços em um só lugar e pedir o orçamento."*

## O que entrega hoje

- Criar quantas festas quiser (até 100 por conta) e dar um nome a cada uma.
- Colocar anúncios na festa a partir de qualquer card (vitrine, explorar,
  busca, favoritos).
- Ver os itens e o total, e tirar itens.
- Solicitar o orçamento: a festa fica travada e o total daquele momento fica
  registrado.
- Voltar a editar uma festa travada.
- Ter as mesmas festas em qualquer aparelho onde a conta entrar (com a API).

## O que não é

- **Não é reserva nem contrato.** Nada garante disponibilidade na data.
- **Não avisa fornecedores.** "Solicitar orçamento" não envia nada a ninguém:
  não existe caixa de entrada de pedidos, nem contato pelo app.
- **Não cobra.** O status "paga" existe no ciclo, mas nenhum fluxo chega nele.
- **O preço não é final.** É a soma dos valores "a partir de" dos anúncios.

A tela "Formas de Pagamento" diz isso ao usuário: *"Por enquanto, você solicita
o orçamento da festa e combina o pagamento direto com cada fornecedor."*

## Intenção que o código deixa ver

`[INFERÊNCIA]` O domínio foi desenhado pensando em pagamento pelo app: o método
se chama `lockForPayment`, o registro do orçamento é `PartyPaymentSnapshot`
com `expiresAt`, existe `confirmPayment` e um `CancellationResult` com
reembolso e multa (sempre zero, comentados como "MVP"). Nada disso tem tela nem
integração. É um desenho à espera, não uma função.

## Em aberto

- OPEN QUESTION: o orçamento deve virar um pedido que chega ao fornecedor?
- OPEN QUESTION: o orçamento travado expira? (`expires_at` existe e nunca é
  preenchido.)
- OPEN QUESTION: a pessoa deve informar data e número de convidados antes de
  solicitar? (Os campos existem no domínio e na API; a tela não os pede.)
- OPEN QUESTION: pode haver mais de um item da mesma categoria que não seja
  salão (dois buffets)? Hoje pode.
