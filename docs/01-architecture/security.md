---
title: Segurança e dados pessoais
type: architecture
updated: 2026-10-02
---

# Segurança e dados pessoais

| Tema | Como está | Onde |
|---|---|---|
| Senhas | Argon2id; mínimo de 8 caracteres; lista de senhas comuns; tempo de resposta igual para e-mail existente ou não | `accounts/service.py`, `accounts/passwords.py` |
| Sessão | tokens no cofre do sistema; rotação com detecção de reuso; logout invalida no servidor | `token_storage.dart`, `accounts/service.py` |
| Transporte | release exige `https`; `http` só em debug e para o próprio aparelho | `app_config.dart`, `android/app/src/debug/AndroidManifest.xml` |
| Autorização | toda consulta filtra pelo dono: a festa de outra pessoa "não existe" (404); rotas `/admin` exigem administrador | `parties/service.py`, `api/deps.py` |
| Entrada | validada no servidor (Pydantic); o app valida antes só para dar retorno rápido | `schemas.py` de cada módulo |
| Preços | sempre copiados do catálogo pelo servidor | `parties/domain.py` |
| Força bruta | limite por IP em login e cadastro, em memória | `core/rate_limit.py` |
| Logs | id, método, caminho, status e duração; sem corpo, query string ou cabeçalhos | `core/logging.py` |
| Produção | a API se recusa a subir com segredo de desenvolvimento, CORS `*` ou hash de teste | `core/config.py` |
| CORS | desligado por padrão; só as origens de `YVENIST_CORS_ORIGINS`; sem cookies; expõe `Retry-After` e `X-Request-ID` | `main.py` |
| Android | backup do Google desligado; sem tráfego em claro fora do debug | `AndroidManifest.xml` |
| Contêiner | o processo roda como usuário sem privilégios (uid 10001) | `backend/Dockerfile` |

## Dados pessoais (LGPD)

- O que é guardado está descrito, tabela por tabela, na Política de Privacidade
  preliminar (`assets/legal/politica-de-privacidade.md`), escrita a partir dos
  modelos. Mudou o que é coletado → mude o texto ([legal](../03-features/legal.md)).
- CPF/CNPJ: a conta dona vê mascarado (`document_masked`); só a fila de análise
  recebe o número completo (`AdminVendorResponse`).
- A pessoa corrige os próprios dados (`PATCH /users/me`) e apaga a conta
  (`POST /users/me/delete`, com a senha).
- O aceite dos termos fica registrado com versão e data.
- O endereço IP só existe na memória do limitador, por cerca de um minuto.

## Regras para quem mexe no projeto

- Nunca escrever senha, chave, token ou segredo em código, teste, documento ou
  mensagem de commit. Credenciais de teste são frases óbvias de teste, em banco
  descartável.
- `android/key.properties`, `*.jks` e `*.keystore` estão no `.gitignore` e não
  entram no repositório.
- Não registrar em log nem em documento o conteúdo de requisições reais.

Limites conhecidos de segurança (tokens da versão web, limitador com várias
instâncias, login só limitado por IP): [problemas conhecidos](../07-known-issues/README.md).
