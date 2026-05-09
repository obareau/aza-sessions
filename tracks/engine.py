from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique


class TracksEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def list_all(self):
        conn = self._get_db()
        rows = conn.execute(
            "SELECT * FROM inspiring_tracks ORDER BY artist, title"
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def add(self, title, artist, album, year, tags, notes, url):
        conn = self._get_db()
        conn.execute(
            "INSERT INTO inspiring_tracks (title, artist, album, year, tags, notes, url) VALUES (?,?,?,?,?,?,?)",
            (title, artist, album, year, tags, notes, url)
        )
        conn.commit()
        conn.close()

    def edit(self, id_, title, artist, album, year, tags, notes, url):
        conn = self._get_db()
        conn.execute(
            "UPDATE inspiring_tracks SET title=?,artist=?,album=?,year=?,tags=?,notes=?,url=? WHERE id=?",
            (title, artist, album, year, tags, notes, url, id_)
        )
        conn.commit()
        conn.close()

    def delete(self, id_):
        conn = self._get_db()
        conn.execute("DELETE FROM inspiring_tracks WHERE id=?", (id_,))
        conn.commit()
        conn.close()
