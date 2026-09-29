"""Le tirage du soir — un point de départ concret, pas une page de plus à remplir.

AZA sait tout ce qu'il faut pour proposer une séance : 42 fiches de matériel avec
leurs codes, 25 stratégies obliques, un générateur de titres dans l'esthétique de
l'univers, et le nom de prise du R8. Rien de tout ça ne servait *avant* de jouer —
uniquement après, pour consigner.

Le tirage assemble ces pièces : un instrument, un traitement, une contrainte, un
titre, un nom de prise. Il ne demande rien et ne retient rien : on retire tant
que ça ne dit rien, et on part jouer.
"""
import random

from core.db import get_db
from core.lore_names import propose as propose_titres
from core.oblique import rand_oblique

# Ce qui joue, et ce qui traite — les types du catalogue rangés par rôle.
INSTRUMENTS = ("machine", "synth_ios", "app_ios")
TRAITEMENTS = ("effet", "plugin", "plugin_ios")


def _actifs(conn, types) -> list[dict]:
    marques = ", ".join("?" * len(types))
    rows = conn.execute(
        f"SELECT id, name, type, code, favorite, purpose, intent FROM catalogue "
        f"WHERE active = 1 AND type IN ({marques})", types).fetchall()
    return [dict(r) for r in rows]


def tirer(db_path: str, seed=None) -> dict:
    """Un instrument, un traitement, une contrainte, un titre, un nom de prise.

    Les favoris sont tirés deux fois plus souvent : ce sont les machines qu'il a
    envie de reprendre, et un tirage qui les ignorerait proposerait surtout du
    matériel qu'il n'aime pas assez pour l'avoir marqué.
    """
    r = random.Random(seed)
    conn = get_db(db_path)
    instruments = _actifs(conn, INSTRUMENTS)
    traitements = _actifs(conn, TRAITEMENTS)
    conn.close()

    def choisir(pool):
        if not pool:
            return None
        pondere = pool + [g for g in pool if g["favorite"]]
        return r.choice(pondere)

    instrument = choisir(instruments)
    traitement = choisir(traitements)
    gear = [g for g in (instrument, traitement) if g]

    return {
        "instrument": instrument,
        "traitement": traitement,
        "gear": gear,
        "noms": [g["name"] for g in gear],
        "oblique": rand_oblique(db_path),
        "titre": (propose_titres(1, seed=r.randrange(10**6)) or [""])[0],
        "vide": not gear,
    }
