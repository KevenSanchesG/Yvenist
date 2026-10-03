---
title: Party Maker — problemas e limites conhecidos
type: feature
tags: [party-maker]
updated: 2026-10-03
---

# Party Maker — problemas e limites conhecidos

Só o que é do Party Maker. O resto do projeto está na
[lista geral](../../07-known-issues/README.md).

## Decisões de negócio tomadas sem os donos

O pedido de 3 de outubro de 2026 mandava decidir e implementar. Estas escolhas
são de produto, e ficam **aguardando a confirmação dos donos**
([ADR-019](../../05-decisions/ADR-019-festa-como-composicao-de-evento.md)):

| # | O que foi decidido | Se os donos quiserem diferente |
|---|---|---|
| PM-20 | O orçamento é pedido **por item**, a cada fornecedor, e a resposta é um valor por item | muda `quotes/` e a tela de pedidos |
| PM-21 | Pedir o orçamento exige data futura e número de convidados | uma linha em `_request_quote` e em `quoteBlockers` |
| PM-22 | Uma festa pode ficar vazia; tirar o último item não a apaga | `RemoveItemFromPartyUseCase` |
| PM-23 | Existe o status "orçamento aceito", que não reserva nada nem cobra | tirar `confirmed` do ciclo |
| PM-24 | O fornecedor não vê o nome da festa nem quem pediu; o cliente não vê o nome do fornecedor | expor um nome público exige criá-lo no cadastro |
| PM-25 | O que cada categoria pede (a tabela de campos) | a tabela é dado: `ItemConfigurationSpec` e `_SPECS` |
| PM-26 | Um serviço do próprio anunciante pede só o que o preço dele usa, e não os campos da categoria | idem |

## Lacunas de produto

| # | O quê | Efeito |
|---|---|---|
| PM-1 | Não há aviso quando um fornecedor responde, nem quando chega um pedido | a pessoa precisa abrir a festa e atualizar; o fornecedor, abrir a caixa de pedidos |
| PM-2 | O cliente e o fornecedor não têm como conversar pelo app | a única comunicação é o recado de cada resposta |
| PM-3 | O orçamento aceito não reserva a data nem gera contrato | o app não tem agenda de fornecedor |
| PM-4 | Um orçamento respondido não expira | o valor fica valendo até a pessoa aceitar ou mudar a festa; `expires_at` do retrato nunca é preenchido |
| PM-5 | `paid` é inalcançável | não há pagamento |
| PM-6 | Não há página de detalhe do anúncio | a pessoa decide pelo card e pela tela de configuração |
| PM-7 | Só o salão pode ser cadastrado pelo app, e a tela não deixa o fornecedor indicar parceiros | os parceiros recomendados existem na API e nos dados de demonstração |
| PM-8 | Um serviço do próprio anunciante não tem campo de observações na tela | a observação vai no item principal |
| PM-9 | Depois de enviado, o anúncio não pode ser editado: nem o preço, nem os serviços | [KI-14](../../07-known-issues/README.md) |

## Limites técnicos

| # | O quê | Quando incomoda |
|---|---|---|
| PM-10 | As regras estão duplicadas no app (`Party`) e na API (`reconcile`), em linguagens diferentes, e são mantidas em sincronia à mão | toda vez que uma regra muda. Os testes dos dois lados, a tabela de categorias conferida contra o mesmo literal e os testes de integração são a rede |
| PM-11 | A API recusa três coisas que o app deixa passar (anúncio despublicado, tipo de evento que saiu do catálogo, ligação que o catálogo não confirma) | o erro aparece só depois de enviar ([business-rules](business-rules.md)) |
| PM-12 | `ownerId` é uma `String` simples | o próprio código anota que deveria virar um objeto de valor |
| PM-13 | `isInAnyParty` olha todas as festas, inclusive as que não aceitam mais itens | o ✓ do card aparece mesmo quando o anúncio só está em uma festa com o orçamento solicitado |
| PM-14 | A festa consulta o catálogo uma vez por anúncio para listar os parceiros | uma festa com dezenas de anúncios faz dezenas de chamadas ao abrir |
| PM-15 | Festas e pedidos limitados a 100, sem paginação | conta com mais de 100 festas (é também o teto de criação) ou fornecedor com mais de 100 pedidos |
| PM-16 | A ordenação "menor preço" compara o número anunciado, seja ele por pessoa, por hora ou fixo | [catalog](../../02-domain/catalog.md) |
| PM-17 | Um item antigo, gravado antes das regras de configuração, só é validado quando a pessoa o altera | de propósito: uma festa antiga continua abrindo. Mas ela pode pedir o orçamento com um salão sem duração |
| PM-18 | O rótulo de um campo não quebra de linha (limite do componente do Material). `test/app/field_text_fit_test.dart` confere que nenhum é cortado em um celular de 360 pontos com a fonte no tamanho normal; com a fonte do sistema grande, um rótulo comprido pode ser cortado | quem usa letras grandes. O erro e a ajuda quebram em até três linhas, e é neles que fica o que importa |

## Resolvidos (para não reaparecerem)

| O quê | Como foi resolvido | Commit |
|---|---|---|
| O orçamento solicitado não chegava a nenhum fornecedor | cada item vai para o fornecedor dele, que responde por uma caixa de pedidos | `cab63f3`, `b137669` |
| Sem tela para data e número de convidados | tela dos dados do evento, e os mesmos campos dentro da configuração do salão | `b137669` |
| Sem como renomear, cancelar ou apagar a festa | menu da festa | `b137669` |
| A quantidade não podia ser editada | faz parte da configuração, nas categorias em que faz sentido | `b137669` |
| Um anúncio sob consulta entraria na festa como "R$ 0,00" | `Pricing` sem valor nunca vira número; a estimativa diz quantos itens ficaram de fora | `144c0f5`, `b137669` |
| A tela não avisava que o anúncio de um item saiu do catálogo | o item diz, e é uma pendência para pedir o orçamento | `b137669` |
| `Party` usava `DateTime.now()` direto | recebe um relógio (`Clock`) | `b137669` |
| App e API tinham limites diferentes (título, quantidade, convidados) | os objetos de valor do app têm os mesmos limites | `b137669` |
| A data e o horário do evento não podiam ser acionados por um leitor de tela: eram campos de texto só de leitura, e o Flutter não publica ação nenhuma deles | `PickerFormField`: um botão com cara de campo | `8802ba8` |
| O erro de um campo continuava na tela depois de o campo ser corrigido, até a tentativa seguinte | depois da primeira tentativa com erro, o formulário confere de novo a cada mudança | `8802ba8` |
| O erro e a ajuda de um campo eram cortados com reticências quando não cabiam em uma linha | o tema deixa quebrar em até três linhas (`errorMaxLines`, `helperMaxLines`), no app inteiro | `8802ba8` |
| No diálogo de valor do fornecedor, o rótulo "Mensagem para o cliente (opcional)" aparecia cortado | rótulo curto, e o resto na ajuda | `8802ba8` |
| Adicionar um parceiro de dentro da festa oferecia "Ver festa" com a pessoa já na festa | o aviso só confirma | `8802ba8` |
| Os diálogos de aceitar e de cancelar diziam que os fornecedores "ficam sabendo" | dizem que aparece na lista de pedidos deles: o app não avisa ninguém | `8802ba8` |
| Ids de item vinham do relógio e colidiam: remover um item removia dois | ids são UUID v4 aleatórios (`IdGenerator`) | `42630a4` |
| O controller só funcionava com o repositório em memória | depende só do contrato `PartyRepository` | `42630a4` |
| O botão central não recebia toque na metade de cima | passou a ocupar o lugar do botão flutuante do `Scaffold` | `790377a` |
| Mensagens de regra com termos internos ("Party está Locked") | reescritas para a tela em `party_domain_exceptions.dart` | `790377a` |
| O rodapé da montagem ficava embaixo do botão central | folga de `AppSpacing.navButtonOverlap` | `790377a` |
