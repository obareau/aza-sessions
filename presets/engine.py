from core.db import get_db


class PresetsEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def list_all(self, catalogue_id=None, q=None):
        conn = self._get_db()
        base = """
            SELECT pn.*, c.name as cat_name, c.type as cat_type,
                   c.manufacturer as cat_manufacturer,
                   inf.name as influence_name
            FROM preset_notes pn
            LEFT JOIN catalogue c ON pn.catalogue_id = c.id
            LEFT JOIN influences inf ON pn.influence_id = inf.id
        """
        where, params = [], []
        if catalogue_id:
            where.append("pn.catalogue_id = ?")
            params.append(catalogue_id)
        sql = base + (" WHERE " + " AND ".join(where) if where else "") + " ORDER BY pn.date DESC"
        rows = conn.execute(sql, params).fetchall()
        conn.close()
        result = [dict(r) for r in rows]
        if q:
            q_low = q.lower()
            result = [n for n in result if
                      q_low in (n.get("preset_name") or "").lower() or
                      q_low in (n.get("evocation") or "").lower() or
                      q_low in (n.get("song_idea") or "").lower() or
                      q_low in (n.get("tags") or "").lower() or
                      q_low in (n.get("notes") or "").lower() or
                      q_low in (n.get("cat_name") or "").lower() or
                      q_low in (n.get("influence_name") or "").lower()]
        return result

    def get(self, note_id):
        conn = self._get_db()
        row = conn.execute("""
            SELECT pn.*, c.name as cat_name, c.type as cat_type,
                   c.manufacturer as cat_manufacturer,
                   inf.name as influence_name
            FROM preset_notes pn
            LEFT JOIN catalogue c ON pn.catalogue_id = c.id
            LEFT JOIN influences inf ON pn.influence_id = inf.id
            WHERE pn.id = ?
        """, (note_id,)).fetchone()
        conn.close()
        return dict(row) if row else None

    def create(self, data):
        conn = self._get_db()
        conn.execute("""
            INSERT INTO preset_notes
            (date, catalogue_id, preset_name, evocation, song_idea,
             influence_id, rating, tags, session_id, notes)
            VALUES (?,?,?,?,?,?,?,?,?,?)
        """, (
            data["date"], data.get("catalogue_id") or None,
            data["preset_name"],
            data.get("evocation") or None, data.get("song_idea") or None,
            data.get("influence_id") or None, data.get("rating") or None,
            data.get("tags") or None, data.get("session_id") or None,
            data.get("notes") or None,
        ))
        conn.commit()
        conn.close()

    def update(self, note_id, data):
        conn = self._get_db()
        conn.execute("""
            UPDATE preset_notes SET
            date=?, catalogue_id=?, preset_name=?, evocation=?, song_idea=?,
            influence_id=?, rating=?, tags=?, session_id=?, notes=?
            WHERE id=?
        """, (
            data["date"], data.get("catalogue_id") or None,
            data["preset_name"],
            data.get("evocation") or None, data.get("song_idea") or None,
            data.get("influence_id") or None, data.get("rating") or None,
            data.get("tags") or None, data.get("session_id") or None,
            data.get("notes") or None,
            note_id,
        ))
        conn.commit()
        conn.close()

    def delete(self, note_id):
        conn = self._get_db()
        conn.execute("DELETE FROM preset_notes WHERE id=?", (note_id,))
        conn.commit()
        conn.close()

    def stats(self):
        conn = self._get_db()
        rows = conn.execute("""
            SELECT pn.catalogue_id, c.name as cat_name, c.type as cat_type,
                   c.manufacturer as cat_manufacturer,
                   COUNT(pn.id) as count,
                   AVG(CAST(pn.rating AS REAL)) as avg_rating,
                   MAX(pn.date) as last_date
            FROM preset_notes pn
            LEFT JOIN catalogue c ON pn.catalogue_id = c.id
            GROUP BY pn.catalogue_id
            ORDER BY count DESC
        """).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def top_presets(self, limit=10):
        conn = self._get_db()
        rows = conn.execute("""
            SELECT pn.*, c.name as cat_name, c.type as cat_type,
                   c.manufacturer as cat_manufacturer,
                   inf.name as influence_name
            FROM preset_notes pn
            LEFT JOIN catalogue c ON pn.catalogue_id = c.id
            LEFT JOIN influences inf ON pn.influence_id = inf.id
            WHERE pn.rating IS NOT NULL
            ORDER BY pn.rating DESC, pn.date DESC
            LIMIT ?
        """, (limit,)).fetchall()
        conn.close()
        return [dict(r) for r in rows]
