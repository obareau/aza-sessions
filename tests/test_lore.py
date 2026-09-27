"""Lecture du corpus de lore.

Les tests construisent leur propre faux corpus : s'appuyer sur le vrai vault
ferait dépendre la suite d'un dossier hors du dépôt, et casserait le jour où
Olivier renomme un fichier de fiction — ce qui n'est pas une régression.
"""
from lore.engine import LoreEngine


def _corpus(tmp_path):
    """Un corpus minimal mais représentatif : frontmatter, sous-dossier, tableau."""
    lore = tmp_path / "Lore"
    (lore / "Lieux").mkdir(parents=True)
    (lore / "Lieux" / "scaer.md").write_text(
        "---\ntitle: Scaër\ntags: [lieu, bretagne]\n"
        "description: Bourg réel et lieu de l'univers à la fois.\n---\n\n"
        "# Scaër\n\n> \"Le silence n'est pas l'absence de son. C'est la présence du contrôle.\"\n",
        encoding="utf-8")
    # Pas de description en frontmatter : elle doit être prise dans le texte.
    (lore / "Lieux" / "hangar-9.md").write_text(
        "---\ntitle: Hangar 9\n---\n\n# Hangar 9\n\n"
        "Un entrepôt vide où la Rectitude entreposait ses archives sonores.\n",
        encoding="utf-8")
    (lore / "Lieux" / "index.md").write_text("---\ntitle: Lieux\n---\n", encoding="utf-8")
    # Sous-dossier — comme les Factions du vrai corpus.
    (lore / "Factions" / "Majeures").mkdir(parents=True)
    (lore / "Factions" / "Majeures" / "rectitude.md").write_text(
        "---\ntitle: La Rectitude\ntags: [faction]\ndescription: La doctrine du C.G.U.\n---\n\n"
        "> **Définition** — une notice, pas une voix : doit être écartée.\n",
        encoding="utf-8")
    (lore / "Temps").mkdir()
    (lore / "Temps" / "timeline.md").write_text(
        "---\ntitle: Chronologie\n---\n\n"
        "## Avant An 0\n\n"
        "| Date | Grégorien | Événement |\n|------|-----------|-----------|\n"
        "| **Pré-An 0 (−168)** | 2245 | Guerres Bio-Techniques |\n\n"
        "## Ère du Binaire\n\n"
        "| Date | Grégorien | Événement |\n|---|---|---|\n"
        "| **An 0** | 2413 | Fondation du [[cgu|C.G.U.]] |\n",
        encoding="utf-8")
    return LoreEngine(str(tmp_path))


def test_corpus_absent_ne_leve_pas(tmp_path):
    e = LoreEngine(str(tmp_path / "nulle-part"))
    assert e.dispo is False
    assert e.sections() == [] and e.tout() == []
    assert e.timeline() == [] and e.citations() == [] and e.citation() is None


def test_chemin_vide(tmp_path):
    assert LoreEngine("").dispo is False


def test_sections_et_comptes(tmp_path):
    e = _corpus(tmp_path)
    assert e.dispo is True
    comptes = {s["nom"]: s["nb"] for s in e.sections()}
    assert comptes["Lieux"] == 2       # index.md n'est pas une entrée
    assert comptes["Factions"] == 1    # trouvée dans son sous-dossier


def test_frontmatter_et_tags(tmp_path):
    scaer = next(x for x in _corpus(tmp_path).entrees("Lieux") if x["slug"] == "scaer")
    assert scaer["titre"] == "Scaër"
    assert scaer["tags"] == ["lieu", "bretagne"]
    assert scaer["description"].startswith("Bourg réel")


def test_description_de_secours(tmp_path):
    """Sans `description:`, la première phrase du texte tient le rôle."""
    h9 = next(x for x in _corpus(tmp_path).entrees("Lieux") if x["slug"] == "hangar-9")
    assert "entrepôt vide" in h9["description"]


def test_sous_section_affichee(tmp_path):
    f = _corpus(tmp_path).entrees("Factions")[0]
    assert f["sous_section"] == "Majeures"


def test_recherche(tmp_path):
    e = _corpus(tmp_path)
    assert [x["slug"] for x in e.cherche("scaër")] == ["scaer"]
    assert e.cherche("bretagne")          # par tag
    assert e.cherche("doctrine")          # par description
    assert e.cherche("") == []


def test_timeline_garde_ordre_et_ere(tmp_path):
    lignes = _corpus(tmp_path).timeline()
    assert len(lignes) == 2               # ni en-tête ni séparateur de tableau
    assert lignes[0]["ere"] == "Avant An 0"
    assert lignes[1]["ere"] == "Ère du Binaire"
    assert lignes[1]["gregorien"] == "2413"
    # Les wikilinks sont résolus à leur libellé, pas affichés brut.
    assert "[[" not in lignes[1]["evenement"] and "C.G.U." in lignes[1]["evenement"]


def test_citations_ecartent_les_definitions(tmp_path):
    cits = _corpus(tmp_path).citations()
    assert len(cits) == 1
    assert "silence" in cits[0]["texte"]
    assert cits[0]["source"] == "Scaër"


def test_citation_tiree_du_pool(tmp_path):
    e = _corpus(tmp_path)
    assert e.citation(seed=1)["texte"] in [c["texte"] for c in e.citations()]


def test_routes(client):
    """Les vues répondent même sans corpus configuré — elles le disent, c'est tout."""
    for url in ("/lore", "/lore/timeline", "/lore/section/Lieux", "/lore/citations"):
        assert client.get(url).status_code == 200, url
    assert client.get("/api/citation").status_code == 200
    assert "entrees" in client.get("/api/lore/entrees").get_json()
    assert client.get("/lore/section/Inexistante").status_code == 302
