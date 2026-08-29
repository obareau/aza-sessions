import csv
import io
from datetime import datetime
from core.db import get_db
from core.constants import ITEM_TYPES, SESSION_TYPES


def session_to_md(s, version=""):
    project_line = f"\n**Projet:** {s['project_title']}" if s['project_title'] else ""
    type_label = SESSION_TYPES.get(s.get("session_type") or "music", "Musique")
    return f"""# Session {s['date']}

**Type:** {type_label}
**Mode:** {s['mode'] or '—'}
**Intention:** {s['intention'] or '—'}
**Durée:** {s['duration_min'] or '—'} min
**Énergie:** {'⚡' * (s['energy_level'] or 0)}
**Note:** {'★' * (s['rating'] or 0)}{project_line}

## Machines
{s['machines'] or '—'}

## Effets hardware
{s['effects'] or '—'}

## DAW
{s['daws'] or '—'}

## Synthés iOS
{s['synths_ios'] or '—'}

## Apps iPad
{s.get('ipad') or '—'}

## Zynthian / Raspberry Pi
{s.get('zynthian') or '—'}

## Plugins
{s['plugins'] or '—'}

## Signal routing
{s['signal_routing'] or '—'}

## Algo MicroFreak
{s['microfreak_algo'] or '—'}

## Patches / Presets
{s['patches'] or '—'}

## Caractère sonore
{s['character'] or '—'}

## Timestamps intéressants
{s['timestamps'] or '—'}

## Fichier audio
{s['audio_file'] or '—'}

## Tags
{s['tags'] or '—'}

## Influences
{s['influences'] or '—'}

## Lien lore AZA
{s['lore_link'] or '—'}

## Stratégie AZA
> {s['oblique'] or '—'}

## Notes libres
{s['comments'] or '—'}

## Récap session Claude
{s['recap_claude'] or '—'}

---
*À retravailler: {'Oui' if s['to_rework'] else 'Non'} | Potentiel release: {'Oui' if s['release_potential'] else 'Non'}*
*Journal de Sessions AZA v{version}*
"""


def _chunk_list(lst, n):
    lst = list(lst)
    return [lst[i:i+n] for i in range(0, len(lst), n)]


def catalogue_blocks(catalogue, block_size=16):
    LABELS = {k: v for k, v in ITEM_TYPES.items()}
    blocks = []
    for key, label in LABELS.items():
        items = list(catalogue.get(key, []))
        if not items:
            continue
        chunks = _chunk_list(items, block_size)
        n = len(chunks)
        for i, chunk in enumerate(chunks):
            suffix = f" {i+1}/{n}" if n > 1 else ""
            blocks.append({'title': label + suffix, 'entries': chunk, 'add_line': (i == n-1)})
    return blocks


def influence_blocks(influences, block_size=20):
    items = list(influences)
    if not items:
        return []
    chunks = _chunk_list(items, block_size)
    n = len(chunks)
    return [{'title': f"Influences de session{f' {i+1}/{n}' if n > 1 else ''}",
             'entries': chunk, 'add_line': (i == n-1)}
            for i, chunk in enumerate(chunks)]


class SessionsEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def list_all(self):
        conn = self._get_db()
        rows = conn.execute("""
            SELECT s.*, p.title AS project_title, p.color AS project_color
            FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
            ORDER BY s.date DESC
        """).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def list_page(self, page=1, per_page=25):
        conn = self._get_db()
        total = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        offset = (page - 1) * per_page
        rows = conn.execute("""
            SELECT s.*, p.title AS project_title, p.color AS project_color
            FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
            ORDER BY s.date DESC LIMIT ? OFFSET ?
        """, (per_page, offset)).fetchall()
        conn.close()
        return [dict(r) for r in rows], total

    def get(self, sid):
        conn = self._get_db()
        row = conn.execute("""
            SELECT s.*, p.title AS project_title, p.color AS project_color, p.id AS project_id_val
            FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
            WHERE s.id = ?
        """, (sid,)).fetchone()
        linked = None
        if row and row["linked_session"]:
            linked = conn.execute("SELECT * FROM sessions WHERE id=?", (row["linked_session"],)).fetchone()
            linked = dict(linked) if linked else None
        conn.close()
        return (dict(row) if row else None), linked

    def get_plain(self, sid):
        conn = self._get_db()
        row = conn.execute("SELECT * FROM sessions WHERE id=?", (sid,)).fetchone()
        conn.close()
        return dict(row) if row else None

    def set_recap(self, sid, text):
        """Écrit le seul champ recap_claude — pas un update() complet.

        Passer par update() obligerait à relire puis réécrire les 31 colonnes
        pour n'en changer qu'une, et écraserait toute modification concurrente.
        """
        conn = self._get_db()
        conn.execute("UPDATE sessions SET recap_claude=? WHERE id=?", (text, sid))
        conn.commit()
        conn.close()

    def create(self, data, from_live=False):
        conn = self._get_db()
        conn.execute("""
            INSERT INTO sessions (
                session_type, title, date, duration_min, mode, intention, energy_level,
                machines, effects, daws, synths_ios, ipad, zynthian, plugins,
                patches, audio_file, timestamps, rating, tags,
                character, lore_link, to_rework, release_potential,
                tempo, tonality, signal_routing, microfreak_algo,
                linked_session, influences, oblique, comments, recap_claude, project_id
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, (
            data.get("session_type") or "music",
            data.get("title", "").strip(),
            data.get("date", datetime.now().strftime("%Y-%m-%d %H:%M")),
            data.get("duration_min") or None,
            data.get("mode"), data.get("intention"),
            data.get("energy_level") or None,
            data.get("machines", ""), data.get("effects", ""),
            data.get("daws", ""), data.get("synths_ios", ""),
            data.get("ipad", ""), data.get("zynthian", ""),
            data.get("plugins", ""), data.get("patches"),
            data.get("audio_file"), data.get("timestamps"),
            data.get("rating") or None, data.get("tags"),
            data.get("character", ""), data.get("lore_link"),
            1 if data.get("to_rework") else 0,
            1 if data.get("release_potential") else 0,
            data.get("tempo"), data.get("tonality"),
            data.get("signal_routing"), data.get("microfreak_algo"),
            data.get("linked_session") or None,
            data.get("influences", ""), data.get("oblique"),
            data.get("comments"), data.get("recap_claude"),
            data.get("project_id") or None,
        ))
        new_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
        if from_live:
            conn.execute("DELETE FROM live_session")
        conn.commit()
        conn.close()
        return new_id

    def update(self, sid, data):
        conn = self._get_db()
        conn.execute("""
            UPDATE sessions SET
                session_type=?, title=?, date=?, duration_min=?, mode=?, intention=?, energy_level=?,
                machines=?, effects=?, daws=?, synths_ios=?, ipad=?, zynthian=?, plugins=?,
                patches=?, audio_file=?, timestamps=?, rating=?, tags=?,
                character=?, lore_link=?, to_rework=?, release_potential=?,
                tempo=?, tonality=?, signal_routing=?, microfreak_algo=?,
                linked_session=?, influences=?, oblique=?, comments=?, recap_claude=?,
                project_id=?
            WHERE id=?
        """, (
            data.get("session_type") or "music",
            data.get("title", "").strip(), data.get("date"),
            data.get("duration_min") or None,
            data.get("mode"), data.get("intention"),
            data.get("energy_level") or None,
            data.get("machines", ""), data.get("effects", ""),
            data.get("daws", ""), data.get("synths_ios", ""),
            data.get("ipad", ""), data.get("zynthian", ""),
            data.get("plugins", ""), data.get("patches"),
            data.get("audio_file"), data.get("timestamps"),
            data.get("rating") or None, data.get("tags"),
            data.get("character", ""), data.get("lore_link"),
            1 if data.get("to_rework") else 0,
            1 if data.get("release_potential") else 0,
            data.get("tempo"), data.get("tonality"),
            data.get("signal_routing"), data.get("microfreak_algo"),
            data.get("linked_session") or None,
            data.get("influences", ""), data.get("oblique"),
            data.get("comments"), data.get("recap_claude"),
            data.get("project_id") or None,
            sid,
        ))
        conn.commit()
        conn.close()

    def delete(self, sid):
        conn = self._get_db()
        conn.execute("DELETE FROM sessions WHERE id=?", (sid,))
        conn.commit()
        conn.close()

    def get_catalogue(self):
        conn = self._get_db()
        rows = conn.execute(
            "SELECT * FROM catalogue WHERE active=1 ORDER BY type, favorite DESC, manufacturer, name"
        ).fetchall()
        conn.close()
        result = {k: [] for k in ITEM_TYPES}
        for r in rows:
            if r["type"] in result:
                result[r["type"]].append(dict(r))
        return result

    def get_influences_active(self):
        conn = self._get_db()
        rows = conn.execute("SELECT * FROM influences WHERE active=1 ORDER BY name").fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def list_brief(self, exclude_id=None):
        conn = self._get_db()
        if exclude_id:
            rows = conn.execute(
                "SELECT id, date, machines FROM sessions WHERE id != ? ORDER BY date DESC", (exclude_id,)
            ).fetchall()
        else:
            rows = conn.execute("SELECT id, date, machines FROM sessions ORDER BY date DESC").fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def get_projects(self):
        conn = self._get_db()
        rows = conn.execute("SELECT * FROM projects ORDER BY title").fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def heatmap_data(self):
        conn = self._get_db()
        rows = conn.execute("SELECT substr(date,1,10) as day, COUNT(*) as cnt FROM sessions WHERE date IS NOT NULL GROUP BY day").fetchall()
        conn.close()
        return {r["day"]: r["cnt"] for r in rows}

    def prefill_from_live(self):
        conn = self._get_db()
        ls = conn.execute("SELECT * FROM live_session LIMIT 1").fetchone()
        conn.close()
        if not ls:
            return None
        started_at = datetime.strptime(ls["started_at"], "%Y-%m-%d %H:%M:%S")
        duration_min = max(1, int((datetime.now() - started_at).total_seconds() // 60))
        return {
            "id": None, "_from_live": True, "duration_min": duration_min,
            "started_at": ls["started_at"], "session_type": "music",
            "machines": ls["machines"] or "", "effects": ls["effects"] or "",
            "daws": ls["daws"] or "", "synths_ios": ls["synths_ios"] or "",
            "ipad": "", "zynthian": "",
            "plugins": ls["plugins"] or "", "mode": ls["mode"] or "",
            "intention": ls["intention"] or "", "oblique": ls["oblique"] or "",
            "project_id": ls["project_id"], "character": "", "influences": "",
            "notes_live": ls["notes_live"] or "",
        }

    def export_md_one(self, sid, version=""):
        conn = self._get_db()
        s = conn.execute("""
            SELECT s.*, p.title AS project_title
            FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
            WHERE s.id = ?
        """, (sid,)).fetchone()
        conn.close()
        if not s:
            return None, None
        return session_to_md(dict(s), version), f"session_{sid}.md"

    def export_md_all(self, version=""):
        conn = self._get_db()
        sessions = conn.execute("""
            SELECT s.*, p.title AS project_title
            FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
            ORDER BY s.date DESC
        """).fetchall()
        conn.close()
        now = datetime.now().strftime('%Y-%m-%d %H:%M')
        filename = f"aza_{datetime.now().strftime('%Y%m%d')}.md"
        if not sessions:
            return (f"# Journal de Sessions AZA v{version}\n\n*Exporté le {now}*\n*0 session(s)*\n\nAucune session.", filename)
        parts = [f"# Journal de Sessions AZA v{version}", f"*Exporté le {now}*",
                 f"*{len(sessions)} session(s)*\n\n---\n"]
        for s in sessions:
            parts.append(session_to_md(dict(s), version))
            parts.append("\n---\n")
        return "\n".join(parts), filename

    def export_csv(self, version=""):
        conn = self._get_db()
        sessions = conn.execute("""
            SELECT s.*, p.title AS project_title
            FROM sessions s LEFT JOIN projects p ON s.project_id = p.id
            ORDER BY s.date DESC
        """).fetchall()
        conn.close()
        cols = ["id","session_type","date","duration_min","mode","intention","energy_level","machines","effects",
                "daws","synths_ios","ipad","zynthian","plugins","patches","audio_file","timestamps","rating","tags",
                "character","lore_link","to_rework","release_potential","tempo","tonality",
                "signal_routing","microfreak_algo","influences","oblique","comments","recap_claude","project_title"]
        buf = io.StringIO()
        w = csv.writer(buf)
        w.writerow(cols)
        for s in sessions:
            w.writerow([s[c] if c in s.keys() else "" for c in cols])
        buf.seek(0)
        filename = f"aza_{datetime.now().strftime('%Y%m%d')}.csv"
        return "﻿" + buf.getvalue(), filename
