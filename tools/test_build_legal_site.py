"""Testes do gerador das páginas públicas dos textos legais.

Da raiz do repositório::

    python -m unittest discover -s tools -p "test_*.py"
"""

from __future__ import annotations

import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_legal_site as site

ROOT = Path(__file__).resolve().parent.parent


class ParseLegalTextTest(unittest.TestCase):
    def test_separa_titulo_secoes_itens_e_paragrafos(self) -> None:
        # O mesmo texto e o mesmo resultado do teste do leitor do app
        # (test/features/legal/legal_document_test.dart): os dois leitores têm
        # de entender os textos do mesmo jeito.
        blocks = site.parse_legal_text(
            "# Termos\n\nVersão 1\n\n## 1. Conta\n\n"
            "Primeira linha\ncontinua aqui.\n\n- item um\n- item dois\n"
        )

        self.assertEqual(
            [(block.kind, block.text) for block in blocks],
            [
                ("title", "Termos"),
                ("paragraph", "Versão 1"),
                ("heading", "1. Conta"),
                ("paragraph", "Primeira linha continua aqui."),
                ("bullet", "item um"),
                ("bullet", "item dois"),
            ],
        )

    def test_aceita_finais_de_linha_do_windows_e_ignora_linhas_em_branco(self) -> None:
        blocks = site.parse_legal_text("## Seção\r\n\r\n\r\nTexto\r\n")

        self.assertEqual([block.text for block in blocks], ["Seção", "Texto"])

    def test_texto_vazio_nao_gera_trechos(self) -> None:
        self.assertEqual(site.parse_legal_text(""), [])
        self.assertEqual(site.parse_legal_text("\n\n"), [])


class RenderTest(unittest.TestCase):
    def test_o_texto_nunca_vira_marcacao(self) -> None:
        body = site.render_body(site.parse_legal_text("# A & B\n\n<script>alert(1)</script>\n"))

        self.assertIn("<h1>A &amp; B</h1>", body)
        self.assertIn("&lt;script&gt;", body)
        self.assertNotIn("<script>", body)

    def test_itens_seguidos_formam_uma_lista_so(self) -> None:
        body = site.render_body(site.parse_legal_text("- um\n- dois\n\nfim\n"))

        self.assertEqual(body, "<ul>\n<li>um</li>\n<li>dois</li>\n</ul>\n<p>fim</p>")

    def test_trecho_entre_colchetes_aparece_destacado(self) -> None:
        body = site.render_body(site.parse_legal_text("Fale com [e-mail a definir].\n"))

        self.assertIn('<span class="pendente">[e-mail a definir]</span>', body)

    def test_sem_titulo_na_primeira_linha_e_um_erro(self) -> None:
        with self.assertRaises(ValueError):
            site.title_of(site.parse_legal_text("texto sem título\n"), Path("x.md"))


class BuildTest(unittest.TestCase):
    """Gera o site a partir dos textos de verdade do repositório."""

    @classmethod
    def setUpClass(cls) -> None:
        cls._folder = tempfile.TemporaryDirectory()
        cls.output = Path(cls._folder.name)
        cls.written = site.build(cls.output)
        cls.pages = {path.name: path.read_text(encoding="utf-8") for path in cls.written}

    @classmethod
    def tearDownClass(cls) -> None:
        cls._folder.cleanup()

    def test_gera_uma_pagina_por_documento_e_o_indice(self) -> None:
        self.assertEqual(
            sorted(self.pages),
            [
                "exclusao-de-conta.html",
                "index.html",
                "politica-de-privacidade.html",
                "termos-de-uso.html",
            ],
        )

    def test_cada_pagina_tem_o_titulo_do_documento_e_cita_o_yvenist(self) -> None:
        # A Play Store pede que a página de exclusão de conta cite o nome do
        # app, e que a política seja reconhecível como a dele.
        titles = {
            "politica-de-privacidade.html": "Política de Privacidade",
            "termos-de-uso.html": "Termos de Uso",
            "exclusao-de-conta.html": "Exclusão de conta",
        }
        for name, title in titles.items():
            with self.subTest(name):
                page = self.pages[name]
                self.assertIn(f"<h1>{title}</h1>", page)
                self.assertIn(f"<title>{title} · Yvenist</title>", page)
                self.assertIn('<html lang="pt-BR">', page)

    def test_as_paginas_se_ligam_entre_si(self) -> None:
        for name, page in self.pages.items():
            for other in self.pages:
                if other not in (name, "index.html"):
                    with self.subTest(f"{name} -> {other}"):
                        self.assertIn(f'href="{other}"', page)
            if name != "index.html":
                self.assertNotIn(f'<li><a href="{name}"', page)

    def test_nenhuma_pagina_chama_um_endereco_de_fora(self) -> None:
        # Uma política de privacidade que carregasse fonte, script ou imagem
        # de terceiros entregaria a eles o IP de quem a lê.
        for name, page in self.pages.items():
            with self.subTest(name):
                self.assertNotRegex(page, r"(?i)(src|href)\s*=\s*[\"']?(https?:)?//")
                self.assertNotIn("<script", page)
                self.assertNotIn("@import", page)

    def test_enquanto_houver_lacunas_a_pagina_diz_que_e_preliminar(self) -> None:
        for page in site.PAGES:
            source = (ROOT / page.source).read_text(encoding="utf-8")
            html = self.pages[f"{page.slug}.html"]
            with self.subTest(page.slug):
                self.assertEqual(site.has_open_points(source), site.DRAFT_NOTICE in html)
                if site.has_open_points(source):
                    self.assertIn("(preliminar)", source)

    def test_a_pagina_de_exclusao_de_conta_tem_a_versao_que_o_servidor_registra(self) -> None:
        # Os dois textos do app são conferidos pelo teste do app; esta página
        # só existe no site e segue a mesma versão.
        settings = (ROOT / "backend/app/core/config.py").read_text(encoding="utf-8")
        versions = re.findall(r'terms_version: str = "([^"]+)"', settings)
        self.assertEqual(len(versions), 1)
        source = (ROOT / "deploy/site/exclusao-de-conta.md").read_text(encoding="utf-8")

        version_line = site.parse_legal_text(source)[1].text
        self.assertEqual(version_line.split(" (")[0], f"Versão {versions[0]}")

    def test_gerar_duas_vezes_da_o_mesmo_resultado(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            again = {path.name: path.read_bytes() for path in site.build(Path(folder))}

        self.assertEqual(again, {path.name: path.read_bytes() for path in self.written})


if __name__ == "__main__":
    unittest.main()
