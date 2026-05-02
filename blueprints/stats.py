import json
from collections import Counter
from datetime import date as _date, timedelta

from flask_login import login_required

from flask import Blueprint, render_template

from constants import VERSION
from db import get_db
from helpers import rand_oblique

bp = Blueprint("stats", __name__)


@bp.route("/stats")
@login_required
def stats():
    conn = get_db()
    sessions = conn.execute("SELECT * FROM sessions").fetchall()
    conn.close()

    total = len(sessions)
    if total == 0:
        return render_template("stats.html", version=VERSION,
                               oblique=rand_oblique(), stats_data=None, total=0)

    def count_items(field):
        counter = Counter()
        for s in sessions:
            val = s[field] or ""
            for item in [x.strip() for x in val.split(",") if x.strip()]:
                counter[item] += 1
        return dict(counter.most_common(15))

    ratings = [s["rating"] or 0 for s in sessions]
    rating_dist = {str(i): ratings.count(i) for i in range(1, 6)}

    energies = [s["energy_level"] or 0 for s in sessions]
    energy_dist = {str(i): energies.count(i) for i in range(1, 4)}

    monthly = Counter()
    for s in sessions:
        if s["date"]:
            month = s["date"][:7]
            monthly[month] += 1
    monthly_sorted = dict(sorted(monthly.items()))

    modes = Counter(s["mode"] for s in sessions if s["mode"])
    intentions = Counter(s["intention"] for s in sessions if s["intention"])

    conn2 = get_db()
    projects_rows = conn2.execute("""
        SELECT p.title, COUNT(s.id) as cnt
        FROM projects p
        JOIN sessions s ON s.project_id = p.id
        GROUP BY p.id ORDER BY cnt DESC
    """).fetchall()
    conn2.close()
    projects_dist = {r["title"]: r["cnt"] for r in projects_rows}

    release_count = sum(1 for s in sessions if s["release_potential"])
    rework_count  = sum(1 for s in sessions if s["to_rework"])

    durations = [s["duration_min"] for s in sessions if s["duration_min"]]
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

    best     = max(sessions, key=lambda s: (s["rating"] or 0, s["duration_min"] or 0))
    longest  = max(sessions, key=lambda s: s["duration_min"] or 0)
    top_machine = max(count_items("machines"), key=count_items("machines").get) if count_items("machines") else None

    stats_data = {
        "total": total,
        "avg_duration": avg_duration,
        "release_count": release_count,
        "rework_count": rework_count,
        "machines": count_items("machines"),
        "effects": count_items("effects"),
        "daws": count_items("daws"),
        "synths_ios": count_items("synths_ios"),
        "plugins": count_items("plugins"),
        "influences": count_items("influences"),
        "characters": count_items("character"),
        "rating_dist": rating_dist,
        "energy_dist": energy_dist,
        "monthly": monthly_sorted,
        "modes": dict(modes.most_common()),
        "intentions": dict(intentions.most_common()),
        "projects": projects_dist,
        "heatmap": heatmap,
        "streak": streak,
        "max_streak": max_streak,
        "total_min": sum(durations),
        "records": {
            "best_id": best["id"], "best_date": best["date"][:10],
            "best_rating": best["rating"] or 0,
            "longest_id": longest["id"], "longest_date": longest["date"][:10],
            "longest_min": longest["duration_min"] or 0,
            "top_machine": top_machine,
            "top_machine_count": count_items("machines").get(top_machine, 0) if top_machine else 0,
        },
    }

    return render_template("stats.html", version=VERSION,
                           oblique=rand_oblique(),
                           stats_data=json.dumps(stats_data),
                           stats=stats_data, total=total)
