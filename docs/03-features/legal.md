---
title: Termos de Uso e Política de Privacidade
type: feature
updated: 2026-10-02
---

# Termos de Uso e Política de Privacidade

## Situação

**Versão preliminar.** Os dois textos foram escritos a partir do que o código
faz (o que cada tabela guarda, o que a exclusão apaga, o que o "orçamento" é).
Não passaram por advogado. O que depende de uma decisão dos donos está entre
colchetes no próprio texto.

| Documento | Arquivo | Na tela |
|---|---|---|
| Termos de Uso | `assets/legal/termos-de-uso.md` | abre, com aviso de versão preliminar |
| Política de Privacidade | `assets/legal/politica-de-privacidade.md` | abre, com aviso |
| Contrato do Fornecedor | não existe | aparece como "Em elaboração"; as regras para fornecedores estão na seção 5 dos Termos |

![Termos](../screenshots/termos-de-uso.png)

## Onde aparece

- Perfil → Termos e Política (`legal_page.dart` → `legal_document_page.dart`).
- No cadastro: "Li e aceito os Termos de Uso e a Política de Privacidade", com
  link. Sem marcar, a conta não é criada.

## A versão

O cadastro grava qual versão a pessoa aceitou. São três lugares que precisam
dizer o mesmo, e um teste confere (`test/features/legal/legal_document_test.dart`):

| Lugar | Valor hoje |
|---|---|
| linha "Versão" de cada documento | `2026-10 (preliminar)` |
| `terms_version` em `backend/app/core/config.py` | `2026-10` |
| `users.terms_version` de cada conta | o que estava em vigor no cadastro |

Mudou o texto de forma relevante → mude a versão nos dois primeiros.

## Como o texto é mostrado

Os arquivos são Markdown simples, lidos por um leitor próprio e pequeno
(`parseLegalText` em `legal_document.dart`): só `#`, `##`, `- ` e parágrafos.
Sem pacote de Markdown. Outra marcação (negrito, link, tabela) apareceria crua
na tela.

## Pendências (dos donos)

Trechos entre colchetes nos textos:

- razão social e CNPJ do responsável pela plataforma;
- e-mail de contato e do encarregado de dados;
- idade mínima (o rascunho diz 18 anos);
- fornecedores de hospedagem e país;
- prazos de cópias de segurança;
- foro;
- se anunciar é mesmo gratuito;
- revisão por advogado da limitação de responsabilidade e das bases legais.

Enquanto houver um colchete, o texto tem de se dizer preliminar: um teste
falha se alguém tirar o "(preliminar)" sem resolver as lacunas.

## Antes de publicar na loja

A Play Store exige a política de privacidade em uma **URL pública**. Hoje ela
só existe dentro do app ([android-release](../09-guides/android-release.md)).

## Quando atualizar os textos

Sempre que o app passar a coletar, compartilhar ou guardar algo novo: campo
novo em `users`, um serviço de terceiros, envio de fotos, pagamentos,
notificações, análise de uso. A política descreve o código; se o código muda,
ela muda junto.
