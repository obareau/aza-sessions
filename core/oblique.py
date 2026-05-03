import random
from .db import get_db

_FALLBACK = "La machine ne ment pas. Elle déforme."


def rand_oblique(db_path):
    conn = get_db(db_path)
    rows = conn.execute("SELECT text FROM obliques WHERE active=1").fetchall()
    conn.close()
    if not rows:
        return _FALLBACK
    return random.choice(rows)["text"]
