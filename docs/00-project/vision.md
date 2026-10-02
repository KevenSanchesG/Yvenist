---
title: Visão do produto
type: project
updated: 2026-10-02
---

# Visão do produto

## O que é

Um marketplace de festas e eventos. Em vez de procurar salões um a um e pedir
orçamentos por mensagem, quem organiza encontra espaços e serviços, monta a
festa inteira em um lugar e gera um orçamento. Quem oferece um espaço ou
serviço se cadastra, passa por uma análise e tem o anúncio publicado.
(Descrição do `README.md`, escrita pelos donos do projeto.)

## Quem usa

| Papel | O que faz no app | Como o código identifica |
|---|---|---|
| Visitante | navega e busca sem conta; favoritar e montar festa pedem login | sessão ausente (`SessionController.user == null`) |
| Cliente | favorita, monta festas, solicita orçamento | qualquer conta |
| Fornecedor | envia o cadastro e o anúncio do salão; depois de aprovado ganha o "Modo Fornecedor" no perfil | conta com `vendor_profiles` aprovado |
| Administrador | aprova ou recusa cadastros e anúncios na fila de análise | `users.is_admin` (criado pela linha de comando) |

Uma conta pode ser cliente e fornecedora ao mesmo tempo: o perfil alterna
entre os dois modos.

## O que existe hoje

Cada item tem um documento em [03-features](../03-features/README.md).

- Vitrine, exploração por categoria e tipo de evento, busca por texto.
- Contas: criar, entrar, recuperar a sessão, editar dados, trocar senha, apagar.
- Favoritos por conta.
- Party Maker: montar a festa, total em tempo real, solicitar orçamento.
- Cadastro de salão em seis etapas, com CPF/CNPJ validado.
- Fila de análise para administradores.
- Termos de Uso e Política de Privacidade em versão preliminar.
- Tema claro e escuro, à escolha da pessoa (Perfil → Aparência).

## O que o app anuncia e ainda não faz

Aparecem como "Em breve", nunca como botão que não faz nada
([princípio](../01-architecture/principles.md)):

- pagamentos, histórico de pagamentos, extrato e dados bancários;
- chat entre cliente e fornecedor; notificações;
- avaliações escritas por usuários;
- endereços de eventos; central de ajuda;
- envio de fotos, agenda de disponibilidade, "Meus Anúncios";
- página de detalhe do anúncio;
- autenticação em dois fatores e a tela de dispositivos conectados;
- cadastro de fornecedor para categorias que não sejam salão.

## O que o "orçamento" é hoje

Solicitar orçamento trava a festa e registra uma estimativa calculada com os
preços "a partir de" dos anúncios. **Não avisa os fornecedores**: não existe
caixa de entrada de pedidos nem contato pelo app. Detalhes em
[Party Maker](../03-features/party-maker/README.md).

## Em aberto

- OPEN QUESTION: como o Yvenist ganha dinheiro. O app diz "Anuncie no Yvenist
  sem pagar nada por isso" (`profile_page.dart`), e não há cobrança em nenhum
  lugar do código.
- OPEN QUESTION: em que ordem as funções "Em breve" entram. Veja o
  [roadmap](roadmap.md).
- `[INFERÊNCIA]` O alvo principal é o celular (Android primeiro): todo o
  desenho é de tela de celular e a publicação preparada é a da Play Store. A
  versão web compila e funciona contra a API, mas não é tratada como produto.
