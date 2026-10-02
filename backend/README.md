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
PostgreSQL, aplica as migrações e inicia a API na porta 8000. Atenção: a imagem
e o compose **nunca foram executados** na máquina em que o projeto foi escrito
(não havia Docker nela). Quem os constrói e testa é o job `docker` do CI; se
ele falhar na primeira execução, é ali que está o ajuste a fazer.

### Windows com Controle Inteligente de Aplicativos

Se o import do SQLAlchemy ou do mypy falhar com *"Uma política de Controle de
Aplicativo bloqueou este arquivo"*, o Windows está barrando as extensões
compiladas desses pacotes. Os dois publicam uma versão em Python puro; instale-a
por cima, sem desligar a proteção:

```powershell
pip download --no-deps --only-binary=:all: --platform any --implementation py --abi none sqlalchemy==2.1.2 mypy==2.4.0 -d wheels
pip install --force-reinstall --no-deps (Get-ChildItem wheels\*.whl).FullName
```

O driver `psycopg[binary]` pode sofrer o mesmo bloqueio; nesse caso use SQLite
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
| `YVENIST_RATE_LIMIT_ENABLED` | `true` | Só desligue em testes |
| `YVENIST_DB_POOL_SIZE` / `YVENIST_DB_MAX_OVERFLOW` | `10` / `20` | Conexões com o PostgreSQL por processo |
| `YVENIST_LOG_LEVEL` | `INFO` | Nível dos logs |
| `YVENIST_PASSWORD_HASH_PROFILE` | `recommended` | `test` usa um hash barato, só para a suíte; recusado em produção |

Com `YVENIST_ENV=production` a aplicação **se recusa a subir** se o segredo JWT
for o de desenvolvimento ou curto, se o CORS aceitar `*` ou se o perfil de hash
de senha for o de testes.

## Comandos

```bash
pytest                     # 339 testes (SQLite em memória)
ruff check . && ruff format --check .
mypy app tests             # app em modo estrito

alembic upgrade head       # aplica migrações
alembic revision --autogenerate -m "descricao"   # nova migração a partir dos modelos

python -m app.cli create-admin --email voce@seudominio.com  # cria/promove administrador
python -m app.cli seed-demo                                # dados de demonstração
python -m app.cli purge-tokens --older-than-days 30        # limpa sessões antigas
```

`create-admin` pede a senha sem mostrá-la (ou lê de `YVENIST_ADMIN_PASSWORD`,
para uso automatizado). O e-mail e a senha passam pelas mesmas regras do
cadastro pelo app: um endereço que o login recusaria, ou uma senha muito comum,
não são aceitos.

### Testes no PostgreSQL

Por padrão a suíte usa SQLite em memória. Para rodá-la no banco de produção (é
o que o CI faz), aponte para um banco **vazio e descartável**: os testes apagam
e recriam as tabelas.

```bash
YVENIST_TEST_DATABASE_URL=postgresql+psycopg://user:senha@localhost/yvenist_test pytest
```

Nesse modo rodam também os testes que só fazem sentido em um banco de verdade:

- `tests/test_concurrency.py`: requisições realmente simultâneas (dois cadastros
  com o mesmo e-mail, o mesmo token de renovação usado em paralelo, dois
  aparelhos gravando a mesma festa...). No SQLite eles são pulados.
- `tests/test_migrations.py` aplica as migrações no próprio PostgreSQL e
  confere que o resultado é idêntico ao que os modelos descrevem.

Conferido em PostgreSQL 17.11 com `psycopg` 3.3.

### Testes de integração com o app

O app tem testes que exercitam o código dele contra esta API no ar (veja
`test/integration` na raiz do repositório). Para servi-los localmente:

```bash
YVENIST_RATE_LIMIT_ENABLED=false YVENIST_PASSWORD_HASH_PROFILE=test \
  uvicorn app.main:get_app --factory
```

O limite de requisições fica desligado porque os testes criam dezenas de contas
em sequência; nunca use essas duas variáveis em produção (a segunda nem é
aceita com `YVENIST_ENV=production`).

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
  português para o usuário. Erros de validação trazem também
  `details.fields`, com a mensagem de cada campo, também em português (a
  tradução dos erros do Pydantic fica em `app/core/errors.py`).
- **Senhas**: Argon2id, mínimo de 8 caracteres e recusa das senhas mais comuns
  (`app/modules/accounts/passwords.py`), sem regras de composição, como
  recomenda o NIST SP 800-63B.
- **Concorrência**: onde "verificar e depois gravar" não basta, quem decide é o
  banco (índices únicos, trava de linha, versão da festa). A violação vira 409,
  nunca 500.
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
