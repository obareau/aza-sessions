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

    def candidates(self, gear_id):
        """Fiches associables — tout le catalogue actif sauf soi-même."""
        conn = self._get_db()
        rows = conn.execute(
            "SELECT id, name, type, manufacturer FROM catalogue "
            "WHERE active=1 AND id != ? ORDER BY type, name", (gear_id,)
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]
