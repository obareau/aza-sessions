"""Générateur de titres dans l'esthétique d'AZA.

Un titre de session n'a pas à décrire la musique — il doit situer la séance
dans l'univers. « Session du 14 » ne dit rien ; « MÉMOIRE RÉSIDUELLE » ou
« NODE SCAER-7 » rattachent la prise à la B.O. d'AZA.

Sans état, sans base : une fonction pure qu'on appelle et dont on jette le
résultat si aucun ne convient. C'est un déclencheur, pas une autorité — la
proposition se réécrit toujours à la main.

Le vocabulaire vient du glossaire de Robōtariis : la Rectitude, le C.G.U., le
calendrier CAL_RECT qui démarre à l'an 0, Scaër. Le registre est celui de
l'univers, pas de la science-fiction générique.
"""
import random

# Objets et états — ce que la Rectitude produit, use ou oublie.
NOMS = [
    "MÉMOIRE", "FRAGMENT", "SÉQUENCE", "VEILLE", "CORROSION", "RÉSIDU",
    "SIGNAL", "PROTOCOLE", "CONSIGNE", "ARCHIVE", "STRATE", "LATENCE",
    "DÉRIVE", "RELIQUE", "SILENCE", "CIRCUIT", "CENDRE", "BALISE",
    "INVENTAIRE", "SOMMEIL", "RUMEUR", "POUSSIÈRE", "FRACTURE", "ORNIÈRE",
]

# Qualités — l'usure, la lenteur, l'administratif.
ADJECTIFS = [
    "RÉSIDUELLE", "LENTE", "MÉCANIQUE", "OUBLIÉE", "CONTINUE", "BASSE",
    "PROVISOIRE", "SOUTERRAINE", "CONFORME", "DIFFÉRÉE", "MUETTE",
    "ANCIENNE", "SATURÉE", "ADMINISTRATIVE", "INTERDITE", "TARDIVE",
    "RÉTIVE", "SCELLÉE", "NOCTURNE", "MINÉRALE",
]

# Lieux — le réel et l'univers se recouvrent : Scaër est les deux à la fois.
LIEUX = [
    "SCAER", "KERGLAZ", "ROSPORDEN", "BASE-12", "SECTEUR-NORD", "RELAIS-3",
    "FRICHE-OUEST", "HANGAR-9", "TOUR-SUD", "LIGNE-4",
]

# Préfixes empruntés au glossaire : codex, calendrier, unités du C.G.U.
CODES = ["CDX", "CGU", "RBT", "CAL", "A0", "CLU", "ARX", "OBS"]

# Chaque motif est une façon différente de nommer : par objet, par lieu, par
# référence administrative. Mélanger les registres évite qu'une série de
# propositions se ressemble toutes.
def _objet(r):    return f"{r.choice(NOMS)} {r.choice(ADJECTIFS)}"
def _numerote(r): return f"{r.choice(NOMS)}-{r.randrange(1, 100):02d}"
def _lieu(r):     return f"NODE {r.choice(LIEUX)}-{r.randrange(1, 20)}"
def _codex(r):    return f"{r.choice(CODES)}-{r.randrange(1, 100):02d} / {_objet(r)}"
def _calendrier(r): return f"A.{r.randrange(1, 400)} — {r.choice(NOMS)}"

MOTIFS = (_objet, _numerote, _lieu, _codex, _calendrier)


def propose(n: int = 5, seed=None) -> list[str]:
    """`n` titres, sans doublon, un motif différent à chaque fois si possible.

    `seed` ne sert qu'aux tests : une proposition reproductible n'a aucun
    intérêt en usage réel, où c'est justement la surprise qu'on cherche.
    """
    r = random.Random(seed)
    n = max(1, min(int(n or 5), 20))
    vus, out = set(), []
    motifs = list(MOTIFS)
    r.shuffle(motifs)
    # Borne dure : sans elle, un tirage malchanceux boucle jusqu'à épuisement
    # du hasard plutôt que de rendre ce qu'il a déjà trouvé.
    for i in range(n * 12):
        if len(out) >= n:
            break
        titre = motifs[i % len(motifs)](r)
        if titre not in vus:
            vus.add(titre)
            out.append(titre)
    return out
