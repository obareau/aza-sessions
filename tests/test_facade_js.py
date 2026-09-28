"""Le potard rotatif de la fiche matériel.

Ce comportement vit entièrement dans le navigateur : la distinction « pas
relevé » / « à zéro » est portée par du JS qu'aucun test Python n'atteint — le
test de bout en bout postait le formulaire directement, sans exécuter la page.
C'est précisément ainsi qu'un `<script>` mal placé est passé inaperçu.
"""
import re
import shutil
import subprocess

import pytest

from core.db import get_db

HARNAIS = "tests/js/facade_knobs.mjs"


@pytest.mark.skipif(shutil.which("node") is None, reason="Node absent")
def test_potard(client, tmp_path):
    conn = get_db(__import__("os").environ["DB_PATH"])
    cur = conn.execute(
        "INSERT INTO catalogue (type, name, manufacturer, active, controls) "
        "VALUES ('machine', 'Façade JS', 'Test', 1, '-- FILTRE\nCutoff')")
    conn.commit()
    gid = cur.lastrowid
    conn.close()

    html = client.get(f"/catalogue/{gid}/facade").get_data(as_text=True)
    # Uniquement le script de la façade : la page porte aussi ceux de base.html
    # (thème, pomodoro…), qui demandent tout un navigateur pour démarrer.
    inline = [b for b in re.findall(r"<script(?![^>]*src=)[^>]*>(.*?)</script>", html, re.S)
              if "POTARDS ROTATIFS" in b]
    assert inline, "script de façade absent — a-t-il glissé hors du bloc de contenu ?"
    js = tmp_path / "page.js"
    js.write_text("\n".join(inline))

    r = subprocess.run(["node", HARNAIS, str(js)], capture_output=True, text=True, timeout=30)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "ÉCHEC" not in r.stdout, r.stdout
