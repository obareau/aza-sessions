import random
from collections import Counter
from core.db import get_db
from core.oblique import rand_oblique as _rand_oblique

CHARACTERS = ["Drone","Rythmique","Texturé","Mélodique","Noise","Ambient","Industriel","Génératif","Percussif"]
INTENTIONS = ["Exploration","B.O AZA","Exercice technique","Défouloir","Jam","Post-prod"]


class SparkEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def rand_oblique(self):
        return _rand_oblique(self.db_path)

    def suggestions(self):
        conn = self._get_db()
        sessions = conn.execute("SELECT * FROM sessions ORDER BY date DESC").fetchall()
        total = len(sessions)
        result = []

        if total >= 3:
            def count_field(field):
                c = Counter()
                for s in sessions:
                    for item in [x.strip() for x in (s[field] or "").split(",") if x.strip()]:
                        c[item] += 1
                return c

            machines_count = count_field("machines")
            effects_count  = count_field("effects")
            ios_count      = count_field("synths_ios")

            threshold = max(1, total * 0.25)

            underused_machines = [k for k, v in machines_count.items() if v < threshold]
            underused_effects  = [k for k, v in effects_count.items()  if v < threshold]
            underused_ios      = [k for k, v in ios_count.items()      if v < threshold]

            if underused_machines:
                pick = random.choice(underused_machines)
                n = machines_count[pick]
                result.append({
                    "icon": "⚙", "type": "Machine sous-utilisée",
                    "text": f"<strong>{pick}</strong>",
                    "sub": f"Utilisée dans seulement {n} session{'s' if n>1 else ''} sur {total}"
                })
            if underused_effects:
                pick = random.choice(underused_effects)
                result.append({
                    "icon": "~", "type": "Effet hardware oublié",
                    "text": f"<strong>{pick}</strong>",
                    "sub": f"Utilisé dans {effects_count[pick]} session{'s' if effects_count[pick]>1 else ''} sur {total}"
                })
            if underused_ios:
                pick = random.choice(underused_ios)
                result.append({
                    "icon": "📱", "type": "Synthé iOS à explorer",
                    "text": f"<strong>{pick}</strong>",
                    "sub": f"Utilisé dans {ios_count[pick]} session{'s' if ios_count[pick]>1 else ''} sur {total}"
                })

            used_intentions = {s["intention"] for s in sessions if s["intention"]}
            unused_intentions = [i for i in INTENTIONS if i not in used_intentions]
            if unused_intentions:
                pick = random.choice(unused_intentions)
                result.append({
                    "icon": "◎", "type": "Intention jamais explorée",
                    "text": f"<strong>{pick}</strong>",
                    "sub": "Tu n'as jamais enregistré de session avec cette intention"
                })

            used_chars = set()
            for s in sessions:
                for c in (s["character"] or "").split(","):
                    used_chars.add(c.strip())
            unused_chars = [c for c in CHARACTERS if c not in used_chars]
            if unused_chars:
                pick = random.choice(unused_chars)
                result.append({
                    "icon": "◈", "type": "Caractère sonore inexploré",
                    "text": f"<strong>{pick}</strong>",
                    "sub": "Aucune session avec ce caractère dans ta base"
                })

        unmastered = conn.execute(
            "SELECT * FROM mirack_modules WHERE mastered=0 ORDER BY RANDOM() LIMIT 2"
        ).fetchall()
        for m in unmastered:
            result.append({
                "icon": "⬡", "type": "Module MiRack à maîtriser",
                "text": f"<strong>{m['name']}</strong>",
                "sub": m["category"] or "Module non classifié"
            })

        inspi = conn.execute("SELECT * FROM inspirations ORDER BY RANDOM() LIMIT 1").fetchone()
        if inspi:
            result.append({
                "icon": "∴", "type": f"Inspiration — {inspi['type']}",
                "text": f"« {inspi['content']} »",
                "sub": inspi["source"] or ""
            })

        track = conn.execute("SELECT * FROM inspiring_tracks ORDER BY RANDOM() LIMIT 1").fetchone()
        if track:
            result.append({
                "icon": "♪", "type": "Réécoute ce morceau",
                "text": f"<strong>{track['title']}</strong>" + (f" — {track['artist']}" if track["artist"] else ""),
                "sub": track["notes"] or (track["tags"] or "")
            })

        oblique_text = self.rand_oblique()
        result.append({
            "icon": "∴", "type": "Stratégie AZA",
            "text": f"<em>{oblique_text}</em>",
            "sub": "Laisse la machine te guider"
        })

        conn.close()
        random.shuffle(result)
        return {"suggestions": result, "total": total}

    def focus(self):
        conn = self._get_db()
        sessions = conn.execute("SELECT * FROM sessions ORDER BY date DESC").fetchall()
        total = len(sessions)

        pool = []

        for _ in range(3):
            pool.append({"icon": "∴", "type": "Stratégie AZA",
                         "text": self.rand_oblique(), "sub": ""})

        if total >= 3:
            def count_field(f):
                c = Counter()
                for s in sessions:
                    for item in [x.strip() for x in (s[f] or "").split(",") if x.strip()]:
                        c[item] += 1
                return c

            threshold = max(1, total * 0.25)
            mc = count_field("machines")
            underused = [k for k, v in mc.items() if v < threshold]
            if underused:
                pick = random.choice(underused)
                pool.append({"icon": "⚙", "type": "Machine à sortir du placard",
                             "text": pick,
                             "sub": f"{mc[pick]} session{'s' if mc[pick]>1 else ''} sur {total}"})

            used_intentions = {s["intention"] for s in sessions if s["intention"]}
            unused = [i for i in INTENTIONS if i not in used_intentions]
            if unused:
                pool.append({"icon": "◎", "type": "Intention jamais explorée",
                             "text": random.choice(unused), "sub": ""})

            used_chars = set()
            for s in sessions:
                for c in (s["character"] or "").split(","):
                    used_chars.add(c.strip())
            unused_c = [c for c in CHARACTERS if c not in used_chars]
            if unused_c:
                pool.append({"icon": "◈", "type": "Caractère sonore inexploré",
                             "text": random.choice(unused_c), "sub": ""})

        unmastered = conn.execute(
            "SELECT * FROM mirack_modules WHERE mastered=0 ORDER BY RANDOM() LIMIT 1"
        ).fetchone()
        if unmastered:
            pool.append({"icon": "⬡", "type": "Module MiRack à maîtriser",
                         "text": unmastered["name"],
                         "sub": unmastered["category"] or ""})

        inspi = conn.execute("SELECT * FROM inspirations ORDER BY RANDOM() LIMIT 1").fetchone()
        if inspi:
            pool.append({"icon": "∴", "type": f"Inspiration — {inspi['type']}",
                         "text": f"« {inspi['content']} »",
                         "sub": inspi["source"] or ""})

        conn.close()
        return random.choice(pool) if pool else {
            "icon": "∴", "type": "Stratégie",
            "text": "La machine ne ment pas. Elle déforme.", "sub": ""
        }
