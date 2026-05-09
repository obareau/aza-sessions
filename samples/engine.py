from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique


class SamplesEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def list_all(self):
        conn = self._get_db()
        rows = conn.execute("SELECT * FROM sample_banks ORDER BY type, name").fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def add(self, name, type_, rating, source, notes):
        conn = self._get_db()
        conn.execute(
            "INSERT INTO sample_banks (name, type, rating, source, notes) VALUES (?,?,?,?,?)",
            (name, type_, rating or None, source, notes)
        )
        conn.commit()
        conn.close()

    def edit(self, id_, name, type_, rating, source, notes):
        conn = self._get_db()
        conn.execute(
            "UPDATE sample_banks SET name=?,type=?,rating=?,source=?,notes=? WHERE id=?",
            (name, type_, rating or None, source, notes, id_)
        )
        conn.commit()
        conn.close()

    def delete(self, id_):
        conn = self._get_db()
        conn.execute("DELETE FROM sample_banks WHERE id=?", (id_,))
        conn.commit()
        conn.close()
