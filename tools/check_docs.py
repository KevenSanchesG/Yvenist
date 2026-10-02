#!/usr/bin/env python3
"""Confere a Knowledge Base do Yvenist (a pasta ``docs/``).

Uso, da raiz do repositório::

    python tools/check_docs.py            # confere; sai com 1 se achar problema
    python tools/check_docs.py --stats    # também mostra o tamanho de cada camada

O que é conferido:

1. todo documento tem cabeçalho com ``title``, ``type`` e ``updated`` ou ``date``;
2. todo link relativo aponta para um arquivo que existe (e a âncora, para um
   título que existe);
3. todo documento é alcançável a partir do índice central;
4. os caminhos do repositório citados entre crases existem;
5. não há pasta vazia nem segredo escrito;
6. o ``CLAUDE.md`` não passa do tamanho recomendado.

Só usa a biblioteca padrão: roda em qualquer Python 3.9+, sem instalar nada.
"""

# ruff: noqa: T201  (ferramenta de linha de comando: o resultado é impresso)

from __future__ import annotations

import re
import sys
import unicodedata
from collections import deque
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
INDEX = DOCS / "00-project" / "memory-system.md"
TEMPLATES = DOCS / "templates"

# Fora do cofre, mas com as mesmas exigências de link, caminho citado e
# segredo: as instruções do Claude Code e os dois README.
INSTRUCTION_FILES = [
    ROOT / "CLAUDE.md",
    *sorted((ROOT / ".claude").rglob("*.md")),
    ROOT / "README.md",
    ROOT / "backend" / "README.md",
]

# A documentação do Claude Code recomenda menos de 200 linhas.
CLAUDE_MD_MAX_LINES = 200

REQUIRED_KEYS = ("title", "type")
DATE_KEYS = ("updated", "date")
# Os tipos de documento do cofre (docs/09-guides/obsidian.md).
DOCUMENT_TYPES = {
    "index",
    "project",
    "architecture",
    "domain",
    "feature",
    "ux",
    "adr",
    "research",
    "known-issues",
    "changelog",
    "guide",
    "meeting",
}
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

LINK = re.compile(r"!?\[[^\]\n]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HEADING = re.compile(r"^#{1,6}\s+(.+?)\s*#*\s*$")
CODE_SPAN = re.compile(r"`([^`\n]+)`")
FENCE = re.compile(r"^\s*(```|~~~)")

# Só caminhos que começam em uma pasta conhecida da raiz são conferidos: nos
# documentos há muitos nomes abreviados (``parties/domain.py``), que são
# pontos de partida para uma busca e não caminhos completos.
REPO_PREFIXES = (
    "lib/",
    "test/",
    "backend/",
    "docs/",
    "assets/",
    "android/",
    "ios/",
    "macos/",
    "linux/",
    "windows/",
    "web/",
    "tools/",
    "deploy/",
    ".github/",
    ".claude/",
)
ROOT_FILES = {
    "CLAUDE.md",
    "README.md",
    "pubspec.yaml",
    "dart_test.yaml",
    "docker-compose.yml",
    "analysis_options.yaml",
    ".gitignore",
    ".gitattributes",
}
# Marcas de que o texto entre crases é um padrão ou um exemplo, não um caminho.
NOT_A_LITERAL_PATH = re.compile(r"[<>*{}…\s$|]|\.\.\.")

# Citados de propósito sem existir no repositório: arquivos que ficam só na
# máquina de quem publica ou no servidor (estão no .gitignore).
EXPECTED_ABSENT = {"android/key.properties", "deploy/.env"}

# O changelog é história: cita os caminhos como eram no dia.
CHANGELOG = DOCS / "08-changelog"

# Formatos de segredo com alta certeza. Texto corrido sobre "senha" ou "token"
# não casa; um valor de verdade, sim.
SECRETS = {
    "chave privada": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "token do GitHub": re.compile(
        r"\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}\b|\bgithub_pat_[A-Za-z0-9_]{30,}\b"
    ),
    "chave da AWS": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "chave de API do Google": re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    "token do Slack": re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b"),
    "JWT": re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
    "valor atribuído a um segredo": re.compile(
        r"(?i)\b(secret|token|password|passwd|senha|api[_-]?key)\b\s*[:=]\s*[\"']?"
        r"(?!<)[A-Za-z0-9+/_\-]{20,}"
    ),
}


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def split_front_matter(text: str) -> tuple[dict[str, str], str]:
    """Separa o cabeçalho (``chave: valor`` simples) do corpo."""
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text
    fields: dict[str, str] = {}
    for line in text[4:end].splitlines():
        key, separator, value = line.partition(":")
        if separator and not line.startswith((" ", "\t", "-")):
            fields[key.strip()] = value.strip().strip("\"'")
    return fields, text[end + 5 :]


def without_code_blocks(body: str) -> list[str]:
    """As linhas do documento, sem o que está dentro de blocos de código."""
    lines: list[str] = []
    in_block = False
    for line in body.splitlines():
        if FENCE.match(line):
            in_block = not in_block
            continue
        if not in_block:
            lines.append(line)
    return lines


def slug(heading: str) -> str:
    """Âncora de um título, como o GitHub a gera."""
    text = re.sub(r"`|\*|_", "", heading.strip().lower())
    text = "".join(
        char
        for char in text
        if char.isalnum() or char in " -" or unicodedata.category(char) == "Mn"
    )
    return text.replace(" ", "-")


def headings_of(path: Path) -> set[str]:
    _, body = split_front_matter(path.read_text(encoding="utf-8"))
    return {
        slug(match.group(1)) for line in without_code_blocks(body) if (match := HEADING.match(line))
    }


def links_of(lines: list[str]) -> list[str]:
    found: list[str] = []
    for line in lines:
        # Um link dentro de crases é um exemplo de sintaxe, não um link.
        found.extend(LINK.findall(CODE_SPAN.sub("", line)))
    return found


def is_external(target: str) -> bool:
    return bool(re.match(r"^[a-z][a-z0-9+.-]*:", target)) or target.startswith("//")


def check_file(path: Path, problems: list[str], graph: dict[Path, set[Path]]) -> None:
    text = path.read_text(encoding="utf-8")
    name = relative(path)
    fields, body = split_front_matter(text)
    lines = without_code_blocks(body)
    is_template = TEMPLATES in path.parents
    in_docs = DOCS in path.parents

    if in_docs:
        for key in REQUIRED_KEYS:
            if not fields.get(key):
                problems.append(f"{name}: cabeçalho sem '{key}'")
        if fields.get("type") and fields["type"] not in DOCUMENT_TYPES:
            problems.append(f"{name}: tipo desconhecido '{fields['type']}'")
        dates = [fields[key] for key in DATE_KEYS if key in fields]
        if not dates:
            problems.append(f"{name}: cabeçalho sem 'updated' nem 'date'")
        elif not is_template and not all(DATE.match(value) for value in dates):
            problems.append(f"{name}: data fora do formato AAAA-MM-DD")

    targets: set[Path] = set()
    for target in links_of(lines):
        if is_external(target):
            continue
        file_part, _, anchor = target.partition("#")
        destination = (path.parent / unquote(file_part)).resolve() if file_part else path
        if not destination.exists():
            problems.append(f"{name}: link quebrado -> {target}")
            continue
        if destination.suffix == ".md":
            targets.add(destination)
            if anchor and slug(unquote(anchor)) not in headings_of(destination):
                problems.append(f"{name}: âncora inexistente -> {target}")
    graph[path] = targets

    if not is_template and CHANGELOG not in path.parents:
        for line in lines:
            for span in CODE_SPAN.findall(line):
                candidate = span.split("::")[0].rstrip(".,;:")
                if NOT_A_LITERAL_PATH.search(candidate) or candidate in EXPECTED_ABSENT:
                    continue
                looks_like_path = candidate.startswith(REPO_PREFIXES) or candidate in ROOT_FILES
                if looks_like_path and not (ROOT / candidate).exists():
                    problems.append(f"{name}: caminho citado não existe -> {candidate}")

    for label, pattern in SECRETS.items():
        if pattern.search(text):
            problems.append(f"{name}: parece conter um segredo ({label})")


def check_reachability(graph: dict[Path, set[Path]], problems: list[str]) -> None:
    """Todo documento do cofre tem de ser alcançável a partir do índice."""
    if not INDEX.exists():
        problems.append(f"índice central ausente: {relative(INDEX)}")
        return
    seen = {INDEX}
    queue = deque([INDEX])
    while queue:
        for target in graph.get(queue.popleft(), ()):
            if target not in seen:
                seen.add(target)
                queue.append(target)
    for path in sorted(graph):
        # Os modelos são alcançados pelo plugin de modelos do Obsidian; a
        # porta de entrada do cofre (docs/README.md) aponta para o índice.
        unlisted_ok = TEMPLATES in path.parents or path == DOCS / "README.md"
        if DOCS in path.parents and path not in seen and not unlisted_ok:
            problems.append(f"{relative(path)}: não é alcançável a partir do índice")


def check_empty_folders(problems: list[str]) -> None:
    for folder in sorted(p for p in DOCS.rglob("*") if p.is_dir()):
        if ".obsidian" in folder.parts:
            continue
        if not any(folder.iterdir()):
            problems.append(f"{relative(folder)}: pasta vazia")


def print_stats(documents: list[Path]) -> None:
    def size(paths: list[Path]) -> tuple[int, int]:
        texts = [p.read_text(encoding="utf-8") for p in paths if p.exists()]
        return sum(t.count("\n") + 1 for t in texts), sum(len(t.encode("utf-8")) for t in texts)

    rules = sorted((ROOT / ".claude" / "rules").glob("*.md"))
    skills = sorted((ROOT / ".claude" / "skills").rglob("SKILL.md"))
    layers = [
        ("CLAUDE.md (sempre carregado)", [ROOT / "CLAUDE.md"]),
        ("índice central (lido no início)", [INDEX]),
        ("regras por área (sob demanda)", rules),
        ("skills (corpo só ao invocar)", skills),
        ("Knowledge Base inteira", documents),
    ]
    print("\nTamanho de cada camada (bytes / 4 ≈ tokens):")
    for label, paths in layers:
        lines, size_bytes = size(paths)
        print(
            f"  {label:<36} {len(paths):>3} arq  {lines:>6} linhas"
            f"  {size_bytes:>8} bytes  ~{size_bytes // 4:>6} tokens"
        )
    largest = sorted(documents, key=lambda p: p.stat().st_size, reverse=True)[:5]
    print("  Maiores documentos:")
    for path in largest:
        print(f"    {path.stat().st_size:>7} bytes  {relative(path)}")


def main() -> int:
    if not DOCS.is_dir():
        print(f"pasta não encontrada: {DOCS}", file=sys.stderr)
        return 2

    documents = sorted(DOCS.rglob("*.md"))
    instruction_files = [p for p in INSTRUCTION_FILES if p.exists()]
    problems: list[str] = []
    graph: dict[Path, set[Path]] = {}

    for path in [*documents, *instruction_files]:
        check_file(path, problems, graph)
    check_reachability(graph, problems)
    check_empty_folders(problems)

    claude_md = ROOT / "CLAUDE.md"
    if claude_md.exists():
        lines = claude_md.read_text(encoding="utf-8").count("\n") + 1
        if lines > CLAUDE_MD_MAX_LINES:
            problems.append(f"CLAUDE.md: {lines} linhas (recomendado: até {CLAUDE_MD_MAX_LINES})")
    else:
        problems.append("CLAUDE.md ausente na raiz do repositório")

    if "--stats" in sys.argv[1:]:
        print_stats(documents)

    if problems:
        print(f"\n{len(problems)} problema(s) na Knowledge Base:\n")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print(
        f"Knowledge Base íntegra: {len(documents)} documentos; "
        f"{len(instruction_files)} arquivos de fora do cofre conferidos."
    )
    return 0


if __name__ == "__main__":
    # No Windows o console pode não estar em UTF-8.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    sys.exit(main())
