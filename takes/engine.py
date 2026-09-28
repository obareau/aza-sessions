"""Registre des prises — uniquement ce qui est saisi à la main.

Les noms de prise sont tapés dans le champ `audio_file` d'une séance, souvent
proposés par le générateur du catalogue (`WPMG_1`). Ce module ne fait que les
relire ensemble : **aucun disque n'est parcouru, aucun dossier n'est attendu**.

Une première version scrutait un dossier de vidage de carte SD pour rapprocher
fichiers et séances. Olivier saisit ses prises à la main — cette version-là
cherchait donc dans un dossier qui n'existerait jamais.

Ce que le registre apporte quand même : voir tous les noms d'un coup, et surtout
repérer ceux qui reviennent. Le compteur du R8 est quotidien et `MF_1` revient
chaque jour ; la collision est assumée, mais la voir vaut mieux que la subir.
"""
from core.db import get_db


class TakesEngine:
    def __init__(self, db_path):
        self.db_path = db_path

    def registre(self) -> list[dict]:
        """Les prises nommées, groupées par nom, la plus récente d'abord.

        Le groupement se fait sur le nom **normalisé** (casse et espaces) :
        « mf_1 » et « MF_1 » désignent la même prise sur la carte, et les
        afficher séparément masquerait justement le doublon.
        """
        conn = get_db(self.db_path)
        rows = conn.execute(
            "SELECT id, date, title, audio_file FROM sessions "
            "WHERE TRIM(COALESCE(audio_file,'')) != '' ORDER BY date DESC"
        ).fetchall()
        conn.close()

        groupes: dict[str, dict] = {}
        for r in rows:
            nom = (r["audio_file"] or "").strip()
            cle = nom.upper()
            g = groupes.setdefault(cle, {"nom": nom, "seances": []})
            g["seances"].append({"id": r["id"], "date": r["date"], "title": r["title"]})

        out = []
        for g in groupes.values():
            g["doublon"] = len(g["seances"]) > 1
            g["dernier"] = g["seances"][0]["date"]
            out.append(g)
        return sorted(out, key=lambda g: g["dernier"], reverse=True)

    def sans_prise(self) -> list[dict]:
        """Les séances qui n'ont aucun nom de prise.

        Ni une erreur ni un manque en soi — toutes les séances ne sont pas
        enregistrées. C'est juste ce qu'on veut pouvoir retrouver quand on
        cherche « celle où j'avais gardé quelque chose ».
        """
        conn = get_db(self.db_path)
        rows = conn.execute(
            "SELECT id, date, title FROM sessions "
            "WHERE TRIM(COALESCE(audio_file,'')) = '' ORDER BY date DESC LIMIT 50"
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]
