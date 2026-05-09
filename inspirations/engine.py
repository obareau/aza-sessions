from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique


class InspirationsEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def list_all(self):
        conn = self._get_db()
        rows = conn.execute(
            "SELECT * FROM inspirations ORDER BY type, created_at DESC"
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def add(self, type_, content, source, notes):
        conn = self._get_db()
        conn.execute(
            "INSERT INTO inspirations (type, content, source, notes) VALUES (?,?,?,?)",
            (type_, content, source, notes)
        )
        conn.commit()
        conn.close()

    def edit(self, id_, type_, content, source, notes):
        conn = self._get_db()
        conn.execute(
            "UPDATE inspirations SET type=?,content=?,source=?,notes=? WHERE id=?",
            (type_, content, source, notes, id_)
        )
        conn.commit()
        conn.close()

    def delete(self, id_):
        conn = self._get_db()
        conn.execute("DELETE FROM inspirations WHERE id=?", (id_,))
        conn.commit()
        conn.close()
