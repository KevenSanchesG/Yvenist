---
title: Princípios
type: architecture
updated: 2026-10-02
---

# Princípios

As regras que o código segue em todo lugar. Cada uma tem um exemplo que pode
ser aberto; quando a regra nasceu de uma decisão, o ADR está ao lado.

## Produto

1. **O que não existe aparece como "Em breve".** Nunca um botão que não faz
   nada, nem dado de exemplo fingindo ser do usuário. Item de menu sem `onTap`
   vira "Em breve" (`_MenuItem` em `profile_page.dart`).
2. **Texto para o usuário em português, sem termo técnico.** As mensagens das
   regras são escritas para a tela (`party_domain_exceptions.dart`).
3. **Marca e textos jurídicos são dos donos.** O código não escolhe tom de cor
   da marca nem dá por final um texto legal.

## Confiança

4. **O servidor é a autoridade.** O app valida para responder rápido; a API
   valida tudo de novo e copia nome e preço do catálogo, sem confiar no que o
   app mandou (`parties/domain.py`).
5. **Falhar fechado.** Na dúvida, não libera: status de fornecedor desconhecido
   é tratado como "em análise" (`vendor_api_mapping.dart`); se a consulta
   falha, a conta não é tratada como fornecedora (`VendorController.load`).
6. **Quem decide corrida é o banco.** Onde "verificar e depois gravar" não
   basta: índice único, trava de linha, versão. A violação vira 409, nunca 500
   ([ADR-006](../05-decisions/ADR-006-concorrencia-pelo-banco.md)).
7. **Segredo nunca no repositório, e produção recusa configuração insegura**
   (`Settings._validate_production`).
8. **Dado pessoal mínimo.** CPF/CNPJ só sai mascarado, exceto na fila de
   análise; logs sem corpo, cabeçalho nem query string (`core/logging.py`).

## Código

9. **Telas conhecem contratos, não implementações.** `CatalogRepository`, nunca
   `ApiCatalogRepository`. Só `app_dependencies.dart` conhece as duas
   ([ADR-001](../05-decisions/ADR-001-camadas-por-funcionalidade.md)).
10. **Clean Architecture como ferramenta.** Entidades, objetos de valor e casos
    de uso completos só onde há regra de verdade (o Party Maker). No resto, o
    domínio é o contrato e as entidades.
11. **Exceção não chega ao widget.** Controllers devolvem `bool` ou valor e
    guardam a falha; repositórios lançam `AppFailure`
    ([ADR-009](../05-decisions/ADR-009-erros-uniformes.md)).
12. **Todo dado assíncrono tem três estados na tela**: carregando, erro com
    "Tentar novamente" e conteúdo (`LoadState<T>`).
13. **Resposta atrasada não sobrescreve a nova.** Uma carga iniciada para outra
    conta é descartada (`if (userId != _userId) return`).
14. **Dinheiro em centavos inteiros; datas em UTC**
    ([ADR-007](../05-decisions/ADR-007-dinheiro-e-snapshots.md)).
15. **Identificadores em inglês; comentários e textos em português.** Comentário
    explica o porquê, não o que a linha faz.

## Qualidade

16. **Acessibilidade conferida por teste**: contraste dos pares de cor, área de
    toque de 48×48, rótulo para leitor de tela, fonte do sistema em 200%
    ([ADR-008](../05-decisions/ADR-008-acessibilidade-e-cores.md)).
17. **Defeito ganha um teste que o reproduz antes da correção.** Esses testes
    têm um comentário `Regressão:` dizendo o que acontecia.
18. **O que não foi verificado é dito.** Documento e relatório separam o que
    foi conferido (e onde) do que não foi.
