from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique


class ProjectsEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def list_all(self):
        conn = self._get_db()
        projects = conn.execute("SELECT * FROM projects ORDER BY title").fetchall()
        counts = {}
        for p in projects:
            n = conn.execute(
                "SELECT COUNT(*) FROM sessions WHERE project_id=?", (p["id"],)
            ).fetchone()[0]
            counts[p["id"]] = n
        conn.close()
        return [dict(p) for p in projects], counts

    def get(self, pid):
        conn = self._get_db()
        project = conn.execute("SELECT * FROM projects WHERE id=?", (pid,)).fetchone()
        conn.close()
        return dict(project) if project else None

    def get_with_sessions(self, pid):
        conn = self._get_db()
        project = conn.execute("SELECT * FROM projects WHERE id=?", (pid,)).fetchone()
        if not project:
            conn.close()
            return None, []
        sessions = conn.execute(
            "SELECT * FROM sessions WHERE project_id=? ORDER BY date DESC", (pid,)
        ).fetchall()
        conn.close()
        return dict(project), [dict(s) for s in sessions]

    def create(self, title, description, color):
        conn = self._get_db()
        conn.execute(
            "INSERT INTO projects (title, description, color) VALUES (?,?,?)",
            (title, description, color)
        )
        conn.commit()
        conn.close()

    def update(self, pid, title, description, color):
        conn = self._get_db()
        conn.execute(
            "UPDATE projects SET title=?, description=?, color=? WHERE id=?",
            (title, description, color, pid)
        )
        conn.commit()
        conn.close()

    def delete(self, pid):
        conn = self._get_db()
        conn.execute("UPDATE sessions SET project_id=NULL WHERE project_id=?", (pid,))
        conn.execute("DELETE FROM projects WHERE id=?", (pid,))
        conn.commit()
        conn.close()
