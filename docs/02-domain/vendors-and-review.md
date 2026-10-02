---
title: Fornecedores e análise
type: domain
updated: 2026-10-02
---

# Fornecedores e análise

App: `lib/features/vendor`, `lib/features/admin`. API: `modules/vendors`.
Telas: [vendor-onboarding](../03-features/vendor-onboarding.md) e
[admin-review](../03-features/admin-review.md).

## Entidades

| Entidade | Campos que importam |
|---|---|
| Cadastro de fornecedor (`VendorProfile`) | um por conta; pessoa física ou jurídica; CPF/CNPJ; nome ou razão social; situação; motivo da recusa; quem analisou e quando |
| Anúncio próprio (`VendorListing`) | o anúncio em qualquer situação, com o motivo da recusa |
| Item da fila (`VendorReview`, `ListingReview`) | o que a análise precisa: documento completo; no anúncio, de quem ele é e a situação desse fornecedor |

## Ciclo

```
Cadastro:  (nenhum) ──envia──▶ em análise ──aprova──▶ aprovado
                                   │  ▲
                                 recusa │ corrige e reenvia
                                   ▼  │
                                 recusado

Anúncio:   em análise ──publica──▶ publicado
               └───────recusa───▶ recusado
```

## Regras

| Regra | Garantida em |
|---|---|
| O primeiro envio leva os dados do fornecedor **e** um anúncio, numa transação só | `VendorService.submit_onboarding` |
| CPF e CNPJ são validados pelos dígitos verificadores; CNPJ aceita o formato alfanumérico | `core/documents.py`, `brazilian_documents.dart` |
| Um documento pertence a um único cadastro | índice único em `vendor_profiles.document` |
| Todo anúncio novo passa por análise, mesmo de fornecedor já aprovado | `_create_listing` |
| Anúncio só é publicado se o fornecedor estiver aprovado | `approve_listing` → 409 `vendor_not_approved` |
| Aprovar um cadastro pode publicar junto os anúncios dele que aguardam | `publish_pending_listings` (padrão: sim) |
| Recusar exige um motivo de 5 a 500 caracteres, que o fornecedor lê | `RejectRequest` |
| Recusar um cadastro recusa junto **todos** os anúncios que aguardavam com ele, com o mesmo motivo. Só os que aguardam: um anúncio já recusado antes mantém o motivo dele, e os de outros fornecedores não mudam. Regra confirmada pelos donos | `reject_vendor` ([ADR-010](../05-decisions/ADR-010-fila-de-analise.md)); `backend/tests/test_vendors.py` |
| Cadastro recusado pode ser corrigido e volta para a fila; o reenvio cria um anúncio novo | `_resubmit_profile` |
| Uma decisão não pode ser tomada duas vezes | 409 `already_reviewed`, com trava de linha |
| O documento completo só sai para administradores | `AdminVendorResponse`; os demais recebem `document_masked` |
| Só administrador acessa `/admin/*` | `get_admin_user` em `api/deps.py` |

## Modo fornecedor no app

Aparece na aba Perfil quando `VendorController.isApproved`. Hoje mostra só
contadores (anúncios enviados, publicados, em análise) e "Anunciar outro
espaço"; o resto é "Em breve".

## Modo demonstração

`InMemoryVendorRepository` guarda o cadastro por conta e implementa
`DemoVendorApproval`: como não há administrador, o perfil oferece "Simular
aprovação (demo)". Esse botão **não existe** quando o app fala com a API.
`InMemoryReviewRepository` segue as mesmas regras da fila, mas começa vazio e a
conta de demonstração não é administradora.

## Limites conhecidos

- A data do cadastro mostrada na fila é a do **primeiro** envio, mesmo depois de
  um reenvio (`created_at`).
- Não há como editar ou arquivar um anúncio, nem despublicar.
- Só o salão tem formulário no app; a API aceita qualquer categoria.

Lista completa: [problemas conhecidos](../07-known-issues/README.md).
