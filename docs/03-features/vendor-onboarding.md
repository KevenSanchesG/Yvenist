---
title: Cadastro de salão (fornecedor)
type: feature
updated: 2026-10-02
---

# Cadastro de salão (fornecedor)

Regras: [vendors-and-review](../02-domain/vendors-and-review.md).

## Fluxo

1. Perfil → banner "Tem um salão ou serviço?" → tela de convite
   (`vendor_welcome_page.dart`) → "Começar meu anúncio".
2. "O que você vai anunciar?" (`ad_category_selection_page.dart`): só **Salão
   de Festas** abre o formulário; Brinquedos e Atrações, Buffet e Bar e
   Decoração aparecem como "Em breve".
3. Formulário em seis etapas (`hall_creation_flow_page.dart`):

   | Etapa | Campos |
   |---|---|
   | 1. Responsável | pessoa física ou jurídica, CPF/CNPJ, nome completo ou razão social |
   | 2. O salão | nome, descrição (mínimo 20 caracteres), área, capacidade, bairro, cidade, UF |
   | 3. Eventos | tipos de evento atendidos (ao menos um) |
   | 4. Estrutura | comodidades (opcional) |
   | 5. Preço | "a partir de" e política de cancelamento (flexível ou moderada) |
   | 6. Revisão | resumo de tudo antes de enviar |

4. Enviar leva ao perfil, com o banner "Análise em andamento".

Cada etapa só avança depois de validada, e nada é enviado antes da revisão.
Sair no meio, com algo preenchido, pede confirmação.

![Convite](../screenshots/fornecedor-convite.png) ![Validação](../screenshots/fornecedor-validacao.png)

## O banner do perfil

| Situação do cadastro | Banner | Ação |
|---|---|---|
| nenhum | "Tem um salão ou serviço?" | abre o convite |
| em análise | "Análise em andamento" | só no modo demonstração: "Simular aprovação (demo)" |
| recusado | "Cadastro não aprovado" + o motivo | "Corrigir e reenviar" (refaz o formulário) |
| aprovado | "Você é um fornecedor!" | abre o Modo Fornecedor |

## Depois de aprovado

O seletor do perfil libera o **Modo Fornecedor**: contadores de anúncios
(enviados, publicados, em análise) e "Anunciar outro espaço". "Meus Anúncios",
"Agenda e Disponibilidade", "Extrato e Saques" e "Dados Bancários" são "Em
breve". Tocar no modo fornecedor sem estar aprovado mostra o aviso "O modo
fornecedor fica disponível depois que o seu anúncio é aprovado."

## Comportamentos que valem conhecer

- CPF e CNPJ são validados no app pelos dígitos verificadores, e de novo no
  servidor. O CNPJ alfanumérico (em vigor desde julho de 2026) é aceito.
- O preço aceita "2500", "2.500,00" e "2500.50" (`parseBrlToCents`); o teto é
  R$ 1 milhão.
- O documento nunca volta inteiro para o app: o perfil guarda
  `documentMasked`.
- Se a consulta do cadastro falhar, a conta é tratada como não fornecedora e o
  modo fornecedor não é liberado.

## Testes

`test/features/vendor/vendor_test.dart`, `test/app/vendor_flow_test.dart`, e os
cenários de fornecedor em `test/integration/`.

## O que não existe

Fotos (o campo de capa existe na API, o formulário não o pede), edição ou
remoção de anúncio, formulário para outras categorias, agenda, financeiro.
