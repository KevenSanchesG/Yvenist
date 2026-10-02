# Yvenist API

API do Yvenist: contas, catálogo de anúncios, favoritos, festas e cadastro de
fornecedores. FastAPI + SQLAlchemy 2 + Alembic, com PostgreSQL em produção e
SQLite para desenvolver sem instalar nada.

## Rodando localmente

Pré-requisito: Python 3.12 ou mais novo (a suíte é executada no 3.14).

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows  (Linux/macOS: source .venv/bin/activate)
pip install -r requirements-dev.txt

alembic upgrade head            # cria o banco (SQLite em ./yvenist.db)
python -m app.cli seed-demo     # opcional: anúncios de demonstração
uvicorn app.main:get_app --factory --reload
```

A API fica em `http://127.0.0.1:8000` e a documentação interativa em
`http://127.0.0.1:8000/docs` (desligada em produção).

Com Docker, a partir da raiz do repositório: `docker compose up --build` sobe
PostgreSQL, aplica as migrações e inicia a API na porta 8000.

### Windows com Controle Inteligente de Aplicativos

Se o import do SQLAlchemy ou do mypy falhar com *"Uma política de Controle de
Aplicativo bloqueou este arquivo"*, o Windows está barrando as extensões
compiladas desses pacotes. Os dois publicam uma versão em Python puro; instale-a
por cima, sem desligar a proteção:

```powershell
pip download --no-deps --only-binary=:all: --platform any --implementation py --abi none sqlalchemy==2.1.2 mypy==2.4.0 -d wheels
pip install --force-reinstall --no-deps (Get-ChildItem wheels\*.whl).FullName
```

O driver `psycopg[binary]` sofre o mesmo bloqueio; nesse caso use SQLite
localmente e deixe o PostgreSQL para o Docker/CI.

## Configuração

Tudo por variáveis de ambiente com prefixo `YVENIST_` (ou arquivo `.env`; veja
`.env.example`).

| Variável | Padrão | Para que serve |
|---|---|---|
| `YVENIST_ENV` | `development` | `production` liga as travas de segurança abaixo |
| `YVENIST_DATABASE_URL` | `sqlite:///./yvenist.db` | Em produção: `postgresql+psycopg://...` |
| `YVENIST_JWT_SECRET` | segredo de desenvolvimento | Obrigatório em produção, 32+ caracteres |
| `YVENIST_ACCESS_TOKEN_TTL_MINUTES` | `15` | Validade do token de acesso |
| `YVENIST_REFRESH_TOKEN_TTL_DAYS` | `30` | Validade da sessão |
| `YVENIST_CORS_ORIGINS` | vazio | Origens do app web, separadas por vírgula |
| `YVENIST_DOCS_ENABLED` | ligado fora de produção | Força ligar/desligar `/docs` |
| `YVENIST_LOGIN_RATE_LIMIT_PER_MINUTE` | `10` | Tentativas de login por IP |
| `YVENIST_REGISTER_RATE_LIMIT_PER_MINUTE` | `5` | Cadastros por IP |

Com `YVENIST_ENV=production` a aplicação **se recusa a subir** se o segredo JWT
for o de desenvolvimento ou curto, se o CORS aceitar `*` ou se o perfil de hash
de senha for o de testes.

## Comandos

```bash
pytest                     # testes (SQLite em memória)
ruff check . && ruff format --check .
mypy app tests             # app em modo estrito

alembic upgrade head       # aplica migrações
alembic revision --autogenerate -m "descricao"   # nova migração a partir dos modelos

python -m app.cli create-admin --email voce@exemplo.com   # cria/promove administrador
python -m app.cli seed-demo                                # dados de demonstração
python -m app.cli purge-tokens --older-than-days 30        # limpa sessões antigas
```

Para rodar a suíte contra PostgreSQL (é o que o CI faz):

```bash
YVENIST_TEST_DATABASE_URL=postgresql+psycopg://user:senha@localhost/yvenist_test pytest
```

As dependências ficam travadas em `requirements.txt` e `requirements-dev.txt`.
Depois de mudar o `pyproject.toml`, regenere os dois:

```bash
uv pip compile pyproject.toml --universal --python-version 3.12 -o requirements.txt
uv pip compile pyproject.toml --extra dev --universal --python-version 3.12 -o requirements-dev.txt
```

## Estrutura

```
app/
  main.py            montagem da aplicação (create_app)
  cli.py             comandos de administração
  api/               dependências HTTP compartilhadas e agregação das rotas
  core/              configuração, banco, segurança, erros, paginação, logs
  modules/
    accounts/        cadastro, login, sessões, dados pessoais
    catalog/         categorias, tipos de evento, busca de anúncios
    favorites/       favoritos do usuário
    parties/         festas (regras em domain.py, sem banco nem HTTP)
    vendors/         cadastro de fornecedor, anúncios próprios, fila de análise
migrations/          migrações Alembic
tests/               testes (API, domínio, migrações, CLI)
```

Cada módulo segue o mesmo desenho: `router.py` (HTTP) → `service.py` (caso de
uso e transação) → `models.py` (tabelas). `schemas.py` são os contratos de
entrada e saída. Onde há regra de negócio de verdade (festas), ela fica em um
`domain.py` puro, testado sem banco.

## Decisões que vale conhecer

- **Erros** têm sempre o formato `{"error": {"code", "message", "request_id"}}`.
  `code` é estável para o app decidir o que fazer; `message` é o texto em
  português para o usuário.
- **Dinheiro** é sempre inteiro em centavos.
- **Autenticação**: token de acesso JWT curto + token de renovação opaco com
  rotação. Reutilizar um token de renovação já trocado derruba a sessão inteira.
  Trocar a senha invalida todos os tokens na hora.
- **Festas** são gravadas por estado (`PUT /parties/{id}` com o estado desejado).
  O servidor valida as transições, copia nome e preço do catálogo (nunca confia
  no preço enviado pelo cliente) e usa versão para detectar edições concorrentes.
- **Paginação** do catálogo é por cursor, não por `OFFSET`.
- **Busca** ignora acentos e maiúsculas usando uma coluna de texto normalizado.
- **Dados pessoais**: CPF/CNPJ só saem mascarados; a conta pode ser apagada pelo
  próprio usuário (`POST /users/me/delete`).
