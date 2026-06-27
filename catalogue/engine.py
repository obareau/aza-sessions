from core.db import get_db

ITEM_TYPES = {
    "machine":  "Hardware / Machines",
    "effet":    "Effets Hardware",
    "daw":      "DAW",
    "synth_ios":"Synthés iOS",
    "ipad":     "Apps iPad",
    "zynthian": "Zynthian / Raspberry Pi",
    "plugin":   "Plugins VST/AU",
}


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
