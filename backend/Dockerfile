FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Dependências antes do código: esta camada só é refeita quando o lock muda.
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY alembic.ini ./
COPY migrations ./migrations
COPY app ./app

# O processo roda sem privilégios de root.
RUN useradd --system --uid 10001 --no-create-home yvenist
USER yvenist

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import sys, urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health/live', timeout=2).status == 200 else 1)"]

# Atrás de um proxy reverso, defina FORWARDED_ALLOW_IPS com o IP do proxy para
# que o limite de requisições enxergue o IP real do cliente: sem isso todos os
# clientes dividem o mesmo limite (docs/09-guides/deployment.md).
# --no-access-log: a aplicação já registra cada requisição (com o id dela e
# sem query string); o log de acesso do uvicorn só duplicaria as linhas.
CMD ["uvicorn", "app.main:get_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--no-access-log"]
