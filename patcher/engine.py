"""PatcherEngine — gestion des layouts de patching (nœuds + connexions)."""
import json
from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique

# Couleurs par type de nœud
NODE_COLORS = {
    "machine":   "#D4380D",   # orange AZA
    "effet":     "#8B0000",   # rouge sombre
    "daw":       "#1A3A6B",   # bleu nuit
    "synth_ios": "#1D5C2E",   # vert forêt
    "plugin":    "#4A1A6B",   # violet sombre
    "free":      "#3A3A3A",   # gris neutre
}

SIGNAL_COLORS = {
    "audio": "#D4380D",
    "midi":  "#2563EB",
    "cv":    "#16A34A",
    "usb":   "#9333EA",
    "autre": "#6B7280",
}


class PatcherEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    # ── LAYOUTS ──────────────────────────────────────────────────────────────

    def list_layouts(self):
        conn = self._db()
        rows = conn.execute("""
            SELECT pl.*, s.date as session_date, s.title as session_title,
                   (SELECT COUNT(*) FROM patch_nodes WHERE layout_id=pl.id) as node_count,
                   (SELECT COUNT(*) FROM patch_connections WHERE layout_id=pl.id) as conn_count
            FROM patch_layouts pl
            LEFT JOIN sessions s ON pl.session_id = s.id
            ORDER BY pl.created_at DESC
        """).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def get_layout(self, layout_id):
        conn = self._db()
        layout = conn.execute(
            "SELECT pl.*, s.date as session_date, s.title as session_title "
            "FROM patch_layouts pl LEFT JOIN sessions s ON pl.session_id=s.id "
            "WHERE pl.id=?", (layout_id,)
        ).fetchone()
        if not layout:
            conn.close()
            return None, [], []
        nodes = conn.execute(
            "SELECT * FROM patch_nodes WHERE layout_id=? ORDER BY id", (layout_id,)
        ).fetchall()
        conns = conn.execute(
            "SELECT * FROM patch_connections WHERE layout_id=? ORDER BY id", (layout_id,)
        ).fetchall()
        conn.close()
        return dict(layout), [dict(n) for n in nodes], [dict(c) for c in conns]

    def create_layout(self, name, session_id=None):
        conn = self._db()
        cur = conn.execute(
            "INSERT INTO patch_layouts (name, session_id) VALUES (?,?)",
            (name, session_id or None)
        )
        layout_id = cur.lastrowid
        conn.commit()
        conn.close()
        return layout_id

    def delete_layout(self, layout_id):
        conn = self._db()
        conn.execute("DELETE FROM patch_connections WHERE layout_id=?", (layout_id,))
        conn.execute("DELETE FROM patch_nodes WHERE layout_id=?", (layout_id,))
        conn.execute("DELETE FROM patch_layouts WHERE id=?", (layout_id,))
        conn.commit()
        conn.close()

    def update_layout_name(self, layout_id, name):
        conn = self._db()
        conn.execute("UPDATE patch_layouts SET name=? WHERE id=?", (name, layout_id))
        conn.commit()
        conn.close()

    # ── IMPORT DEPUIS SESSION / CATALOGUE ────────────────────────────────────

    def import_from_session(self, layout_id, session_id):
        """Importe les machines/FX/DAW/iOS/plugins d'une session comme nœuds."""
        conn = self._db()
        session = conn.execute("SELECT * FROM sessions WHERE id=?", (session_id,)).fetchone()
        if not session:
            conn.close()
            return 0

        # Récupérer les items actifs du catalogue pour matching
        catalogue = {}
        for row in conn.execute("SELECT * FROM catalogue WHERE active=1").fetchall():
            catalogue[row["name"].lower()] = dict(row)

        added = 0
        x, y = 120, 120
        step_x, step_y = 220, 140

        field_map = [
            ("machines",  "machine"),
            ("effects",   "effet"),
            ("daws",      "daw"),
            ("synths_ios","synth_ios"),
            ("plugins",   "plugin"),
        ]

        col = 0
        for field, node_type in field_map:
            val = session[field] or ""
            items = [i.strip() for i in val.split(",") if i.strip()]
            row_y = y + col * step_y
            for i, name in enumerate(items):
                nx = x + i * step_x
                cat_entry = catalogue.get(name.lower())
                cat_id = cat_entry["id"] if cat_entry else None
                color = NODE_COLORS.get(node_type, NODE_COLORS["free"])
                conn.execute(
                    "INSERT INTO patch_nodes (layout_id, label, x, y, node_type, catalogue_id, color) "
                    "VALUES (?,?,?,?,?,?,?)",
                    (layout_id, name, nx, row_y, node_type, cat_id, color)
                )
                added += 1
            if items:
                col += 1

        conn.commit()
        conn.close()
        return added

    def import_from_catalogue(self, layout_id, types=None):
        """Importe tous les items actifs du catalogue comme nœuds."""
        conn = self._db()
        q = "SELECT * FROM catalogue WHERE active=1"
        params = []
        if types:
            q += f" AND type IN ({','.join('?'*len(types))})"
            params = list(types)
        q += " ORDER BY type, name"
        rows = conn.execute(q, params).fetchall()

        x, y = 120, 120
        step_x, step_y = 220, 150
        type_rows = {}
        for row in rows:
            type_rows.setdefault(row["type"], []).append(dict(row))

        col = 0
        added = 0
        for node_type, items in type_rows.items():
            color = NODE_COLORS.get(node_type, NODE_COLORS["free"])
            for i, item in enumerate(items):
                conn.execute(
                    "INSERT INTO patch_nodes (layout_id, label, x, y, node_type, catalogue_id, color) "
                    "VALUES (?,?,?,?,?,?,?)",
                    (layout_id, item["name"], x + i * step_x, y + col * step_y,
                     node_type, item["id"], color)
                )
                added += 1
            col += 1

        conn.commit()
        conn.close()
        return added

    # ── SAVE (AJAX) ──────────────────────────────────────────────────────────
    def save_layout(self, layout_id, nodes, connections):
        """Sauvegarde complète nœuds + connexions depuis le front (JSON).
        Gère les IDs temporaires côté client (chaînes "tmp_…" ou entiers hors DB).
        Retourne un mapping old_id → new_real_id pour que le client puisse se resynchroniser.
        """
        conn = self._db()

        # IDs réels existant en base
        existing_ids = {r[0] for r in conn.execute(
            "SELECT id FROM patch_nodes WHERE layout_id=?", (layout_id,)
        ).fetchall()}

        id_map = {}   # old_client_id → real_db_id
        seen_ids = set()

        for n in nodes:
            raw_id = n.get("id")
            # Essayer de convertir en int ; les IDs temporaires "tmp_…" échoueront
            try:
                nid_int = int(raw_id)
            except (TypeError, ValueError):
                nid_int = None

            if nid_int and nid_int in existing_ids:
                conn.execute(
                    "UPDATE patch_nodes SET label=?,x=?,y=?,color=?,node_type=? WHERE id=?",
                    (n["label"], int(n["x"]), int(n["y"]),
                     n.get("color", "#3A3A3A"), n.get("node_type", "free"), nid_int)
                )
                seen_ids.add(nid_int)
                id_map[raw_id] = nid_int
            else:
                # Nouveau nœud (ID temp ou ID entier inconnu)
                cur = conn.execute(
                    "INSERT INTO patch_nodes "
                    "(layout_id,label,x,y,node_type,color,catalogue_id) "
                    "VALUES (?,?,?,?,?,?,?)",
                    (layout_id, n["label"], int(n["x"]), int(n["y"]),
                     n.get("node_type", "free"), n.get("color", "#3A3A3A"),
                     n.get("catalogue_id"))
                )
                real_id = cur.lastrowid
                seen_ids.add(real_id)
                id_map[raw_id] = real_id

        # Supprimer nœuds retirés
        for old_id in existing_ids - seen_ids:
            conn.execute("DELETE FROM patch_nodes WHERE id=?", (old_id,))

        # Connexions — remplacer entièrement en résolvant les IDs temporaires
        conn.execute("DELETE FROM patch_connections WHERE layout_id=?", (layout_id,))
        for c in connections:
            from_id = id_map.get(c["from_id"], c["from_id"])
            to_id   = id_map.get(c["to_id"],   c["to_id"])
            try:
                from_id = int(from_id)
                to_id   = int(to_id)
            except (TypeError, ValueError):
                continue  # connexion invalide, on ignore
            conn.execute(
                "INSERT INTO patch_connections "
                "(layout_id,from_id,to_id,label,signal_type) "
                "VALUES (?,?,?,?,?)",
                (layout_id, from_id, to_id,
                 c.get("label", ""), c.get("signal_type", "audio"))
            )

        conn.commit()
        conn.close()

    # ── CATALOGUE (pour le panneau picker) ──────────────────────────────────

    def get_catalogue_items(self):
        """Retourne tous les items actifs du catalogue, groupés par type."""
        conn = self._db()
        # manufacturer est optionnel (ajouté en v2.2.0 via ALTER TABLE)
        cols = {r[1] for r in conn.execute("PRAGMA table_info(catalogue)").fetchall()}
        select = "id, name, type" + (", manufacturer" if "manufacturer" in cols else ", '' as manufacturer")
        order  = ("type, manufacturer, name" if "manufacturer" in cols else "type, name")
        rows = conn.execute(
            f"SELECT {select} FROM catalogue WHERE active=1 ORDER BY {order}"
        ).fetchall()
        conn.close()
        groups = {}
        for r in rows:
            groups.setdefault(r["type"], []).append(dict(r))
        return groups

    # ── SESSIONS (pour le formulaire) ────────────────────────────────────────

    def get_sessions(self):
        conn = self._db()
        rows = conn.execute(
            "SELECT id, date, title, machines FROM sessions ORDER BY date DESC LIMIT 100"
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]
