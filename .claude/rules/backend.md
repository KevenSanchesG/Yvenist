---
paths:
  - "backend/**/*.py"
---

# API (FastAPI)

Contexto completo: `docs/01-architecture/backend.md`. Rodar e configurar:
`backend/README.md`.

- Cada módulo: `router.py` (HTTP) → `service.py` (caso de uso e transação) →
  `models.py`; `schemas.py` é o contrato. Rota não fala com o banco; serviço
  não conhece HTTP. Regra de negócio de verdade fica em um `domain.py` puro.
- SQLAlchemy **síncrono**. Relações com `lazy="raise"`: carregue com
  `selectinload` o que a resposta usa.
- Erro de negócio é uma subclasse de `app.core.errors` com `code` estável e
  `message` em português para o usuário. Nunca devolva o valor enviado.
- O servidor é a autoridade: valide tudo de novo e nunca confie em preço,
  status ou dono vindos do cliente.
- Toda consulta de dado de uma conta filtra pelo dono; o que é de outra conta
  responde 404.
- Onde "verificar e depois gravar" não basta, garanta no banco (índice único,
  `with_for_update`, versão) e traduza a violação para 409. Nunca 500.
- Dinheiro em centavos inteiros; datas em UTC (`UTCDateTime`, `utcnow`).
- Configuração só por `Settings` (`YVENIST_*`). Nada de segredo no código.
- Log sem corpo, cabeçalho, query string ou dado pessoal.
- A suíte trata avisos como erro: API depreciada de uma biblioteca falha o
  teste.
- Antes de concluir: `ruff check .`, `ruff format --check .`,
  `mypy app tests`, `pytest -q`. Testes de concorrência só rodam em
  PostgreSQL (no CI).
