import json
from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique


class DimEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def list_scripts(self):
        conn = self._get_db()
        rows = conn.execute(
            "SELECT * FROM prompter_scripts ORDER BY created_at DESC"
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def get_script(self, sid):
        conn = self._get_db()
        row = conn.execute(
            "SELECT * FROM prompter_scripts WHERE id=?", (sid,)
        ).fetchone()
        conn.close()
        return dict(row) if row else None

    def save(self, sid, title, description, cues):
        """Create or update a script. cues is a list of dicts. Returns the row id."""
        cues_json = json.dumps(cues, ensure_ascii=False)
        conn = self._get_db()
        if sid:
            conn.execute(
                "UPDATE prompter_scripts SET title=?, description=?, cues=? WHERE id=?",
                (title, description, cues_json, sid)
            )
            conn.commit()
            conn.close()
            return sid
        else:
            conn.execute(
                "INSERT INTO prompter_scripts (title, description, cues) VALUES (?,?,?)",
                (title, description, cues_json)
            )
            conn.commit()
            new_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]
            conn.close()
            return new_id

    def delete(self, sid):
        conn = self._get_db()
        conn.execute("DELETE FROM prompter_scripts WHERE id=?", (sid,))
        conn.commit()
        conn.close()

    def export_json(self, sid):
        """Returns (json_str, filename) or None if script not found."""
        script = self.get_script(sid)
        if not script:
            return None
        payload = {
            "title":       script["title"],
            "description": script["description"] or "",
            "cues":        json.loads(script["cues"])
        }
        data = json.dumps(payload, ensure_ascii=False, indent=2)
        filename = script["title"].lower().replace(" ", "_")[:40] + ".json"
        return data, filename

    def export_md(self, sid):
        """Returns (markdown_str, filename) or None if script not found."""
        script = self.get_script(sid)
        if not script:
            return None
        cues = json.loads(script["cues"])
        lines = [f"# {script['title']}"]
        if script["description"]:
            lines.append(f"\n> {script['description']}\n")
        lines.append("\n| Temps  | Patch | Action | Couleur |")
        lines.append("|--------|-------|--------|---------|")
        for c in cues:
            t   = c.get("time_fmt") or "—"
            p   = (c.get("patch")  or "—").replace("|", "\\|")
            a   = (c.get("action") or "—").replace("|", "\\|")
            col = c.get("color") or "default"
            lines.append(f"| {t} | {p} | {a} | {col} |")
        data = "\n".join(lines) + "\n"
        filename = script["title"].lower().replace(" ", "_")[:40] + ".md"
        return data, filename

    def import_raw(self, raw, filename):
        """Parse raw file content. Returns (title, description, cues) or raises ValueError."""
        if filename.endswith(".md") or filename.endswith(".txt"):
            return self._parse_md(raw)
        return self._parse_json(raw)

    # ── private parsers ──────────────────────────────────────────────────────

    def _parse_json(self, raw):
        payload = json.loads(raw)
        title       = payload.get("title", "Script importé")
        description = payload.get("description", "")
        cues = []
        for c in payload.get("cues", []):
            cues.append({
                "time_fmt": c.get("time_fmt", ""),
                "time_s":   int(c.get("time_s", 0)),
                "patch":    c.get("patch",  ""),
                "action":   c.get("action", ""),
                "color":    c.get("color",  "default")
            })
        return title or "Script importé", description, cues

    def _parse_md(self, raw):
        title, description, cues = "", "", []
        for line in raw.splitlines():
            line = line.strip()
            if line.startswith("# ") and not title:
                title = line[2:].strip()
            elif line.startswith("> ") and not description:
                description = line[2:].strip()
            elif line.startswith("|") and not line.startswith("|---"):
                cells = [c.strip() for c in line.strip("|").split("|")]
                if len(cells) >= 3 and cells[0] != "Temps":
                    t_fmt  = cells[0] if cells[0] != "—" else ""
                    patch  = cells[1] if cells[1] != "—" else ""
                    action = cells[2] if cells[2] != "—" else ""
                    color  = cells[3] if len(cells) > 3 and cells[3] not in ("—", "Couleur") else "default"
                    secs = 0
                    if t_fmt:
                        parts = t_fmt.split(":")
                        try:
                            secs = int(parts[0]) * 60 + int(parts[1]) if len(parts) == 2 else int(parts[0])
                        except ValueError:
                            secs = 0
                    cues.append({"time_fmt": t_fmt, "time_s": secs,
                                 "patch": patch, "action": action, "color": color})
        return title or "Script importé", description, cues

    @staticmethod
    def parse_form_cues(times, patches, actions, colors):
        """Convert parallel form lists into a cues list."""
        cues = []
        for t, p, a, c in zip(times, patches, actions, colors):
            if p.strip() or a.strip():
                secs = 0
                if t.strip():
                    parts = t.strip().split(":")
                    try:
                        secs = int(parts[0]) * 60 + int(parts[1]) if len(parts) == 2 else int(parts[0])
                    except ValueError:
                        secs = 0
                cues.append({"time_s": secs, "time_fmt": t.strip(),
                             "patch": p.strip(), "action": a.strip(),
                             "color": c or "default"})
        return cues
