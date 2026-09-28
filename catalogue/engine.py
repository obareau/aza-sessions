import json
import re

from core.db import get_db
from core.constants import ITEM_TYPES  # noqa: F401 — ré-exporté pour catalogue.api


class CatalogueEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def list_grouped(self):
        """Retourne tous les items groupés par type — types libres inclus."""
        conn = self._get_db()
        items = conn.execute(
            "SELECT * FROM catalogue ORDER BY type, favorite DESC, manufacturer, name"
        ).fetchall()
        conn.close()
        grouped = {}
        for item in items:
            grouped.setdefault(item["type"], []).append(dict(item))
        return grouped

    def list_active_grouped(self):
        conn = self._get_db()
        items = conn.execute(
            "SELECT * FROM catalogue WHERE active=1 ORDER BY type, favorite DESC, manufacturer, name"
        ).fetchall()
        conn.close()
        result = {}
        for item in items:
            result.setdefault(item["type"], []).append(dict(item))
        return result

    def get_all_types(self):
        """Retourne tous les types distincts présents dans la DB (pour datalist)."""
        conn = self._get_db()
        rows = conn.execute(
            "SELECT DISTINCT type FROM catalogue ORDER BY type"
        ).fetchall()
        conn.close()
        return [r["type"] for r in rows]

    def add(self, typ, name, manufacturer="", notes=""):
        conn = self._get_db()
        conn.execute(
            "INSERT INTO catalogue (type, name, manufacturer, notes) VALUES (?,?,?,?)",
            (typ, name, manufacturer, notes)
        )
        conn.commit()
        conn.close()

    def add_inline(self, typ, name, manufacturer=""):
        """Ajout rapide inline — retourne le dict du nouvel item ou None si doublon."""
        conn = self._get_db()
        existing = conn.execute(
            "SELECT id FROM catalogue WHERE type=? AND name=?", (typ, name)
        ).fetchone()
        if existing:
            conn.close()
            return None
        conn.execute(
            "INSERT INTO catalogue (type, name, manufacturer) VALUES (?,?,?)",
            (typ, name, manufacturer)
        )
        conn.commit()
        row = conn.execute(
            "SELECT * FROM catalogue WHERE rowid = last_insert_rowid()"
        ).fetchone()
        conn.close()
        return dict(row)

    def add_bulk(self, typ, rows):
        """Saisie rapide multi-lignes. rows = liste de dicts {name, manufacturer, notes}.
        Ignore les lignes sans nom et les doublons (type, name). Retourne (ajoutés, ignorés)."""
        conn = self._get_db()
        added = skipped = 0
        try:
            for row in rows:
                name = (row.get("name") or "").strip()
                if not name:
                    continue
                manufacturer = (row.get("manufacturer") or "").strip()
                notes = (row.get("notes") or "").strip()
                existing = conn.execute(
                    "SELECT id FROM catalogue WHERE type=? AND name=?", (typ, name)
                ).fetchone()
                if existing:
                    skipped += 1
                    continue
                conn.execute(
                    "INSERT INTO catalogue (type, name, manufacturer, notes) VALUES (?,?,?,?)",
                    (typ, name, manufacturer, notes)
                )
                added += 1
            conn.commit()
        finally:
            conn.close()
        return added, skipped

    # ── Fiches détaillées ────────────────────────────────────────────────
    # `purpose` (à quoi ça sert) et `intent` (comment je compte m'en servir)
    # vivent sur la ligne du catalogue, pas dans une table à part : ce sont des
    # propriétés de la machine, pas des événements datés comme les remarques du
    # carnet. Une seconde table aurait obligé à un JOIN pour lire ce qui tient
    # dans deux colonnes.

    FICHE_FIELDS = ("code", "manufacturer", "purpose", "intent")

    def fiches(self, only_active=False):
        """Toutes les fiches, à plat, pour la vue table.

        À plat et non groupé : la vue table sert justement à comparer un plugin
        et une machine ligne à ligne — le regroupement par type est déjà ce que
        fait /catalogue.
        """
        conn = self._get_db()
        where = "WHERE active=1 " if only_active else ""
        rows = conn.execute(
            "SELECT id, type, name, code, manufacturer, purpose, intent, notes, active, favorite "
            f"FROM catalogue {where}ORDER BY type, favorite DESC, name COLLATE NOCASE"
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    # ── Nom de prise ─────────────────────────────────────────────────────
    #
    # Le Zoom R8 nomme ses prises tout seul (« FOLDER01 »), ce qui ne dit rien
    # six mois plus tard. Un nom construit depuis le matériel — MFMG5-1 pour
    # MicroFreak + MS-50G, première prise du jour — se relit sans ouvrir la
    # machine, et se retrouve dans AZA par une simple recherche.
    #
    # Les codes viennent du catalogue, jamais d'une saisie : c'est ce qui
    # distingue cette colonne du champ libre `signal_routing`, où « Microfrek »
    # s'est déjà écrit une fois.

    # Ordre des colonnes = ordre du signal : la machine d'abord, l'effet
    # ensuite. Alphabétiser les codes aurait mis la pédale avant le synthé.
    CODE_ORDER = ("machines", "effects", "synths_ios", "plugins")

    def codes_for(self, noms) -> list[str]:
        """Codes catalogue des noms donnés, dans l'ordre reçu, sans doublon.

        Un nom sans code est ignoré : mieux vaut un nom de prise plus court
        qu'un nom qui invente une abréviation.
        """
        noms = [n.strip() for n in noms if n and n.strip()]
        if not noms:
            return []
        conn = self._get_db()
        try:
            rows = conn.execute(
                "SELECT name, code FROM catalogue WHERE code IS NOT NULL AND TRIM(code) <> ''"
            ).fetchall()
        finally:
            conn.close()
        # Le R8 n'accepte que A-Z, 0-9 et « _ » : on retire le reste ici plutôt
        # que de faire confiance à la saisie.
        par_nom = {r["name"]: re.sub(r"[^A-Z0-9_]", "", r["code"].strip().upper())
                   for r in rows}
        out = []
        for n in noms:
            c = par_nom.get(n)
            if c and c not in out:
                out.append(c)
        return out

    # ⚠️ Contraintes du Zoom R8, vérifiées dans son manuel (p. 94) : un nom de
    # PROJET fait au plus 8 caractères et n'accepte que A-Z, 0-9 et « _ ».
    # Le tiret est INTERDIT — un « MFMG5-1 » serait refusé par la machine.
    # (Les noms de FICHIER audio, eux, tolèrent 219 caractères et le tiret ;
    # c'est le projet qu'on nomme ici, parce que c'est lui qu'on lit à l'écran.)
    TAKE_MAX = 8
    TAKE_SEP = "_"

    def take_preview(self, gear_par_colonne: dict, date: str) -> dict:
        """Le nom, et de quoi comprendre pourquoi c'est celui-là.

        `take_name` seul laisse une question sans réponse quand on regarde
        l'écran : pourquoi la pédale n'est-elle pas dans le nom ? Réponse
        presque toujours la même — elle n'a pas encore de code. Autant le dire
        plutôt que laisser chercher.
        """
        noms = []
        for col in self.CODE_ORDER:
            for n in (gear_par_colonne.get(col) or "").split(","):
                if n.strip():
                    noms.append(n.strip())
        codes = self.codes_for(noms)
        nom = self.take_name(gear_par_colonne, date)
        prefixe = "".join(codes)
        return {
            "nom":       nom,
            "prefixe":   prefixe,
            "longueur":  len(nom),
            "max":       self.TAKE_MAX,
            # Rogné : le préfixe complet ne tenait pas dans les 8 caractères.
            "tronque":   bool(nom) and not nom.startswith(prefixe),
            # Sélectionné mais absent du nom, faute de code au catalogue.
            "sans_code": [n for n in noms if not self._code_de(n)],
        }

    def _code_de(self, nom: str) -> str:
        conn = self._get_db()
        try:
            r = conn.execute("SELECT code FROM catalogue WHERE name=?", (nom,)).fetchone()
        finally:
            conn.close()
        return (r["code"] or "").strip() if r else ""

    def take_name(self, gear_par_colonne: dict, date: str) -> str:
        """Nom de prise du jour : codes concaténés + rang, ex. « MFMG5_1 ».

        Le compteur repart chaque jour — c'est le rythme d'un enregistreur de
        studio, où l'on refait la même chaîne trois fois dans l'après-midi.
        Deux sessions du même jour avec le même matériel donnent donc _1 et _2.

        Le rang est prioritaire sur les codes : si les 8 caractères ne suffisent
        pas, c'est le préfixe qu'on rogne, jamais le numéro — deux prises du même
        après-midi qui porteraient le même nom seraient pires qu'un nom tronqué.
        """
        noms = []
        for col in self.CODE_ORDER:
            for n in (gear_par_colonne.get(col) or "").split(","):
                if n.strip():
                    noms.append(n.strip())
        codes = self.codes_for(noms)
        if not codes:
            return ""
        prefixe = "".join(codes)
        conn = self._get_db()
        try:
            deja = conn.execute(
                "SELECT COUNT(*) FROM sessions WHERE date LIKE ? AND audio_file LIKE ?",
                (f"{date[:10]}%", f"{prefixe[:self.TAKE_MAX]}%")
            ).fetchone()[0]
        finally:
            conn.close()
        suffixe = f"{self.TAKE_SEP}{deja + 1}"
        place = max(1, self.TAKE_MAX - len(suffixe))
        return f"{prefixe[:place]}{suffixe}"

    def add_fiche(self, typ, name, manufacturer="", purpose="", intent="", code=""):
        """Crée une fiche complète depuis la vue table.

        Retourne l'id créé, ou None si le couple (type, nom) existe déjà — même
        garde que `add_inline` : le carnet croise les sessions par comparaison
        exacte du nom, deux fiches homonymes le rendraient ambigu.

        Lève ValueError si le type ou le nom manque. Deux sorties distinctes
        pour deux causes distinctes : une saisie incomplète et un doublon ne se
        corrigent pas pareil, et l'appelant ne peut le dire à l'utilisateur que
        s'il peut les distinguer.
        """
        typ  = (typ or "").strip().lower().replace(" ", "_")
        name = (name or "").strip()
        if not typ or not name:
            raise ValueError("type et nom sont requis")
        conn = self._get_db()
        try:
            existing = conn.execute(
                "SELECT id FROM catalogue WHERE type=? AND name=?", (typ, name)
            ).fetchone()
            if existing:
                return None
            cur = conn.execute(
                "INSERT INTO catalogue (type, name, manufacturer, purpose, intent, code) "
                "VALUES (?,?,?,?,?,?)",
                (typ, name, (manufacturer or "").strip(),
                 (purpose or "").strip(), (intent or "").strip(),
                 (code or "").strip().upper())
            )
            conn.commit()
            return cur.lastrowid
        finally:
            conn.close()

    def update_fiches(self, rows):
        """Enregistre la table d'un coup. rows = [{id, manufacturer, purpose, intent}].

        N'écrit que les lignes réellement modifiées : la table se soumet
        entière à chaque fois, et réécrire 40 lignes pour en changer une
        rendrait tout historique de modification illisible.
        Retourne le nombre de fiches touchées.
        """
        conn = self._get_db()
        touched = 0
        try:
            for row in rows:
                try:
                    item_id = int(row.get("id"))
                except (TypeError, ValueError):
                    continue
                current = conn.execute(
                    "SELECT code, manufacturer, purpose, intent FROM catalogue WHERE id=?",
                    (item_id,)
                ).fetchone()
                if current is None:
                    continue
                values = {f: (row.get(f) or "").strip() for f in self.FICHE_FIELDS}
                if all(values[f] == (current[f] or "") for f in self.FICHE_FIELDS):
                    continue
                conn.execute(
                    "UPDATE catalogue SET code=?, manufacturer=?, purpose=?, intent=? WHERE id=?",
                    (values["code"], values["manufacturer"],
                     values["purpose"], values["intent"], item_id)
                )
                touched += 1
            conn.commit()
        finally:
            conn.close()
        return touched

    def delete(self, item_id):
        conn = self._get_db()
        conn.execute("DELETE FROM catalogue WHERE id=?", (item_id,))
        conn.commit()
        conn.close()

    def edit(self, item_id, name, manufacturer="", notes=""):
        conn = self._get_db()
        conn.execute(
            "UPDATE catalogue SET name=?, manufacturer=?, notes=? WHERE id=?",
            (name, manufacturer, notes, item_id)
        )
        conn.commit()
        conn.close()

    def toggle(self, item_id):
        conn = self._get_db()
        conn.execute("UPDATE catalogue SET active=1-active WHERE id=?", (item_id,))
        conn.commit()
        conn.close()

    def toggle_favorite(self, item_id):
        conn = self._get_db()
        conn.execute("UPDATE catalogue SET favorite=1-favorite WHERE id=?", (item_id,))
        conn.commit()
        conn.close()

    # Ce qu'on « joue », par opposition aux interfaces et aux enregistreurs :
    # le catalogue mélange MicroFreak et Audient ID4 sous le même type.
    PLAYABLE_TYPES = ("machine", "effet", "plugin", "synth_ios", "plugin_ios")

    def chips(self, gear_columns, limit_recent=6):
        """Matériel proposé en un clic sur la saisie rapide.

        Ordre : favoris d'abord, puis ce qui a servi le plus récemment, puis
        l'alphabet. Le tri par usage évite d'avoir à marquer des favoris à la
        main pour que la liste devienne utile — elle le devient en s'en servant.
        """
        conn = self._get_db()
        rows = conn.execute(
            "SELECT id, name, type, favorite FROM catalogue "
            "WHERE active=1 AND type IN (%s) ORDER BY name"
            % ",".join("?" * len(self.PLAYABLE_TYPES)), self.PLAYABLE_TYPES
        ).fetchall()

        # Dernière apparition de chaque nom dans les sessions, toutes colonnes
        # matériel confondues. Peu de lignes ici : on lit et on croise en Python.
        seen = {}
        cols = ", ".join(gear_columns)
        for srow in conn.execute(f"SELECT date, {cols} FROM sessions ORDER BY date DESC"):
            for c in gear_columns:
                for part in (srow[c] or "").split(","):
                    part = part.strip()
                    if part and part not in seen:
                        seen[part] = srow["date"]
        conn.close()

        out = [{"id": r["id"], "name": r["name"], "type": r["type"],
                "favorite": bool(r["favorite"]), "last": seen.get(r["name"], "")}
               for r in rows]
        out.sort(key=lambda g: (not g["favorite"], g["last"] == "",
                                "" if not g["last"] else _invert(g["last"]), g["name"].lower()))
        return out


def _invert(d):
    """Clé de tri décroissante sur une date ISO, sans reverse global."""
    return "".join(chr(255 - ord(c)) if ord(c) < 255 else c for c in d)



class GearNotebookEngine:
    """Carnet par instrument — ce qu'on apprend d'une machine à force de s'en servir.

    Trois sources, une seule page :
      - les patches favoris viennent de `preset_notes` (module Presets, v3.7.0) —
        pas de seconde table, sinon la même information vivrait à deux endroits ;
      - les associations vivent dans `gear_pairings` ;
      - les remarques s'empilent dans `gear_notes`.
    """

    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def get(self, gear_id):
        conn = self._get_db()
        row = conn.execute("SELECT * FROM catalogue WHERE id=?", (gear_id,)).fetchone()
        conn.close()
        return dict(row) if row else None

    def presets(self, gear_id):
        """Patches notés pour cette machine, les mieux notés d'abord."""
        conn = self._get_db()
        rows = conn.execute("""
            SELECT id, date, preset_name, evocation, song_idea, rating, tags, session_id
            FROM preset_notes
            WHERE catalogue_id = ?
            ORDER BY COALESCE(rating, 0) DESC, date DESC
        """, (gear_id,)).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def pairings(self, gear_id):
        """Associations, vues des DEUX côtés.

        Une association est stockée une fois mais concerne deux machines : dire
        « le MicroFreak passe bien dans le NTS-1 » doit se lire aussi depuis la
        fiche du NTS-1. D'où l'UNION plutôt qu'un simple WHERE gear_id=?, qui
        n'aurait montré que la moitié de ce qu'on sait.
        """
        conn = self._get_db()
        rows = conn.execute("""
            SELECT p.id, p.note, c.id AS partner_id, c.name AS partner_name,
                   c.type AS partner_type, c.manufacturer AS partner_manufacturer
            FROM gear_pairings p JOIN catalogue c ON c.id = p.partner_id
            WHERE p.gear_id = ?
            UNION ALL
            SELECT p.id, p.note, c.id AS partner_id, c.name AS partner_name,
                   c.type AS partner_type, c.manufacturer AS partner_manufacturer
            FROM gear_pairings p JOIN catalogue c ON c.id = p.gear_id
            WHERE p.partner_id = ?
            ORDER BY partner_type, partner_name
        """, (gear_id, gear_id)).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def add_pairing(self, gear_id, partner_id, note=""):
        """Retourne True si ajoutée, False si doublon ou association à soi-même."""
        gear_id, partner_id = int(gear_id), int(partner_id)
        if gear_id == partner_id:
            return False
        conn = self._get_db()
        try:
            existing = conn.execute("""
                SELECT id FROM gear_pairings
                WHERE (gear_id=? AND partner_id=?) OR (gear_id=? AND partner_id=?)
            """, (gear_id, partner_id, partner_id, gear_id)).fetchone()
            if existing:
                return False
            conn.execute(
                "INSERT INTO gear_pairings (gear_id, partner_id, note) VALUES (?,?,?)",
                (gear_id, partner_id, note.strip())
            )
            conn.commit()
            return True
        finally:
            conn.close()

    def delete_pairing(self, pairing_id):
        conn = self._get_db()
        conn.execute("DELETE FROM gear_pairings WHERE id=?", (pairing_id,))
        conn.commit()
        conn.close()

    def notes(self, gear_id):
        conn = self._get_db()
        rows = conn.execute(
            "SELECT * FROM gear_notes WHERE gear_id=? ORDER BY date DESC, id DESC",
            (gear_id,)
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def add_note(self, gear_id, note, date=None):
        note = (note or "").strip()
        if not note:
            return False
        from datetime import date as _date
        conn = self._get_db()
        conn.execute(
            "INSERT INTO gear_notes (gear_id, date, note) VALUES (?,?,?)",
            (gear_id, date or _date.today().isoformat(), note)
        )
        conn.commit()
        conn.close()
        return True

    def delete_note(self, note_id):
        conn = self._get_db()
        conn.execute("DELETE FROM gear_notes WHERE id=?", (note_id,))
        conn.commit()
        conn.close()

    # Les colonnes de session qui portent du matériel, telles que les remplit
    # sessions/api.py — ", ".join(form.getlist(...)).
    GEAR_COLUMNS = ("machines", "effects", "daws", "synths_ios",
                    "plugins", "ipad", "zynthian")

    def sessions(self, gear_id):
        """Les sessions où cette fiche a joué.

        Rien à saisir : l'information est déjà dans les sessions, elle n'avait
        simplement aucun endroit où se lire depuis la machine.

        Le filtrage se fait en deux temps — un LIKE large en SQL pour ne pas
        tout charger, puis une comparaison exacte élément par élément en Python.
        Le LIKE seul confondrait « Volca Drum » et « Volca Kick » dès qu'on
        chercherait « Volca », et surtout ferait correspondre n'importe quel
        nom court contenu dans un autre.
        """
        gear = self.get(gear_id)
        if not gear:
            return []
        name = (gear["name"] or "").strip()
        if not name:
            return []

        where = " OR ".join(f"{c} LIKE ?" for c in self.GEAR_COLUMNS)
        params = [f"%{name}%"] * len(self.GEAR_COLUMNS)
        conn = self._get_db()
        rows = conn.execute(
            f"SELECT id, date, title, session_type, rating, {', '.join(self.GEAR_COLUMNS)} "
            f"FROM sessions WHERE {where} ORDER BY date DESC", params
        ).fetchall()
        conn.close()

        out = []
        for r in rows:
            named = any(
                name == part.strip()
                for c in self.GEAR_COLUMNS
                for part in (r[c] or "").split(",")
            )
            if named:
                out.append({k: r[k] for k in ("id", "date", "title", "session_type", "rating")})
        return out

    def candidates(self, gear_id):
        """Fiches associables — tout le catalogue actif sauf soi-même."""
        conn = self._get_db()
        rows = conn.execute(
            "SELECT id, name, type, manufacturer FROM catalogue "
            "WHERE active=1 AND id != ? ORDER BY type, name", (gear_id,)
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]


# ══════════════════════════════════════════════════════════════════════════════
# RELEVÉS DE POTARDS
# ══════════════════════════════════════════════════════════════════════════════

DIAL_MIN, DIAL_MAX = 0, 10


def parse_controls(texte: str) -> list[dict]:
    """Lit la déclaration des commandes d'un instrument, une par ligne.

        -- OSCILLATEUR          → un titre de section
        Cutoff                  → un potentiomètre, de 0 à 10
        Filtre: LP | BP | HP    → un sélecteur, avec ses positions
        # ceci est ignoré

    Du texte libre plutôt qu'un éditeur de façade : déclarer vingt commandes se
    fait en vingt lignes tapées d'un trait, alors qu'un constructeur visuel
    demanderait vingt glissers-déposers — et ne servirait qu'une fois par
    machine. Les sections ne sont là que pour la lecture d'une fiche imprimée.
    """
    out = []
    for ligne in (texte or "").splitlines():
        ligne = ligne.strip()
        if not ligne or ligne.startswith("#"):
            continue
        if ligne.startswith("--"):
            titre = ligne.lstrip("-").strip()
            if titre:
                out.append({"kind": "section", "name": titre, "options": []})
            continue
        if ":" in ligne:
            nom, _, reste = ligne.partition(":")
            options = [o.strip() for o in reste.split("|") if o.strip()]
            if nom.strip() and options:
                out.append({"kind": "switch", "name": nom.strip(), "options": options})
                continue
        out.append({"kind": "dial", "name": ligne, "options": []})
    return out


def controls_names(texte: str) -> list[str]:
    """Les seuls noms relevables — les sections n'ont pas de valeur."""
    return [c["name"] for c in parse_controls(texte) if c["kind"] != "section"]


class KnobSheetEngine:
    """Relevés de positions de potards, par instrument.

    Existe pour ce que rien d'autre ne rattrape : un synthé analo sans mémoire
    (le Behringer Wasp, une pédale) perd son réglage dès qu'on l'éteint. Le
    relevé est la seule trace qui permette de retrouver un son.
    """

    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def instruments(self) -> list[dict]:
        """Les fiches actives, celles qui ont une façade déclarée en tête.

        Une machine sans déclaration reste dans la liste : c'est justement d'ici
        qu'on va la déclarer, et la masquer obligerait à repasser par le
        catalogue pour commencer.
        """
        conn = self._get_db()
        rows = conn.execute("""
            SELECT c.id, c.name, c.type, c.manufacturer, c.controls,
                   (SELECT COUNT(*) FROM knob_sheets k WHERE k.gear_id = c.id) AS nb_releves
            FROM catalogue c WHERE c.active = 1 ORDER BY c.name
        """).fetchall()
        conn.close()
        out = []
        for r in rows:
            d = dict(r)
            d["nb_commandes"] = len([c for c in parse_controls(d["controls"])
                                     if c["kind"] != "section"])
            out.append(d)
        return sorted(out, key=lambda d: (-d["nb_commandes"], -d["nb_releves"],
                                          d["name"].lower()))

    def controls(self, gear_id) -> list[dict]:
        conn = self._get_db()
        row = conn.execute("SELECT controls FROM catalogue WHERE id=?", (gear_id,)).fetchone()
        conn.close()
        return parse_controls(row["controls"] if row else "")

    def set_controls(self, gear_id, texte):
        conn = self._get_db()
        conn.execute("UPDATE catalogue SET controls=? WHERE id=?", (texte or "", gear_id))
        conn.commit()
        conn.close()

    def sheets(self, gear_id, session_id=None) -> list[dict]:
        """Les relevés d'un instrument, le plus récent d'abord.

        Chaque relevé est rendu **contre la déclaration courante** : une commande
        déclarée après coup apparaît vide au lieu de manquer, et une commande
        retirée de la déclaration ne traîne plus dans l'affichage — la valeur
        reste en base, elle, au cas où elle reviendrait.
        """
        conn = self._get_db()
        sql = ("SELECT k.*, p.preset_name FROM knob_sheets k "
               "LEFT JOIN preset_notes p ON p.id = k.preset_id WHERE k.gear_id=?")
        args = [gear_id]
        if session_id is not None:
            sql += " AND k.session_id=?"
            args.append(session_id)
        rows = conn.execute(sql + " ORDER BY datetime(k.created_at) DESC, k.id DESC", args).fetchall()
        conn.close()
        modele = self.controls(gear_id)
        out = []
        for r in rows:
            d = dict(r)
            try:
                valeurs = json.loads(d.pop("values_json") or "{}")
            except ValueError:
                valeurs = {}
            d["controls"] = [
                {**c, "value": valeurs.get(c["name"], "")}
                for c in modele if c["kind"] != "section"
            ] if modele else [
                # Aucune déclaration : on montre quand même ce qui a été relevé,
                # sinon un relevé pris avant la déclaration deviendrait invisible.
                {"kind": "dial", "name": k, "options": [], "value": v}
                for k, v in valeurs.items()
            ]
            d["sections"] = modele
            d["valeurs"] = valeurs
            out.append(d)
        return out

    def by_session(self, session_id) -> list[dict]:
        """Tous les relevés rattachés à une séance, quel que soit l'instrument.

        C'est ce que lit la fiche de rappel : pour rejouer, il faut les façades
        de toute la chaîne, pas celle d'une machine à la fois.
        """
        conn = self._get_db()
        rows = conn.execute(
            "SELECT k.gear_id, c.name AS gear_name, c.manufacturer "
            "FROM knob_sheets k JOIN catalogue c ON c.id = k.gear_id "
            "WHERE k.session_id = ? GROUP BY k.gear_id ORDER BY c.name",
            (session_id,)).fetchall()
        conn.close()
        out = []
        for r in rows:
            for sh in self.sheets(r["gear_id"], session_id=session_id):
                out.append({**sh, "gear_name": r["gear_name"],
                            "manufacturer": r["manufacturer"]})
        return out

    def save(self, gear_id, valeurs: dict, label="", session_id=None, notes="",
             preset_id=None) -> int:
        """Enregistre un relevé. Les commandes non renseignées ne sont pas stockées.

        Un potard laissé vide veut dire « pas noté », pas « à zéro » — écrire 0
        inventerait un réglage qu'on n'a pas lu sur la façade.
        """
        propres = {}
        for nom, val in (valeurs or {}).items():
            val = (str(val) if val is not None else "").strip()
            if val == "":
                continue
            propres[nom] = val
        conn = self._get_db()
        cur = conn.execute(
            "INSERT INTO knob_sheets (gear_id, session_id, preset_id, label, values_json, notes) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (gear_id, session_id, preset_id or None, (label or "").strip(),
             json.dumps(propres, ensure_ascii=False), (notes or "").strip()),
        )
        conn.commit()
        sheet_id = cur.lastrowid
        conn.close()
        return sheet_id

    def delete(self, sheet_id):
        conn = self._get_db()
        conn.execute("DELETE FROM knob_sheets WHERE id=?", (sheet_id,))
        conn.commit()
        conn.close()
