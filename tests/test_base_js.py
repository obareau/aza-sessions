"""Le JS de base.html — thème personnalisé et mode focus.

Ces deux fonctionnalités vivent entièrement dans le navigateur : aucune route,
aucune table, donc rien que pytest puisse atteindre seul. Le harnais Node
(`tests/js/base_theme_focus.mjs`) exécute le JS réellement servi par la page
contre un faux DOM minimal. Sauté si Node n'est pas installé — le reste de la
suite n'a pas à en dépendre.
"""
import re
import shutil
import subprocess

import pytest

HARNAIS = "tests/js/base_theme_focus.mjs"


@pytest.mark.skipif(shutil.which("node") is None, reason="Node absent")
def test_js_base(client, tmp_path):
    html = client.get("/").get_data(as_text=True)
    # Les <script src=...> (Chart.js) ne sont pas dans la page : on ne garde que
    # le JS inline, celui qu'on écrit et qu'on peut donc casser.
    inline = re.findall(r"<script(?![^>]*src=)[^>]*>(.*?)</script>", html, re.S)
    assert inline, "aucun script inline dans la page — extraction cassée ?"
    page_js = tmp_path / "page.js"
    page_js.write_text("\n".join(inline))

    r = subprocess.run(["node", HARNAIS, str(page_js)],
                       capture_output=True, text=True, timeout=30)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "ÉCHEC" not in r.stdout, r.stdout
