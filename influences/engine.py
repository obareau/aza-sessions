from core.db import get_db


class InfluencesEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def list_all(self):
        conn = self._get_db()
        rows = conn.execute("SELECT * FROM influences ORDER BY type, name").fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def add(self, name, typ="artiste", notes=""):
        conn = self._get_db()
        conn.execute("INSERT INTO influences (name, type, notes) VALUES (?,?,?)", (name, typ, notes))
        conn.commit()
        conn.close()

    def delete(self, item_id):
        conn = self._get_db()
        conn.execute("DELETE FROM influences WHERE id=?", (item_id,))
        conn.commit()
        conn.close()

    def edit(self, item_id, name, typ="artiste", notes=""):
        conn = self._get_db()
        conn.execute(
            "UPDATE influences SET name=?, type=?, notes=? WHERE id=?",
            (name, typ, notes, item_id)
        )
        conn.commit()
        conn.close()

    def toggle(self, item_id):
        conn = self._get_db()
        conn.execute("UPDATE influences SET active=1-active WHERE id=?", (item_id,))
        conn.commit()
        conn.close()
