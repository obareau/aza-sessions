import random
from .db import get_db

_FALLBACK = "La machine ne ment pas. Elle déforme."


def rand_oblique(db_path, exclude=None):
    conn = get_db(db_path)
    rows = conn.execute("SELECT text FROM obliques WHERE active=1").fetchall()
    conn.close()
    if not rows:
        return _FALLBACK
    pool = [r["text"] for r in rows]
    if exclude:
        filtered = [t for t in pool if t not in exclude]
        pool = filtered if filtered else pool
    return random.choice(pool)
