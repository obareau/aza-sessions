import json
from collections import Counter
from datetime import date as _date, timedelta
from core.db import get_db


# Une moyenne sur trois sessions n'est pas une tendance, c'est trois sessions.
# En dessous de ce seuil les blocs d'évolution et de corrélation ne s'affichent
# pas du tout : mieux vaut une page plus courte qu'une courbe qui mentirait.
MIN_POINTS = 5


class StatsEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def _get_db(self):
        return get_db(self.db_path)

    def compute(self):
        conn = self._get_db()
        sessions = conn.execute("SELECT * FROM sessions").fetchall()
        sessions = [dict(s) for s in sessions]

        projects_rows = conn.execute("""
            SELECT p.title, COUNT(s.id) as cnt
            FROM projects p
            JOIN sessions s ON s.project_id = p.id
            GROUP BY p.id ORDER BY cnt DESC
        """).fetchall()
        conn.close()

        total = len(sessions)
        if total == 0:
            return None

        def count_items(field):
            counter = Counter()
            for s in sessions:
                val = s[field] or ""
                for item in [x.strip() for x in val.split(",") if x.strip()]:
                    counter[item] += 1
            return dict(counter.most_common(15))

        ratings   = [s["rating"] or 0 for s in sessions]
        rating_dist = {str(i): ratings.count(i) for i in range(1, 6)}

        energies  = [s["energy_level"] or 0 for s in sessions]
        energy_dist = {str(i): energies.count(i) for i in range(1, 4)}

        monthly = Counter()
        for s in sessions:
            if s["date"]:
                monthly[s["date"][:7]] += 1
        monthly_sorted = dict(sorted(monthly.items()))
        this_month = monthly.get(_date.today().isoformat()[:7], 0)

        modes      = Counter(s["mode"]      for s in sessions if s["mode"])
        intentions = Counter(s["intention"] for s in sessions if s["intention"])

        projects_dist = {r["title"]: r["cnt"] for r in projects_rows}

        release_count = sum(1 for s in sessions if s["release_potential"])
        rework_count  = sum(1 for s in sessions if s["to_rework"])

        durations   = [s["duration_min"] for s in sessions if s["duration_min"]]
        avg_duration = round(sum(durations) / len(durations)) if durations else 0

        heatmap = {}
        for s in sessions:
            if s["date"]:
                day = s["date"][:10]
                heatmap[day] = heatmap.get(day, 0) + 1

        today_d = _date.today()
        streak, max_streak, cur = 0, 0, 0
        d = today_d
        while True:
            if heatmap.get(d.isoformat(), 0) > 0:
                cur += 1
                if d == today_d or d == today_d - timedelta(days=1):
                    streak = cur
            else:
                max_streak = max(max_streak, cur)
                cur = 0
                if d < today_d - timedelta(days=365):
                    break
            d -= timedelta(days=1)
        max_streak = max(max_streak, cur)

        # ── Évolution temporelle ──
        # Moyennes par mois : la note dit si ça progresse, l'énergie dit dans
        # quel état on joue. Un mois sans donnée est absent, pas à zéro — zéro
        # voudrait dire « mauvais », alors que ça veut dire « pas renseigné ».
        def moyenne_par_mois(field):
            par_mois = {}
            for s in sessions:
                if s["date"] and s[field]:
                    par_mois.setdefault(s["date"][:7], []).append(s[field])
            return {m: round(sum(v) / len(v), 2)
                    for m, v in sorted(par_mois.items())}

        notees   = [s for s in sessions if s["rating"]]
        energees = [s for s in sessions if s["energy_level"]]
        monthly_rating = moyenne_par_mois("rating")   if len(notees)   >= MIN_POINTS else {}
        monthly_energy = moyenne_par_mois("energy_level") if len(energees) >= MIN_POINTS else {}

        # ── Corrélations ──
        # Nuage brut plutôt qu'un coefficient : sur cette taille d'échantillon
        # un r de Pearson donnerait une précision qu'on n'a pas. L'œil voit le
        # groupe, ou voit qu'il n'y a rien à voir.
        nuage = [{"x": s["duration_min"], "y": s["rating"]}
                 for s in sessions if s["duration_min"] and s["rating"]]
        duration_rating = nuage if len(nuage) >= MIN_POINTS else []

        par_heure = {}
        for s in sessions:
            # 'YYYY-MM-DDTHH:MM' — pas d'heure, pas de point.
            if s["energy_level"] and s["date"] and len(s["date"]) >= 13:
                par_heure.setdefault(int(s["date"][11:13]), []).append(s["energy_level"])
        energy_by_hour = ({f"{h:02d}h": round(sum(v) / len(v), 2)
                           for h, v in sorted(par_heure.items())}
                          if len(energees) >= MIN_POINTS else {})

        machines = count_items("machines")
        best    = max(sessions, key=lambda s: (s["rating"] or 0, s["duration_min"] or 0))
        longest = max(sessions, key=lambda s: s["duration_min"] or 0)
        top_machine = max(machines, key=machines.get) if machines else None

        return {
            "total":          total,
            "avg_duration":   avg_duration,
            "release_count":  release_count,
            "rework_count":   rework_count,
            "machines":       machines,
            "effects":        count_items("effects"),
            "daws":           count_items("daws"),
            "synths_ios":     count_items("synths_ios"),
            "plugins":        count_items("plugins"),
            "influences":     count_items("influences"),
            "characters":     count_items("character"),
            "rating_dist":    rating_dist,
            "energy_dist":    energy_dist,
            "monthly":        monthly_sorted,
            "modes":          dict(modes.most_common()),
            "intentions":     dict(intentions.most_common()),
            "projects":       projects_dist,
            "heatmap":        heatmap,
            "streak":         streak,
            "max_streak":     max_streak,
            "total_min":      sum(durations),
            "monthly_rating":  monthly_rating,
            "monthly_energy":  monthly_energy,
            "duration_rating": duration_rating,
            "energy_by_hour":  energy_by_hour,
            "min_points":      MIN_POINTS,
            "this_month":      this_month,
            "records": {
                "best_id":          best["id"],
                "best_date":        best["date"][:10],
                "best_rating":      best["rating"] or 0,
                "longest_id":       longest["id"],
                "longest_date":     longest["date"][:10],
                "longest_min":      longest["duration_min"] or 0,
                "top_machine":      top_machine,
                "top_machine_count": machines.get(top_machine, 0) if top_machine else 0,
            },
        }
