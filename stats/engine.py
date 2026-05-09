import json
from collections import Counter
from datetime import date as _date, timedelta
from core.db import get_db


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
