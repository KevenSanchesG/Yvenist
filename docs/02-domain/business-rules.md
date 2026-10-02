---
title: Regras de negócio — índice
type: domain
updated: 2026-10-02
---

# Regras de negócio — índice

As regras de cada assunto estão no documento dele. Aqui ficam só as que
atravessam mais de um assunto, e o caminho até as outras.

## Onde está cada conjunto

| Assunto | Regras em |
|---|---|
| Festas | [party-maker/business-rules](../03-features/party-maker/business-rules.md) |
| Contas e sessão | [accounts](accounts.md#regras) |
| Catálogo e favoritos | [catalog](catalog.md#regras) |
| Fornecedores e análise | [vendors-and-review](vendors-and-review.md#regras) |

## Regras que atravessam o sistema

| Regra | Garantida em |
|---|---|
| Cada conta só enxerga e altera o que é dela; o que é de outra conta responde 404, não 403 | filtro pelo dono em cada serviço (`parties/service.py::_find`) |
| Só anúncio publicado aparece na busca ou entra em uma festa | `catalog/service.py`, `parties/service.py::_lookup_listing` |
| Nome, categoria e preço de um item de festa vêm do catálogo, nunca do app | `parties/domain.py::reconcile` |
| Um item que já está na festa mantém o preço de quando entrou, mesmo que o anúncio mude | `party_items` guarda a cópia |
| Dinheiro é inteiro, em centavos, e uma festa tem uma moeda só | `Money`, `currency_mismatch` |
| Favoritar e montar festa exigem conta; navegar e buscar não | `ensureSignedIn`, guarda das abas em `app_shell.dart` |
| O que depende de análise nunca é liberado por engano | status desconhecido vira "em análise"; consulta que falha não libera o modo fornecedor |
| O aceite dos termos é registrado com a versão que estava em vigor | `users.terms_version` = `terms_version` de `core/config.py` = versão dos textos em `assets/legal/` |

## Como uma regra é registrada aqui

Uma linha, no documento do assunto, dizendo a regra em português e onde ela é
garantida (arquivo, índice do banco ou as duas coisas). Se a regra nasceu de
uma escolha entre alternativas, crie também um ADR. Se a mesma regra existe no
app e na API (é o caso das festas), cite os dois lugares: eles precisam mudar
juntos.
