"""Dépouillement des prises — rapprocher les fichiers du Zoom R8 et les séances.

AZA fabrique un nom de prise (`WPMG_1`), l'écrit dans `sessions.audio_file`… et
plus personne ne le relit. Le dossier où la carte SD se vide, lui, accumule des
fichiers que rien ne rattache au journal. Ce module ferme la boucle, dans les
deux sens :

- une prise sans séance, c'est une chose jouée qu'on n'a jamais notée ;
- une séance dont la prise manque sur le disque, c'est un souvenir sans preuve.

Rien n'est copié, rien n'est déplacé, rien n'est écrit : le dossier de prises
reste la référence, AZA le lit. Aucune dépendance non plus — `wave` est dans la
bibliothèque standard et suffit à lire une durée.
"""
import os
import wave

from core.db import get_db

# Ce que le R8 produit, plus ce qu'on récupère parfois d'ailleurs.
EXTENSIONS = (".wav", ".aif", ".aiff", ".mp3", ".flac", ".m4a", ".ogg")

# Garde-fou : un dossier de prises mal réglé (le home entier, par exemple) ne
# doit pas faire ramer la page pendant une minute.
MAX_FICHIERS = 2000
MAX_PROFONDEUR = 4


def duree_wav(chemin: str) -> int | None:
    """Durée en secondes, lue dans l'en-tête WAV. `None` si illisible.

    Seul le WAV est mesuré : c'est ce que le R8 enregistre, et lire la durée
    d'un MP3 demanderait soit une dépendance, soit un décodeur écrit à la main
    pour un format qu'on ne rencontre pas ici.
    """
    if not chemin.lower().endswith(".wav"):
        return None
    try:
        with wave.open(chemin, "rb") as f:
            taux = f.getframerate()
            return round(f.getnframes() / taux) if taux else None
    except Exception:
        return None


def mmss(secondes) -> str:
    if not secondes:
        return ""
    return f"{int(secondes) // 60}:{int(secondes) % 60:02d}"


def _cles(chemin_relatif: str) -> set[str]:
    """Les noms sous lesquels un fichier peut être reconnu.

    Le R8 range ses enregistrements en **dossiers de projet** : le nom qu'AZA a
    fabriqué se retrouve donc souvent sur le dossier (`WPMG_1/TRACK01.WAV`) et
    non sur le fichier. On accepte les deux, sinon rien ne se rapprocherait.
    """
    morceaux = chemin_relatif.replace("\\", "/").split("/")
    cles = {os.path.splitext(morceaux[-1])[0].strip().upper()}
    if len(morceaux) > 1:
        cles.add(morceaux[-2].strip().upper())
    return {c for c in cles if c}


class TakesEngine:
    def __init__(self, db_path, racine):
        self.db_path = db_path
        self.racine = os.path.expanduser(racine or "")

    @property
    def dispo(self) -> bool:
        return bool(self.racine) and os.path.isdir(self.racine)

    # ── Disque ───────────────────────────────────────────────────────────────
    def fichiers(self) -> list[dict]:
        if not self.dispo:
            return []
        out = []
        for dossier, sous, noms in os.walk(self.racine):
            profondeur = dossier[len(self.racine):].count(os.sep)
            if profondeur >= MAX_PROFONDEUR:
                sous[:] = []
            for n in sorted(noms):
                if not n.lower().endswith(EXTENSIONS) or n.startswith("."):
                    continue
                chemin = os.path.join(dossier, n)
                rel = os.path.relpath(chemin, self.racine)
                try:
                    taille = os.path.getsize(chemin)
                except OSError:
                    continue
                out.append({
                    "rel": rel,
                    "nom": n,
                    "dossier": os.path.dirname(rel),
                    "taille_mo": round(taille / 1048576, 1),
                    "duree": mmss(duree_wav(chemin)),
                    "cles": _cles(rel),
                })
                if len(out) >= MAX_FICHIERS:
                    return out
        return out

    def chemin_sur(self, rel: str) -> str | None:
        """Résout un chemin relatif **en restant sous la racine**.

        Sans cette vérification, un `../../.ssh/id_rsa` servi par la route
        d'écoute donnerait accès à tout le disque. On compare les chemins réels,
        pas les chaînes : un lien symbolique doit être arrêté aussi.
        """
        if not self.dispo or not rel:
            return None
        racine = os.path.realpath(self.racine)
        vise = os.path.realpath(os.path.join(racine, rel))
        if vise != racine and not vise.startswith(racine + os.sep):
            return None
        return vise if os.path.isfile(vise) else None

    # ── Rapprochement ────────────────────────────────────────────────────────
    def _seances_avec_prise(self) -> list[dict]:
        conn = get_db(self.db_path)
        rows = conn.execute(
            "SELECT id, date, title, audio_file FROM sessions "
            "WHERE TRIM(COALESCE(audio_file,'')) != '' ORDER BY date DESC"
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def depouille(self) -> dict:
        """Les trois listes : rattachées, orphelines, réclamées mais absentes."""
        seances = self._seances_avec_prise()
        par_nom = {}
        for s in seances:
            par_nom.setdefault((s["audio_file"] or "").strip().upper(), []).append(s)

        rattachees, orphelines = [], []
        trouves = set()
        for f in self.fichiers():
            corresp = [s for cle in f["cles"] for s in par_nom.get(cle, [])]
            if corresp:
                trouves.update(c for c in f["cles"] if c in par_nom)
                # Une même clé peut désigner deux séances (collision inter-jours
                # assumée sur le R8) : on les montre toutes plutôt que d'en élire
                # une au hasard.
                rattachees.append({**f, "seances": corresp})
            else:
                orphelines.append(f)

        manquantes = [s for cle, groupe in par_nom.items() if cle not in trouves
                      for s in groupe]
        return {
            "rattachees": rattachees,
            "orphelines": orphelines,
            "manquantes": sorted(manquantes, key=lambda s: s["date"], reverse=True),
            "nb_fichiers": len(rattachees) + len(orphelines),
        }
