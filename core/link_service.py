"""Pair Ableton Link partagé par l'application.

Le Prompteur affiche le tempo et la phase de la grille Link — donc de tout ce
qui tourne sur le réseau : Ableton Live, les synthés iOS (MiRack, Tera Pro,
Peach, Seqnd, Blue Arp, LK for Live…).

⚠️⚠️ **UN SEUL PAIR PAR PROCESSUS.** Chaque instance `link.Link()` apparaît comme
un appareil distinct sur le réseau. L'unité systemd tourne en `--workers 1` :
si ce nombre augmente un jour, l'app se dédoublera dans la session Link de tous
les musiciens, sans erreur ni avertissement. Le singleton ci-dessous protège du
cas simple, pas du multi-processus.

⚠️ **Le navigateur ne peut PAS parler Link** (multicast UDP) : c'est ce module
qui tient le pair, et le client interroge `/api/link/state`.

ℹ️ **Dégradation silencieuse.** Sans la bibliothèque, `available()` renvoie
False et rien ne casse — l'app fonctionne comme avant, le widget disparaît.
Installer avec : `pip install LinkPython-extern` (⚠️ PAS `abletonlink`, qui
n'existe pas sur PyPI malgré ce que la roadmap a longtemps dit).
"""

import threading

try:
    import link as _link
except ImportError:  # bibliothèque absente : le module reste inerte
    _link = None

# Quantum = nombre de temps par mesure. 4 = une mesure à 4/4, la maille
# naturelle pour caler un changement de cue.
QUANTUM = 4.0

_instance = None
_verrou = threading.Lock()


def available() -> bool:
    """La bibliothèque est-elle installée ?"""
    return _link is not None


def _pair():
    """Le pair Link du processus, créé à la première demande."""
    global _instance
    if _link is None:
        return None
    if _instance is None:
        with _verrou:
            if _instance is None:  # re-test sous verrou
                p = _link.Link(120.0)
                p.enabled = True
                # Sans ce drapeau, l'état de transport reste LOCAL : on croirait
                # avoir lancé la lecture d'un pair distant sans que rien ne parte.
                p.startStopSyncEnabled = True
                _instance = p
    return _instance


def state() -> dict:
    """Instantané de la grille Link. Ne lève jamais."""
    p = _pair()
    if p is None:
        return {"available": False}
    try:
        s = p.captureAppSessionState()
        t = p.clock().micros()
        tempo = s.tempo()
        phase = s.phaseAtTime(t, QUANTUM)
        return {
            "available": True,
            "peers": p.numPeers(),
            "tempo": round(tempo, 2),
            "beat": round(s.beatAtTime(t, QUANTUM), 3),
            "phase": round(phase, 3),
            "quantum": QUANTUM,
            "playing": s.isPlaying(),
            # Délai jusqu'au prochain temps fort — c'est tout ce qu'il faut pour
            # qu'un changement de cue ne tombe jamais au milieu d'une mesure.
            "next_downbeat_s": round((QUANTUM - phase) * 60.0 / tempo, 3),
        }
    except Exception as exc:  # un pair injoignable ne doit pas casser une page
        return {"available": False, "error": str(exc)}


def set_tempo(bpm: float) -> dict:
    """Impose un tempo à toute la session Link. Vérifie par relecture.

    ⚠️⚠️ **Un commit n'est PAS fiable en soi.** Mesuré le 2026-08-08 : deux
    écritures ont échoué EN SILENCE (132 puis 96 BPM, relus inchangés) avant
    qu'une troisième, structurellement identique, passe du premier coup. Cause
    non isolée. On relit donc systématiquement, et l'appelant doit gérer
    `ok: False` — ne pas découvrir ça en concert.
    """
    p = _pair()
    if p is None:
        return {"ok": False, "error": "Ableton Link indisponible"}
    if not (20.0 <= bpm <= 999.0):
        return {"ok": False, "error": f"tempo hors bornes : {bpm}"}
    try:
        s = p.captureAppSessionState()
        s.setTempo(float(bpm), p.clock().micros())
        p.commitAppSessionState(s)
        relu = p.captureAppSessionState().tempo()
        return {"ok": abs(relu - bpm) < 0.01, "tempo": round(relu, 2), "demande": bpm}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}
