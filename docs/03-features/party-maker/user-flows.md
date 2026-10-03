---
title: Party Maker — fluxos do usuário
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker — fluxos do usuário

O que a pessoa consegue fazer **hoje**, pela tela. Cada fluxo tem um teste em
`test/app/party_flow_test.dart`.

## 1. Colocar um anúncio em uma festa

1. Em qualquer card de anúncio (vitrine, explorar, busca, favoritos), tocar no
   **+** ("Adicionar … a uma festa").
2. Visitante: aparece o pedido de login ("Entre para montar a sua festa."); ao
   entrar, o fluxo continua.
3. Abre a folha "Em qual festa você quer adicionar …?", com as festas que ainda
   aceitam itens. Tocar em uma, ou em **Criar nova festa** e dar um nome.
4. Abre a **configuração do item**. Nada entra na festa antes de confirmar.
5. Preencher o que a categoria pede e tocar em **Adicionar à festa**.
6. A tela fecha e um aviso confirma: "… adicionado a …", com o atalho **Ver
   festa**. O **+** do card vira um ✓ ("… já está em uma festa. Adicionar a
   outra").

Se a festa escolhida **já tem** o anúncio, a mesma tela abre para **alterar** o
item que está lá, com um recado explicando ("… já está em …. Altere o que
precisar: o mesmo item não entra duas vezes.").

Se a festa era nova e a pessoa desiste, ou o item não pode entrar, a festa não
chega a ser criada.

## 2. Configurar um item

A tela mostra só o que aquele item pede ([entidades](entities.md)):

| Parte | Quando aparece |
|---|---|
| cabeçalho: foto, nome, categoria, como cobra, valor mínimo, capacidade | sempre |
| **Dados do evento** | o item é um salão (tipo, data, horário e convidados; só o tipo é opcional) ou é cobrado por pessoa (só os convidados). Vêm preenchidos com o que a festa já tem, e valem para a festa inteira |
| **Sobre este item**: a quantidade (onde faz sentido) e os campos da categoria | sempre |
| **Serviços de …**: os serviços do próprio anunciante, cada um com uma caixa de marcar | o anúncio tem serviços. O obrigatório já vem marcado e não desmarca; o que é cobrado por hora ou por unidade pede a duração ou a quantidade ao ser marcado |
| rodapé: **Estimativa deste item** e o botão | sempre |

A estimativa do rodapé muda enquanto a pessoa preenche. Sem a medida de que o
preço depende, ou sob consulta, ela diz "Sob consulta" (ou "R$ … + 1 sob
consulta"), nunca um valor inventado.

Ao confirmar, cada campo é conferido pela regra da categoria; o que falta
aparece embaixo do próprio campo, e a tela rola até o primeiro. Uma regra da
festa que barra o item (segundo salão, convidados acima da capacidade) aparece
em um aviso no topo, e o formulário continua aberto com o que foi preenchido.

## 3. Criar uma festa sem partir de um anúncio

Na aba central, sem nenhuma festa: **Criar festa**. Com festas: **Nova
festa**. A tela pede o nome; o tipo, a data, o horário e os convidados são
opcionais ("você informa quando escolher o salão ou pedir o orçamento"). A
festa nasce vazia e já aberta, com os atalhos **Explorar anúncios** e **Ver os
mais procurados**.

## 4. A festa aberta

A aba central decide o que mostrar (`PartyMakerEntryPage`):

| Situação | O que aparece |
|---|---|
| ainda carregando | "Carregando suas festas" |
| falhou e não há nada em memória | erro com "Tentar novamente" |
| há uma festa aberta | a festa |
| senão | "Minhas Festas": a lista, ou o convite para criar a primeira |

Na festa, de cima para baixo:

1. **Em que pé está** e o próximo passo, em uma frase.
2. **O evento**: tipo, data e hora, convidados (ou "a definir"), com o lápis
   para editar.
3. **Falta para pedir o orçamento**: a lista do que impede o pedido, com o
   atalho "Informar dados do evento". Só aparece se houver pendência.
4. **Os itens**, agrupados por categoria (espaço, buffet, atrações…). Cada um
   com o que foi configurado, a estimativa e, se já houver, a resposta do
   fornecedor e o recado dele.
5. **Recomendados por …**: os parceiros que um item indica e que ainda não
   estão na festa, com um **+** para cada.
6. Rodapé fixo: **Estimativa do evento**, **Orçamento recebido** (quando há) e
   a ação que cabe agora.

## 5. Alterar e remover um item

- **Lápis**: abre a configuração com o que a pessoa tinha informado. Para um
  anúncio com serviços, dá para marcar e desmarcar os opcionais.
- **Lixeira**: pergunta antes, dizendo o que sai junto (os serviços do
  anúncio) e o que fica (os parceiros que ele tinha indicado). A lixeira de um
  serviço obrigatório fica desabilitada, com o motivo no rótulo.

Tirar o último item deixa a festa vazia; ela não é apagada.

## 6. Editar os dados do evento

Pelo lápis do evento ou pelo menu **⋮ → Editar dados do evento**. Se algum
fornecedor já tinha informado um valor, a tela avisa que mudar o tipo, a data
ou os convidados descarta esses valores.

## 7. Solicitar o orçamento

O botão **Solicitar orçamento** só fica habilitado sem pendências. Ao tocar, um
diálogo explica o que é enviado ("o tipo de evento, a data, o número de
convidados e o que você informou no item. Seu nome e o nome da festa não são
enviados") e que a festa fica travada. Confirmado, a festa passa a "Orçamento
solicitado" e cada item mostra "Aguardando o fornecedor".

## 8. Acompanhar as respostas

Não há aviso automático: a pessoa toca em **Atualizar a festa** (ou puxa a
lista para baixo). Cada item mostra a resposta dele:

| Resposta | Na tela |
|---|---|
| valor | "Orçamento: R$ …", com o recado, se houver |
| pedido de alteração | "O fornecedor pediu uma alteração", com o motivo; o item ganha uma borda de aviso |
| recusa | "O fornecedor não pode atender", com o motivo |

O rodapé mostra o **Orçamento recebido** ao lado da estimativa, com "(2 de 3)"
enquanto faltar alguém.

## 9. Edição solicitada: ajustar e reenviar

Quando um item volta, a festa fica como "Edição solicitada". **Editar festa**
a devolve ao planejamento; a pessoa altera ou tira o item e solicita de novo.
A festa mostra "Orçamento solicitado (2ª rodada)", e só o que mudou volta a
ser pedido.

## 10. Aceitar, cancelar, apagar

| Ação | Onde | Confirmação |
|---|---|---|
| **Aceitar orçamento** | rodapé, com o orçamento recebido | mostra o total e avisa que o pagamento é combinado direto com cada fornecedor |
| **Editar festa** | rodapé, depois do pedido | só pergunta se o orçamento já foi aceito (desfaz o aceite) |
| **Cancelar festa** | menu ⋮, depois do pedido | sim |
| **Apagar festa** | menu ⋮, em planejamento ou cancelada | sim; não dá para desfazer |

## 11. Histórico

Menu **⋮ → Histórico da festa**: cada pedido, cada resposta e cada volta para
a edição, do mais novo para o mais antigo, com a data e a rodada.

## 12. Escolher outra festa

A seta do topo volta para "Minhas Festas". Cada festa aparece com o status, a
data e os convidados, a quantidade de itens, a estimativa e, se houver, o
orçamento recebido.

## 13. O fornecedor responde

No **Perfil → Modo Fornecedor → Pedidos de orçamento**: os pedidos agrupados
por evento (tipo, data, convidados), cada item com o que o cliente configurou
e a estimativa que ele viu. Três respostas: **Informar valor** (ou "Corrigir
valor"), **Pedir alteração** e **Recusar**, as duas últimas com o motivo
obrigatório.

No **modo demonstração** não há outra conta para ser o fornecedor: a festa com
o orçamento solicitado mostra **Responder como fornecedor (demo)**, que abre a
mesma tela.

## O que a tela ainda não deixa fazer

Lista de pendências: [known-issues](known-issues.md).
