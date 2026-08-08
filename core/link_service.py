"""Lecture de la grille Ableton Link — **via D.I.M**, sans pair propre.

⚠️⚠️ **AZA Sessions ne tient PLUS son propre pair Link** (débranché le
2026-08-08). Il en tenait un jusqu'ici, et D.I.M aussi : les deux apparaissaient
comme **deux appareils distincts** dans la session Link de tous les musiciens
présents — mesuré, `peers` passait à 2 avec les deux services allumés alors
qu'un seul Ableton Live tournait.

**D.I.M possède l'horloge, AZA la lit.** C'est le partage qui correspond au
workflow : D.I.M est le séquenceur de performance, AZA le journal de session.
Deux outils, deux moments — ils ne s'utilisent pas en même temps.

ℹ️ D.I.M a en plus la meilleure architecture : une abstraction `SyncSource`
avec **trois** sources (Ableton Link, horloge MIDI, OSC) là où AZA n'avait que
Link. Lire son état, c'est hériter des trois sans écrire une ligne.

⚠️ **Le tempo peut donc venir d'ailleurs que de Link** — `active_source` dit
laquelle des trois parle. Ne pas supposer Link.

Prérequis côté D.I.M : la source doit être démarrée une fois, par
`POST /api/sync/link/start` avec un corps JSON (même vide) — `get_json(force=True)`
refuse une requête sans corps par un 400.
"""

import json
import os
import urllib.error
import urllib.request

DIM_HOST = os.environ.get("DIM_HOST", "localhost")
DIM_PORT = int(os.environ.get("DIM_PORT", 5002))
_URL = f"http://{DIM_HOST}:{DIM_PORT}/api/sync/status"

# Court à dessein : cet appel est sur le chemin d'un changement de cue. Mieux
# vaut avancer sans quantize qu'infliger une attente au musicien.
_TIMEOUT_S = 0.4


def available() -> bool:
    """Toujours vrai : la disponibilité réelle se lit dans `state()`.

    Gardé pour ne pas casser les appelants existants — l'absence de D.I.M n'est
    pas une erreur de configuration d'AZA, c'est un état du réseau.
    """
    return True


def state() -> dict:
    """Instantané de la grille, lu chez D.I.M. Ne lève jamais.

    Renvoie la même forme qu'avant le débranchement, pour que le widget du
    Prompteur et le quantize n'aient rien à changer.
    """
    try:
        with urllib.request.urlopen(_URL, timeout=_TIMEOUT_S) as r:
            data = json.loads(r.read().decode("utf-8"))
    except (urllib.error.URLError, OSError, ValueError, TimeoutError):
        # D.I.M éteint : ce n'est pas une panne, c'est le cas courant quand on
        # tient son journal sans jouer.
        return {"available": False, "reason": "D.I.M injoignable"}

    link = data.get("link")
    if not link or not link.get("available"):
        return {"available": False, "reason": "sync Link non démarrée dans D.I.M"}

    return {
        "available": True,
        "peers": link.get("peers", 0),
        "tempo": link.get("tempo_bpm"),
        "beat": link.get("beat"),
        "phase": link.get("phase"),
        "quantum": link.get("quantum", 4.0),
        "playing": link.get("playing", False),
        "next_downbeat_s": link.get("next_downbeat_s"),
        # Quelle des trois sources de D.I.M parle réellement.
        "source": data.get("active_source"),
    }
