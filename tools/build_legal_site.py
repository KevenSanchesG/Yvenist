#!/usr/bin/env python3
"""Gera as páginas públicas dos textos legais do Yvenist.

Uso, da raiz do repositório::

    python tools/build_legal_site.py                 # escreve em build/legal-site
    python tools/build_legal_site.py --out pasta     # ou na pasta indicada

A Play Store exige a política de privacidade e um caminho para pedir a
exclusão da conta em um **endereço público**. Os textos são os mesmos
arquivos que o app mostra (``assets/legal``), mais a página de exclusão de
conta, que só existe no site (``deploy/site``). Cada um vira uma página HTML
sozinha: sem script, sem fonte de fora, sem nenhuma chamada a terceiros.

Enquanto um texto tiver um trecho entre colchetes (uma decisão que falta), a
página dele mostra o aviso de versão preliminar, como o app faz.

Só usa a biblioteca padrão: roda em qualquer Python 3.9+, sem instalar nada.
"""

# ruff: noqa: T201  (ferramenta de linha de comando: o resultado é impresso)

from __future__ import annotations

import argparse
import html
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = ROOT / "build" / "legal-site"

SITE_NAME = "Yvenist"

# O mesmo aviso que o app mostra (``DraftNotice``, em
# lib/features/shared_features/legal/presentation/widgets/draft_notice.dart).
DRAFT_NOTICE = (
    "Versão preliminar: este texto ainda não passou por revisão jurídica e "
    "pode mudar antes do lançamento."
)

# Um trecho entre colchetes é uma decisão que ainda não foi tomada.
OPEN_POINT = re.compile(r"\[[^\]]+\]")


@dataclass(frozen=True)
class Page:
    source: Path
    """O Markdown de origem, a partir da raiz do repositório."""

    slug: str
    """O nome do arquivo gerado, sem a extensão: é o endereço da página."""


PAGES = (
    Page(Path("assets/legal/politica-de-privacidade.md"), "politica-de-privacidade"),
    Page(Path("assets/legal/termos-de-uso.md"), "termos-de-uso"),
    Page(Path("deploy/site/exclusao-de-conta.md"), "exclusao-de-conta"),
)


@dataclass(frozen=True)
class Block:
    kind: str  # "title", "heading", "bullet" ou "paragraph"
    text: str


def parse_legal_text(source: str) -> list[Block]:
    """Lê o Markdown simples dos documentos legais.

    O mesmo subconjunto que o app entende (``parseLegalText``, em
    ``legal_document.dart``): ``# título``, ``## seção``, ``- item`` e
    parágrafos separados por linha em branco. Os dois têm de concordar, senão
    o site e o app mostrariam o mesmo texto de jeitos diferentes.
    """
    blocks: list[Block] = []
    paragraph: list[str] = []

    def close_paragraph() -> None:
        if paragraph:
            blocks.append(Block("paragraph", " ".join(paragraph)))
            paragraph.clear()

    for raw_line in source.split("\n"):
        line = raw_line.strip()
        if not line:
            close_paragraph()
        elif line.startswith("## "):
            close_paragraph()
            blocks.append(Block("heading", line[3:].strip()))
        elif line.startswith("# "):
            close_paragraph()
            blocks.append(Block("title", line[2:].strip()))
        elif line.startswith("- "):
            close_paragraph()
            blocks.append(Block("bullet", line[2:].strip()))
        else:
            paragraph.append(line)
    close_paragraph()
    return blocks


def title_of(blocks: list[Block], source: Path) -> str:
    if not blocks or blocks[0].kind != "title":
        raise ValueError(f"{source.as_posix()}: a primeira linha precisa ser o título (# ...)")
    return blocks[0].text


def has_open_points(source: str) -> bool:
    return OPEN_POINT.search(source) is not None


def _inline(text: str) -> str:
    """O texto pronto para o HTML, com os trechos entre colchetes destacados."""
    escaped = html.escape(text, quote=False)
    return OPEN_POINT.sub(lambda match: f'<span class="pendente">{match.group(0)}</span>', escaped)


def render_body(blocks: list[Block]) -> str:
    parts: list[str] = []
    in_list = False

    def close_list() -> None:
        nonlocal in_list
        if in_list:
            parts.append("</ul>")
            in_list = False

    for block in blocks:
        if block.kind == "bullet":
            if not in_list:
                parts.append("<ul>")
                in_list = True
            parts.append(f"<li>{_inline(block.text)}</li>")
            continue
        close_list()
        if block.kind == "title":
            parts.append(f"<h1>{_inline(block.text)}</h1>")
        elif block.kind == "heading":
            parts.append(f"<h2>{_inline(block.text)}</h2>")
        else:
            parts.append(f"<p>{_inline(block.text)}</p>")
    close_list()
    return "\n".join(parts)


STYLE = """
:root { color-scheme: light; }
body {
  margin: 0;
  background: #fff;
  color: #333;
  font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
}
main { max-width: 44rem; margin: 0 auto; padding: 1.5rem 1.25rem 3rem; }
h1 { font-size: 1.75rem; line-height: 1.25; margin: 0.5rem 0 1rem; }
h2 { font-size: 1.15rem; margin: 2rem 0 0.5rem; }
p, li { margin: 0.5rem 0; }
ul { padding-left: 1.25rem; }
a { color: #c2410c; }
.marca { font-weight: 700; color: #4b5563; text-decoration: none; }
.aviso {
  background: #f2f3f4;
  border-radius: 12px;
  padding: 1rem;
  margin: 1rem 0 1.5rem;
  color: #4b5563;
}
.pendente { background: #fdf2e9; color: #92400e; }
nav { border-top: 1px solid #e5e7eb; margin-top: 2.5rem; padding-top: 1rem; }
nav ul { list-style: none; padding: 0; }
""".strip()


def render_page(*, title: str, body: str, links: list[tuple[str, str]], draft: bool) -> str:
    notice = f'<p class="aviso" role="note">{html.escape(DRAFT_NOTICE)}</p>\n' if draft else ""
    items = "\n".join(
        f'<li><a href="{html.escape(href)}">{html.escape(label)}</a></li>' for href, label in links
    )
    return f"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · {SITE_NAME}</title>
<style>
{STYLE}
</style>
</head>
<body>
<main>
<a class="marca" href="index.html">{SITE_NAME}</a>
{notice}{body}
<nav aria-label="Outros documentos">
<ul>
{items}
</ul>
</nav>
</main>
</body>
</html>
"""


def _write(path: Path, text: str) -> None:
    # Finais de linha iguais em qualquer sistema: o arquivo gerado no Windows
    # é o mesmo gerado no CI.
    with path.open("w", encoding="utf-8", newline="\n") as file:
        file.write(text)


def build(output: Path, root: Path = ROOT) -> list[Path]:
    """Gera o site em ``output`` e devolve os arquivos escritos."""
    documents: list[tuple[Page, str, list[Block], str]] = []
    for page in PAGES:
        path = root / page.source
        if not path.is_file():
            raise FileNotFoundError(f"texto de origem não encontrado: {page.source.as_posix()}")
        source = path.read_text(encoding="utf-8")
        blocks = parse_legal_text(source)
        documents.append((page, source, blocks, title_of(blocks, page.source)))

    output.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    all_links = [(f"{page.slug}.html", title) for page, _, _, title in documents]

    for page, source, blocks, title in documents:
        target = output / f"{page.slug}.html"
        others = [link for link in all_links if link[0] != target.name]
        _write(
            target,
            render_page(
                title=title,
                body=render_body(blocks),
                links=others,
                draft=has_open_points(source),
            ),
        )
        written.append(target)

    index = output / "index.html"
    _write(
        index,
        render_page(
            title="Documentos",
            body="<h1>Documentos do Yvenist</h1>",
            links=all_links,
            draft=any(has_open_points(source) for _, source, _, _ in documents),
        ),
    )
    written.append(index)
    return written


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="pasta de saída (padrão: build/legal-site)",
    )
    arguments = parser.parse_args(argv)

    try:
        written = build(arguments.out)
    except (FileNotFoundError, ValueError) as error:
        print(f"Erro: {error}", file=sys.stderr)
        return 1

    for path in written:
        print(path)
    return 0


if __name__ == "__main__":
    # No Windows o console pode não estar em UTF-8.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    sys.exit(main())
