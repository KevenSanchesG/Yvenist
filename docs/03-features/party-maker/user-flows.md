---
title: Party Maker — fluxos do usuário
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — fluxos do usuário

O que a pessoa consegue fazer **hoje**, pela tela. Cada fluxo tem um teste em
`test/app/party_flow_test.dart`.

## 1. Colocar um anúncio em uma festa

1. Em qualquer card de anúncio, tocar no **+** ("Adicionar … a uma festa").
2. Visitante: aparece o pedido de login ("Entre para montar a sua festa."); ao
   entrar, o fluxo continua.
3. Abre a folha "Em qual festa você quer adicionar …?", com as festas que ainda
   aceitam itens (em planejamento).
4. Tocar em uma festa adiciona o item; ou tocar em **Criar nova festa**, dar um
   nome ("Ex.: 15 anos da Maria") e confirmar.
5. A folha fecha e um aviso confirma: "… adicionado a …". O **+** do card vira
   um ✓ ("… já está em uma festa. Adicionar a outra").

Tocar no ✓ abre a mesma folha. Escolher uma festa em que o anúncio já está soma
1 à quantidade daquele item, em vez de duplicá-lo.

Se o item não puder entrar (segundo salão, por exemplo), a folha continua
aberta com a mensagem da regra, e a pessoa pode escolher outra festa. Se a
tentativa era criando uma festa nova, essa festa é descartada.

## 2. Ver e montar a festa

A aba central decide o que mostrar (`PartyMakerEntryPage`):

| Situação | O que aparece |
|---|---|
| ainda carregando | "Carregando suas festas" |
| falhou e não há nada em memória | erro com "Tentar novamente" |
| há uma festa aberta | a montagem dela |
| não há nenhuma festa | a montagem vazia, convidando a ver anúncios |
| há festas e nenhuma aberta | o hub "Minhas Festas" |

Na montagem: a lista de itens (nome, preço, quantidade), "N itens
selecionados", o total e o botão do rodapé.

## 3. Tirar um item

Tocar no ícone de remover do item. Se for o **último**, o app pergunta
"Remover o último item?" e avisa que a festa será apagada.

## 4. Solicitar o orçamento

Tocar em **Solicitar orçamento**. A festa fica travada ("Orçamento
solicitado"), o aviso confirma e a aba volta para o hub. Com a festa travada, o
botão passa a ser **Editar festa** e o **+** dos cards não a oferece mais.

## 5. Voltar a editar

Abrir a festa travada e tocar em **Editar festa**: ela volta ao planejamento e
o orçamento registrado é descartado.

## 6. Escolher outra festa

No hub "Minhas Festas", tocar em uma festa a abre. Puxar a lista para baixo
recarrega. A seta do topo volta ao Início.

## O que a tela ainda não deixa fazer

O domínio e a API aceitam; falta a interface:

| Ação | Onde já existe |
|---|---|
| informar data e número de convidados | `Party.setEventDate`, `setGuestCount`; `event_at`, `guest_count` |
| renomear a festa | `RenamePartyTitleUseCase` |
| cancelar a festa | `CancelPartyUseCase` |
| mudar a quantidade de um item | `Party.updateItemQuantity` (a tela sempre adiciona 1; adicionar de novo o mesmo anúncio soma) |
| apagar uma festa sem tirar os itens um a um | `PartyRepository.deleteById` |
| ver o orçamento registrado (linhas e data) | `PartyPaymentSnapshot` |

Lista de pendências: [known-issues](known-issues.md).
