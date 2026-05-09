from datetime import datetime
from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique
from core.constants import ITEM_TYPES, MODES, INTENTIONS


class LiveEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def get(self):
        conn = self._get_db()
        ls = conn.execute("SELECT * FROM live_session LIMIT 1").fetchone()
        conn.close()
        return dict(ls) if ls else None

    def get_catalogue(self):
        conn = self._get_db()
        rows = conn.execute(
            "SELECT * FROM catalogue WHERE active=1 ORDER BY type, name"
        ).fetchall()
        conn.close()
        result = {k: [] for k in ITEM_TYPES}
        for r in rows:
            if r["type"] in result:
                result[r["type"]].append(dict(r))
        return result

    def get_projects(self):
        conn = self._get_db()
        rows = conn.execute("SELECT * FROM projects ORDER BY title").fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def start(self, mode, intention, project_id):
        conn = self._get_db()
        conn.execute("DELETE FROM live_session")
        oblique = self.rand_oblique()
        conn.execute("""
            INSERT INTO live_session (id, started_at, oblique, mode, intention, project_id)
            VALUES (1, ?, ?, ?, ?, ?)
        """, (
            datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            oblique,
            mode or "",
            intention or "",
            project_id or None,
        ))
        conn.commit()
        conn.close()

    def save(self, data):
        conn = self._get_db()
        conn.execute("""
            UPDATE live_session SET
                notes_live=?, machines=?, effects=?, daws=?,
                synths_ios=?, plugins=?, mode=?, intention=?
            WHERE id=1
        """, (
            data.get("notes_live", ""),
            data.get("machines", ""),
            data.get("effects", ""),
            data.get("daws", ""),
            data.get("synths_ios", ""),
            data.get("plugins", ""),
            data.get("mode", ""),
            data.get("intention", ""),
        ))
        conn.commit()
        conn.close()

    def abandon(self):
        conn = self._get_db()
        conn.execute("DELETE FROM live_session")
        conn.commit()
        conn.close()
