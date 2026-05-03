from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique


class ObliquesEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def list_all(self):
        conn = self._get_db()
        rows = conn.execute("SELECT * FROM obliques ORDER BY id").fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def add(self, text):
        conn = self._get_db()
        conn.execute("INSERT INTO obliques (text) VALUES (?)", (text,))
        conn.commit()
        conn.close()

    def delete(self, item_id):
        conn = self._get_db()
        conn.execute("DELETE FROM obliques WHERE id=?", (item_id,))
        conn.commit()
        conn.close()

    def edit(self, item_id, text):
        conn = self._get_db()
        conn.execute("UPDATE obliques SET text=? WHERE id=?", (text, item_id))
        conn.commit()
        conn.close()

    def toggle(self, item_id):
        conn = self._get_db()
        conn.execute("UPDATE obliques SET active=1-active WHERE id=?", (item_id,))
        conn.commit()
        conn.close()
