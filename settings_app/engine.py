import os
import json
import sqlite3
import tempfile
from datetime import datetime
from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique


class SettingsEngine:
    def __init__(self, db_path, config_path):
        self.db_path = db_path
        self.config_path = config_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def get_config(self):
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return {}

    def save_config(self, data):
        with open(self.config_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

    def count_sessions(self):
        conn = self._get_db()
        n = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        conn.close()
        return n

    def backup_data(self):
        with open(self.db_path, "rb") as f:
            data = f.read()
        filename = f"aza_backup_{datetime.now().strftime('%Y%m%d_%H%M')}.db"
        return data, filename

    def import_db(self, tmp_path):
        """Merge sessions from tmp_path into main DB. Returns (imported, skipped, total, error)."""
        try:
            src = sqlite3.connect(tmp_path)
            src.row_factory = sqlite3.Row
            tables = [r[0] for r in src.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()]
            if "sessions" not in tables:
                src.close()
                return 0, 0, 0, "Ce fichier ne contient pas de table 'sessions'."

            src_cols = {r[1] for r in src.execute("PRAGMA table_info(sessions)").fetchall()}
            dst = self._get_db()
            dst_cols = {r[1] for r in dst.execute("PRAGMA table_info(sessions)").fetchall()}
            common = [c for c in dst_cols if c in src_cols and c not in ("id",)]

            rows = src.execute("SELECT * FROM sessions").fetchall()
            src.close()

            if not rows:
                dst.close()
                return 0, 0, 0, None  # msg: empty

            imported = 0
            skipped = 0
            for row in rows:
                exists = dst.execute(
                    "SELECT id FROM sessions WHERE date=? AND machines=?",
                    (row["date"], row["machines"])
                ).fetchone()
                if exists:
                    skipped += 1
                    continue
                cols_str = ", ".join(common)
                placeholders = ", ".join("?" for _ in common)
                vals = tuple(row[c] for c in common)
                dst.execute(f"INSERT INTO sessions ({cols_str}) VALUES ({placeholders})", vals)
                imported += 1

            dst.commit()
            total = dst.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
            dst.close()
            return imported, skipped, total, None
        except Exception as e:
            return 0, 0, 0, str(e)

    def reset_sessions(self):
        conn = self._get_db()
        conn.execute("DELETE FROM sessions")
        conn.execute("DELETE FROM sqlite_sequence WHERE name='sessions'")
        conn.commit()
        conn.close()
