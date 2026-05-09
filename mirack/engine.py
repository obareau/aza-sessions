from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique


class MirackEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def list_all(self):
        conn = self._get_db()
        rows = conn.execute(
            "SELECT * FROM mirack_modules ORDER BY category, name"
        ).fetchall()
        conn.close()
        modules = [dict(r) for r in rows]
        grouped = {}
        for m in modules:
            cat = m["category"] or "Autre"
            grouped.setdefault(cat, []).append(m)
        return modules, grouped

    def add(self, name, category, mastered, favorite, notes):
        conn = self._get_db()
        conn.execute(
            "INSERT INTO mirack_modules (name, category, mastered, favorite, notes) VALUES (?,?,?,?,?)",
            (name, category, 1 if mastered else 0, 1 if favorite else 0, notes)
        )
        conn.commit()
        conn.close()

    def edit(self, id_, name, category, notes):
        conn = self._get_db()
        conn.execute(
            "UPDATE mirack_modules SET name=?,category=?,notes=? WHERE id=?",
            (name, category, notes, id_)
        )
        conn.commit()
        conn.close()

    def toggle_mastered(self, id_):
        conn = self._get_db()
        conn.execute("UPDATE mirack_modules SET mastered=1-mastered WHERE id=?", (id_,))
        conn.commit()
        conn.close()

    def toggle_favorite(self, id_):
        conn = self._get_db()
        conn.execute("UPDATE mirack_modules SET favorite=1-favorite WHERE id=?", (id_,))
        conn.commit()
        conn.close()

    def delete(self, id_):
        conn = self._get_db()
        conn.execute("DELETE FROM mirack_modules WHERE id=?", (id_,))
        conn.commit()
        conn.close()
