---
title: Party Maker — problemas e limites conhecidos
type: feature
tags: [party-maker]
updated: 2026-10-02
---

# Party Maker — problemas e limites conhecidos

Só o que é do Party Maker. O resto do projeto está na
[lista geral](../../07-known-issues/README.md).

## Lacunas de produto

| # | O quê | Efeito |
|---|---|---|
| PM-1 | O orçamento solicitado não chega a nenhum fornecedor | a pessoa trava a festa e nada acontece do outro lado. A tela de pagamentos diz que o combinado é direto com o fornecedor, mas o app não oferece o contato |
| PM-2 | Sem tela para data e número de convidados | os campos existem no domínio e na API e ficam sempre vazios |
| PM-3 | Sem como renomear, cancelar ou apagar a festa inteira | para apagar é preciso tirar os itens um a um; os casos de uso `RenamePartyTitleUseCase` e `CancelPartyUseCase` não são chamados por ninguém |
| PM-4 | A quantidade não pode ser editada | a tela sempre adiciona 1; para ter 2 é preciso adicionar o mesmo anúncio de novo |
| PM-5 | O orçamento registrado (linhas e data) não é mostrado | a tela mostra só o total ao vivo |
| PM-6 | `paid` é inalcançável | não há pagamento; `confirmPayment` e `CancellationResult` não têm uso |
| PM-7 | `expires_at` do orçamento nunca é preenchido | não há regra de validade |
| PM-8 | Não há página de detalhe do anúncio | a pessoa decide colocar na festa só pelo card |

## Limites técnicos

| # | O quê | Quando incomoda |
|---|---|---|
| PM-9 | As regras estão duplicadas no app (`Party`) e na API (`reconcile`), em linguagens diferentes, e são mantidas em sincronia à mão | toda vez que uma regra muda. Os testes dos dois lados e os de integração são a rede |
| PM-10 | App e API têm limites diferentes (título, quantidade, convidados) | quando a API recusa algo que o app aceitou; hoje só o título longo é alcançável pela tela |
| PM-11 | `Party` usa `DateTime.now()` direto | testes não controlam `updatedAt` e `generatedAt` |
| PM-12 | `ownerId` é uma `String` simples | o próprio código anota que deveria virar um objeto de valor |
| PM-13 | `isInAnyParty` olha todas as festas, inclusive travadas | o ✓ do card aparece mesmo quando o anúncio só está em uma festa que não aceita mais itens |
| PM-14 | Item cujo anúncio foi apagado continua na festa | é o comportamento desejado (a pessoa não perde o planejamento), mas a tela não avisa que o anúncio não existe mais |
| PM-15 | Lista limitada a 100 festas, sem paginação | conta com mais de 100 festas (hoje é também o teto de criação) |

## Resolvidos (para não reaparecerem)

| O quê | Como foi resolvido | Commit |
|---|---|---|
| Ids de item vinham do relógio e colidiam: remover um item removia dois | ids são UUID v4 aleatórios (`IdGenerator`) | `42630a4` |
| Remover o último item avisava falha e deixava na tela a festa já apagada | o caso de uso devolve `null` quando a festa deixou de existir | `42630a4` |
| O controller só funcionava com o repositório em memória | depende só do contrato `PartyRepository` | `42630a4` |
| O botão central não recebia toque na metade de cima | passou a ocupar o lugar do botão flutuante do `Scaffold` | `790377a` |
| Mensagens de regra com termos internos ("Party está Locked") | reescritas para a tela em `party_domain_exceptions.dart` | `790377a` |
| O rodapé da montagem ficava embaixo do botão central | folga de `AppSpacing.navButtonOverlap` | `790377a` |
