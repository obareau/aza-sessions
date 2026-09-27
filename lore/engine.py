"""Lecture du corpus de lore — Obsidian reste la référence, AZA ne fait que lire.

Décision du 2026-09-27 : aucune entité AZA n'est stockée en base. Les lieux,
factions, entités et la chronologie vivent dans le vault Robōtariis, validés
là-bas ; les dupliquer ici garantirait deux vérités qui divergeraient dès la
première correction faite d'un seul côté.

Conséquences assumées :
- **AZA ne rend pas le Markdown.** Le corpus est déjà lisible dans Obsidian et
  publié sur robotariis.com. Ce qu'il manquait au journal, c'est de *pointer*
  vers le lore, pas d'en devenir un second lecteur. On affiche donc l'en-tête
  (titre, description, tags) et on renvoie au texte complet — pas de moteur
  Markdown, pas de dépendance ajoutée.
- **Pas de vault, pas de page.** Si le chemin est absent, chaque vue le dit et
  reste vide, plutôt que de faire croire que le lore est perdu.
"""
import os
import random
import re

# Le nom du dossier sur disque → l'étiquette affichée. L'ordre est celui du
# `Lore/index.md` du vault : du personnage au temps, comme il l'a rangé.
SECTIONS = {
    "Personnages":  "Personnages",
    "Factions":     "Factions",
    "Entites":      "Entités",
    "Institutions": "Institutions",
    "Culture":      "Culture",
    "Concepts":     "Concepts",
    "Lieux":        "Lieux",
    "Temps":        "Temps",
    "Langages":     "Langages",
}

# Un index de section n'est pas une entrée : c'est le sommaire du dossier.
IGNORES = {"index"}

CITATION_MIN, CITATION_MAX = 40, 320


def _frontmatter(texte: str) -> tuple[dict, str]:
    """Extrait le frontmatter YAML sans dépendre d'un parseur YAML.

    Le corpus n'utilise que des scalaires et des listes inline (`tags: [a, b]`) ;
    installer PyYAML pour ça serait payer une dépendance pour six lignes.
    """
    if not texte.startswith("---"):
        return {}, texte
    fin = texte.find("\n---", 3)
    if fin == -1:
        return {}, texte
    meta = {}
    for ligne in texte[3:fin].splitlines():
        if ":" not in ligne or ligne.lstrip().startswith("#"):
            continue
        cle, _, val = ligne.partition(":")
        cle, val = cle.strip(), val.strip().strip('"').strip("'")
        if val.startswith("[") and val.endswith("]"):
            meta[cle] = [t.strip() for t in val[1:-1].split(",") if t.strip()]
        else:
            meta[cle] = val
    return meta, texte[fin + 4:]


def _wikilinks(ligne: str) -> str:
    """`[[cible|libellé]]` → `libellé`.

    À faire **avant** de découper une ligne de tableau : la barre verticale d'un
    wikilink est le même caractère que le séparateur de cellule Markdown, et un
    découpage naïf coupait « Fondation du [[cgu|C.G.U.]] » en deux colonnes.
    """
    ligne = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", ligne)
    return re.sub(r"\[\[([^\]]+)\]\]", r"\1", ligne)


def _nettoie(ligne: str) -> str:
    """Retire le balisage d'une ligne de Markdown pour l'afficher telle quelle."""
    ligne = _wikilinks(ligne)
    ligne = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", ligne)
    ligne = re.sub(r"[*_`]{1,3}", "", ligne)
    return re.sub(r"\s+", " ", ligne).strip()


def _premier_paragraphe(corps: str) -> str:
    """Faute de `description:` en frontmatter, la première phrase du texte.

    Une carte sans une ligne de contexte n'apprend rien ; le corpus n'a pas
    toujours de description, mais il a toujours un premier paragraphe.
    """
    for ligne in corps.splitlines():
        ligne = ligne.strip()
        if not ligne or ligne.startswith(("#", "|", ">", "-", "*", "!", "---")):
            continue
        texte = _nettoie(ligne)
        if len(texte) > 25:
            return texte[:300]
    return ""


class LoreEngine:
    """Lecteur du corpus. Sans état : le vault peut changer entre deux requêtes."""

    def __init__(self, racine: str):
        self.racine = os.path.expanduser(racine or "")

    # ── Disponibilité ────────────────────────────────────────────────────────
    @property
    def dispo(self) -> bool:
        return bool(self.racine) and os.path.isdir(os.path.join(self.racine, "Lore"))

    def _dossier(self, section: str) -> str:
        return os.path.join(self.racine, "Lore", section)

    # ── Entrées ──────────────────────────────────────────────────────────────
    def _lit(self, section: str, slug: str) -> dict | None:
        """`slug` est relatif au dossier de section — « Majeures/cgu-rectitude »."""
        chemin = os.path.join(self._dossier(section), slug + ".md")
        try:
            with open(chemin, encoding="utf-8") as f:
                texte = f.read()
        except OSError:
            return None
        meta, corps = _frontmatter(texte)
        # Titre : le frontmatter d'abord, puis le premier `# `, puis le slug.
        titre = meta.get("title") or ""
        if not titre:
            for ligne in corps.splitlines():
                if ligne.startswith("# "):
                    titre = _nettoie(ligne[2:])
                    break
        return {
            "section":      section,
            "section_nom":  SECTIONS.get(section, section),
            # Certaines sections sont rangées en sous-dossiers (Factions/Majeures) :
            # l'afficher évite qu'une faction mineure passe pour une majeure.
            "sous_section": os.path.dirname(slug).replace(os.sep, " / "),
            "slug":         slug,
            "titre":        titre or os.path.basename(slug).replace("-", " ").title(),
            "description":  meta.get("description") or _premier_paragraphe(corps),
            "tags":         meta.get("tags", []) if isinstance(meta.get("tags"), list) else [],
            "date":         meta.get("date", ""),
        }

    def entrees(self, section: str) -> list[dict]:
        """Toutes les entrées d'une section, sous-dossiers compris.

        Les Factions sont rangées en Majeures / Mineures / Grises / Groupes : une
        lecture à plat n'en aurait vu aucune, et la section aurait paru vide.
        """
        if section not in SECTIONS or not self.dispo:
            return []
        racine = self._dossier(section)
        slugs = []
        for dossier, _, fichiers in os.walk(racine):
            for f in fichiers:
                if not f.endswith(".md") or f[:-3] in IGNORES:
                    continue
                slugs.append(os.path.relpath(os.path.join(dossier, f[:-3]), racine))
        out = [self._lit(section, s) for s in sorted(slugs)]
        return sorted((e for e in out if e), key=lambda e: e["titre"].lower())

    def tout(self) -> list[dict]:
        return [e for s in SECTIONS for e in self.entrees(s)]

    def sections(self) -> list[dict]:
        """Les sections avec leur compte — une section vide n'est pas affichée."""
        out = []
        for cle, nom in SECTIONS.items():
            n = len(self.entrees(cle))
            if n:
                out.append({"cle": cle, "nom": nom, "nb": n})
        return out

    def cherche(self, q: str) -> list[dict]:
        q = (q or "").strip().lower()
        if not q:
            return []
        return [e for e in self.tout()
                if q in e["titre"].lower() or q in e["description"].lower()
                or any(q in t.lower() for t in e["tags"])]

    # ── Chronologie ──────────────────────────────────────────────────────────
    def timeline(self) -> list[dict]:
        """La chronologie telle qu'elle est écrite dans `Lore/Temps/timeline.md`.

        Le fichier est une suite de tableaux Markdown sous des titres d'ère. On
        lit les lignes, on garde l'ère courante en tête : l'ordre du fichier EST
        l'ordre narratif, il n'y a rien à trier — et surtout rien à inventer.
        """
        chemin = os.path.join(self.racine, "Lore", "Temps", "timeline.md")
        try:
            with open(chemin, encoding="utf-8") as f:
                _, corps = _frontmatter(f.read())
        except OSError:
            return []
        lignes, ere = [], ""
        for ligne in corps.splitlines():
            ligne = ligne.rstrip()
            if ligne.startswith("#"):
                ere = _nettoie(ligne.lstrip("# "))
                continue
            if not ligne.startswith("|"):
                continue
            cellules = [_nettoie(c) for c in _wikilinks(ligne).strip("|").split("|")]
            if len(cellules) < 3:
                continue
            # En-tête et ligne de séparation du tableau
            if cellules[0].lower() in ("date", "") or set(cellules[0]) <= {"-", ":"}:
                continue
            lignes.append({"ere": ere, "date": cellules[0],
                           "gregorien": cellules[1], "evenement": cellules[2]})
        return lignes

    # ── Citations ────────────────────────────────────────────────────────────
    def citations(self) -> list[dict]:
        """Les blocs de citation (`> …`) du corpus — ses mots, pas les miens.

        Les définitions de glossaire sont écartées : elles expliquent l'univers
        au lieu de le faire entendre, et ce qu'on veut afficher ici c'est une
        voix, pas une notice.
        """
        if not self.dispo:
            return []
        out, vues = [], set()
        for entree in self.tout():
            chemin = os.path.join(self._dossier(entree["section"]), entree["slug"] + ".md")
            try:
                with open(chemin, encoding="utf-8") as f:
                    lignes = f.read().splitlines()
            except OSError:
                continue
            for ligne in lignes:
                if not ligne.startswith("> "):
                    continue
                texte = _nettoie(ligne[2:])
                if texte.startswith("Définition"):
                    continue
                if not (CITATION_MIN <= len(texte) <= CITATION_MAX) or texte in vues:
                    continue
                vues.add(texte)
                out.append({"texte": texte, "source": entree["titre"],
                            "section": entree["section"], "slug": entree["slug"]})
        return out

    def citation(self, seed=None) -> dict | None:
        pool = self.citations()
        return random.Random(seed).choice(pool) if pool else None
