from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique


class WishlistEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def list_all(self):
        conn = self._get_db()
        rows = conn.execute(
            "SELECT * FROM gear_wishlist ORDER BY acquired, "
            "CASE priority WHEN 'Urgent' THEN 1 WHEN 'Bientôt' THEN 2 "
            "WHEN 'Un jour' THEN 3 ELSE 4 END, name"
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def add(self, manufacturer, name, type_, price, priority, notes, url):
        conn = self._get_db()
        conn.execute(
            "INSERT INTO gear_wishlist (manufacturer, name, type, price, priority, notes, url) VALUES (?,?,?,?,?,?,?)",
            (manufacturer, name, type_, price or None, priority, notes, url)
        )
        conn.commit()
        conn.close()

    def edit(self, id_, manufacturer, name, type_, price, priority, notes, url):
        conn = self._get_db()
        conn.execute(
            "UPDATE gear_wishlist SET manufacturer=?,name=?,type=?,price=?,priority=?,notes=?,url=? WHERE id=?",
            (manufacturer, name, type_, price or None, priority, notes, url, id_)
        )
        conn.commit()
        conn.close()

    def toggle_acquired(self, id_):
        conn = self._get_db()
        conn.execute("UPDATE gear_wishlist SET acquired=1-acquired WHERE id=?", (id_,))
        conn.commit()
        conn.close()

    def delete(self, id_):
        conn = self._get_db()
        conn.execute("DELETE FROM gear_wishlist WHERE id=?", (id_,))
        conn.commit()
        conn.close()
