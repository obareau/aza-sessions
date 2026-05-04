from core.db import get_db

ITEM_TYPES = {
    "machine":  "Hardware / Machines",
    "effet":    "Effets Hardware",
    "daw":      "DAW",
    "synth_ios":"Synthés iOS",
    "plugin":   "Plugins VST/AU",
}


class CatalogueEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def list_grouped(self):
        conn = self._get_db()
        items = conn.execute(
            "SELECT * FROM catalogue ORDER BY type, manufacturer, name"
        ).fetchall()
        conn.close()
        grouped = {k: [] for k in ITEM_TYPES}
        for item in items:
            if item["type"] in grouped:
                grouped[item["type"]].append(dict(item))
        return grouped

    def list_active_grouped(self):
        conn = self._get_db()
        items = conn.execute(
            "SELECT * FROM catalogue WHERE active=1 ORDER BY type, manufacturer, name"
        ).fetchall()
        conn.close()
        result = {k: [] for k in ITEM_TYPES}
        for item in items:
            if item["type"] in result:
                result[item["type"]].append(dict(item))
        return result

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
