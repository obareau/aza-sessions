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
        items = conn.execute("SELECT * FROM catalogue ORDER BY type, name").fetchall()
        conn.close()
        grouped = {k: [] for k in ITEM_TYPES}
        for item in items:
            if item["type"] in grouped:
                grouped[item["type"]].append(dict(item))
        return grouped

    def add(self, typ, name, notes=""):
        conn = self._get_db()
        conn.execute("INSERT INTO catalogue (type, name, notes) VALUES (?,?,?)", (typ, name, notes))
        conn.commit()
        conn.close()

    def delete(self, item_id):
        conn = self._get_db()
        conn.execute("DELETE FROM catalogue WHERE id=?", (item_id,))
        conn.commit()
        conn.close()

    def edit(self, item_id, name, notes=""):
        conn = self._get_db()
        conn.execute("UPDATE catalogue SET name=?, notes=? WHERE id=?", (name, notes, item_id))
        conn.commit()
        conn.close()

    def toggle(self, item_id):
        conn = self._get_db()
        conn.execute("UPDATE catalogue SET active=1-active WHERE id=?", (item_id,))
        conn.commit()
        conn.close()
