"""Sauvegarde JSON de la base — lisible, vérifiable, restaurable.

Pourquoi du JSON en plus des copies SQLite de `core/backup.py` :

- **lisible sans AZA** : un éditeur de texte suffit pour retrouver une séance,
  même le jour où l'app ne démarre plus ;
- **vérifiable** : chaque fichier porte l'empreinte SHA-256 de son contenu, une
  copie tronquée ou abîmée est refusée à la restauration au lieu d'écraser la
  base avec un état partiel ;
- **écrite à chaque changement**, pas seulement au démarrage. Les copies SQLite
  ne se faisaient qu'au lancement du service : un mois de séances sans
  redémarrage, c'était un mois sans filet.

⚠️ La veille (`Journal`) ne s'appuie PAS sur les routes HTTP : elle lit
`PRAGMA data_version`, qui change dès qu'une autre connexion a écrit. Toute
écriture est vue, y compris par une route qui écrirait en GET.

⚠️ La restauration ne remplace jamais le fichier de la base (`os.replace`) :
une connexion déjà ouverte continuerait d'écrire dans l'ancien fichier, et ses
écritures disparaîtraient. Elle passe par l'API backup de SQLite, qui réécrit
la base en place sous verrou.
"""
import base64
import hashlib
import json
import os
import re
import sqlite3
import tempfile
import threading
import time
from datetime import datetime, timedelta

from .db import ro_uri

FORMAT = "aza-sessions-sauvegarde"
FORMAT_VERSION = 1

PREFIX = "aza-sessions_"
_NAME_RE = re.compile(
    r"^aza-sessions_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})(?:-(\d+))?(?:_([a-z0-9-]+))?\.json$"
)

# Tables qui ont existé et ne reviendront pas : présentes dans une vieille base,
# elles ne doivent pas bloquer la restauration de tout le reste.
#  - prompter_scripts : le Prompteur est parti chez D.I.M (v3.12.0)
#  - sessions_fts*    : l'index FTS5 corrompait la base, retiré (v3.6.x)
OBSOLETE_TABLES = {"prompter_scripts"}
OBSOLETE_PREFIXES = ("sessions_fts",)

# Rétention — voir `keep_set`.
KEEP_NEWEST = 20
KEEP_ALL_HOURS = 48
KEEP_DAILY_DAYS = 60


class RestoreError(Exception):
    """Sauvegarde refusée : rien n'a été touché dans la base."""


# ── EXPORT ───────────────────────────────────────────────────────────────────

def _q(name):
    """Identifiant SQL entre guillemets — les noms viennent de la base lue."""
    return '"' + name.replace('"', '""') + '"'


def _user_tables(conn):
    return [r[0] for r in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name")]


def _encode(value):
    if isinstance(value, bytes):
        return {"$base64": base64.b64encode(value).decode("ascii")}
    return value


def _decode(value):
    if isinstance(value, dict) and set(value) == {"$base64"}:
        return base64.b64decode(value["$base64"])
    return value


def _read_db(conn):
    tables, schema = {}, {}
    for name in _user_tables(conn):
        cols = [r[1] for r in conn.execute(f"PRAGMA table_info({_q(name)})")]
        cur = conn.execute(f"SELECT * FROM {_q(name)} ORDER BY rowid")
        rows = [{c: _encode(v) for c, v in zip(cols, row)} for row in cur]
        tables[name] = {"columns": cols, "rows": rows}
        schema[name] = conn.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (name,)
        ).fetchone()[0]
    sequences = {}
    try:
        sequences = {n: s for n, s in conn.execute(
            "SELECT name, seq FROM sqlite_sequence ORDER BY name")}
    except sqlite3.OperationalError:
        pass  # aucune table AUTOINCREMENT
    return tables, sequences, schema


def content_hash(dump):
    """Empreinte des DONNÉES seules (tables + séquences), pas de la date ni de
    la version : deux sauvegardes d'une base inchangée ont la même."""
    payload = json.dumps({"tables": dump["tables"], "sequences": dump["sequences"]},
                         sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def dump_db(db_path, app_version=""):
    """Photographie complète de la base, toutes tables, en dict sérialisable.

    Lecture dans une transaction : la photo est cohérente même si une requête
    écrit au même moment.
    """
    conn = sqlite3.connect(ro_uri(db_path), uri=True, timeout=10.0)
    try:
        conn.execute("BEGIN")
        tables, sequences, schema = _read_db(conn)
        conn.execute("COMMIT")
    finally:
        conn.close()
    dump = {
        "format": FORMAT,
        "format_version": FORMAT_VERSION,
        "app_version": app_version,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "counts": {t: len(v["rows"]) for t, v in tables.items()},
        "sequences": sequences,
        "tables": tables,
        "schema": schema,
    }
    dump["sha256"] = content_hash(dump)
    return dump


def to_json(dump):
    return json.dumps(dump, ensure_ascii=False, indent=1)


# ── FICHIERS ─────────────────────────────────────────────────────────────────

def _atomic_write(path, text):
    """Écrit puis renomme : un fichier de sauvegarde est complet ou absent,
    jamais à moitié écrit (coupure de courant, disque plein)."""
    folder = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(prefix=".ecriture-", suffix=".json", dir=folder)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
        tmp = None
    finally:
        if tmp and os.path.exists(tmp):
            os.remove(tmp)
    try:
        dfd = os.open(folder, os.O_RDONLY)
        try:
            os.fsync(dfd)
        finally:
            os.close(dfd)
    except OSError:
        pass


def write_snapshot(dump, backup_dir, label=None, now=None):
    """Écrit `dump` dans backup_dir sous un nom horodaté. Retourne le chemin."""
    os.makedirs(backup_dir, exist_ok=True)
    now = now or datetime.now()
    stem = PREFIX + now.strftime("%Y-%m-%d_%H-%M-%S")
    suffix = f"_{label}" if label else ""
    path = os.path.join(backup_dir, f"{stem}{suffix}.json")
    n = 2
    while os.path.exists(path):
        path = os.path.join(backup_dir, f"{stem}-{n}{suffix}.json")
        n += 1
    _atomic_write(path, to_json(dump))
    return path


def list_snapshots(backup_dir):
    """Sauvegardes du dossier, la plus récente en premier."""
    if not os.path.isdir(backup_dir):
        return []
    out = []
    for name in os.listdir(backup_dir):
        m = _NAME_RE.match(name)
        if not m:
            continue
        path = os.path.join(backup_dir, name)
        out.append({
            "name": name,
            "path": path,
            "when": datetime.strptime(m.group(1), "%Y-%m-%d_%H-%M-%S"),
            "rank": int(m.group(2) or 1),  # deux écritures dans la même seconde
            "label": m.group(3) or "",
            "size": os.path.getsize(path),
        })
    out.sort(key=_order, reverse=True)
    return out


def _order(snap):
    return (snap["when"], snap.get("rank", 1))


def keep_set(snapshots, now):
    """Noms à garder. Fonction pure, testée seule.

    - une sauvegarde étiquetée (`avant-restauration`, `avant-vidage`…) : toujours ;
    - les KEEP_NEWEST plus récentes : toujours, quel que soit leur âge — après
      six mois sans ouvrir l'app, on retrouve encore ses vingt derniers états ;
    - tout ce qui a moins de KEEP_ALL_HOURS ;
    - la dernière de chaque jour jusqu'à KEEP_DAILY_DAYS ;
    - au-delà, la dernière de chaque mois, sans limite.
    """
    keep = set()
    plain = sorted((s for s in snapshots if not s["label"]), key=_order, reverse=True)
    keep.update(s["name"] for s in snapshots if s["label"])
    keep.update(s["name"] for s in plain[:KEEP_NEWEST])
    seen_days, seen_months = set(), set()
    for s in plain:
        age = now - s["when"]
        if age < timedelta(hours=KEEP_ALL_HOURS):
            keep.add(s["name"])
        elif age < timedelta(days=KEEP_DAILY_DAYS):
            day = s["when"].date()
            if day not in seen_days:
                seen_days.add(day)
                keep.add(s["name"])
        else:
            month = (s["when"].year, s["when"].month)
            if month not in seen_months:
                seen_months.add(month)
                keep.add(s["name"])
    return keep


def prune(backup_dir, now=None):
    snaps = list_snapshots(backup_dir)
    keep = keep_set(snaps, now or datetime.now())
    removed = []
    for s in snaps:
        if s["name"] not in keep:
            try:
                os.remove(s["path"])
                removed.append(s["name"])
            except OSError:
                pass
    return removed


# ── LECTURE & VÉRIFICATION ───────────────────────────────────────────────────

SQLITE_MAGIC = b"SQLite format 3\x00"


def load_file(path):
    """Lit une sauvegarde `.json` ou une base `.db` et rend un dump.

    Une base `.db` est lue en lecture seule puis traduite au même format : c'est
    ainsi qu'une vieille `sessions.db` se restaure entière, et plus seulement sa
    table de séances.
    """
    with open(path, "rb") as f:
        head = f.read(16)
    if head == SQLITE_MAGIC:
        try:
            return dump_db(path)
        except sqlite3.DatabaseError as exc:
            raise RestoreError(f"base SQLite illisible : {exc}") from exc
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RestoreError(
            "ce fichier n'est ni une sauvegarde JSON d'AZA ni une base SQLite "
            f"({exc.__class__.__name__})") from exc
    check_dump(data)
    return data


def check_dump(dump):
    if not isinstance(dump, dict) or dump.get("format") != FORMAT:
        raise RestoreError("ce JSON n'est pas une sauvegarde d'AZA Sessions")
    if dump.get("format_version", 0) > FORMAT_VERSION:
        raise RestoreError(
            f"sauvegarde au format {dump['format_version']}, plus récent que "
            f"celui que cette version d'AZA sait lire ({FORMAT_VERSION}) — "
            "mets l'app à jour")
    if not isinstance(dump.get("tables"), dict):
        raise RestoreError("sauvegarde sans tables")
    dump.setdefault("sequences", {})
    expected = dump.get("sha256")
    if expected and content_hash(dump) != expected:
        raise RestoreError(
            "l'empreinte SHA-256 ne correspond pas : fichier abîmé ou modifié. "
            "Si tu l'as corrigé à la main, retire la ligne \"sha256\" pour "
            "l'accepter tel quel")
    for name, table in dump["tables"].items():
        if not isinstance(table, dict) or not isinstance(table.get("rows"), list):
            raise RestoreError(f"table « {name} » mal formée")


def _obsolete(table):
    return table in OBSOLETE_TABLES or table.startswith(OBSOLETE_PREFIXES)


def _unknowns(dump, schema):
    """Ce que la sauvegarde contient et que cette version ne sait pas ranger."""
    tables, columns, obsolete = [], [], []
    for name, table in dump["tables"].items():
        if name not in schema:
            (obsolete if _obsolete(name) else tables).append(name)
            continue
        cols = set(table.get("columns") or [])
        for row in table["rows"]:
            cols.update(row)
        columns += [f"{name}.{c}" for c in sorted(cols - set(schema[name]))]
    return sorted(tables), columns, sorted(obsolete)


# ── RESTAURATION ─────────────────────────────────────────────────────────────

def restore(db_path, dump, init_db=None, allow_unknown=False):
    """Remplace TOUT le contenu de la base par celui de `dump`.

    Construit d'abord une base complète à côté, la vérifie (comptes, intégrité),
    et seulement alors la recopie dans la base vivante. Une erreur à n'importe
    quelle étape laisse la base intacte.

    Retourne un rapport : {"counts": {table: n}, "ignored": [...]}.
    """
    if init_db is None:
        from .init_db import init_db
    check_dump(dump)
    folder = os.path.dirname(os.path.abspath(db_path))
    fd, tmp = tempfile.mkstemp(prefix=".restauration-", suffix=".db", dir=folder)
    os.close(fd)
    os.remove(tmp)  # init_db doit créer la base lui-même
    try:
        init_db(tmp)
        conn = sqlite3.connect(tmp)
        try:
            schema = {t: [r[1] for r in conn.execute(f"PRAGMA table_info({_q(t)})")]
                      for t in _user_tables(conn)}
            tables, columns, obsolete = _unknowns(dump, schema)
            if (tables or columns) and not allow_unknown:
                what = ", ".join(tables + columns)
                raise RestoreError(
                    "la sauvegarde contient des données que cette version d'AZA ne "
                    f"sait pas ranger : {what}. Elles seraient perdues — mets l'app à "
                    "jour, ou coche « ignorer » en connaissance de cause")

            counts = {}
            with conn:
                for name, table in sorted(dump["tables"].items()):
                    if name not in schema:
                        continue
                    known = set(schema[name])
                    conn.execute(f"DELETE FROM {_q(name)}")
                    for row in table["rows"]:
                        cols = [c for c in row if c in known]
                        if not cols:
                            conn.execute(f"INSERT INTO {_q(name)} DEFAULT VALUES")
                            continue
                        sql = (f"INSERT INTO {_q(name)} ({', '.join(_q(c) for c in cols)}) "
                               f"VALUES ({', '.join('?' for _ in cols)})")
                        conn.execute(sql, [_decode(row[c]) for c in cols])
                    counts[name] = len(table["rows"])
                # AUTOINCREMENT ne réutilise jamais un id : on reprend le compteur
                # de la sauvegarde, sinon une séance supprimée verrait son numéro
                # attribué à une autre.
                for name, seq in dump["sequences"].items():
                    if name not in schema or seq is None:
                        continue
                    cur = conn.execute(
                        "SELECT seq FROM sqlite_sequence WHERE name=?", (name,)).fetchone()
                    if cur is None:
                        conn.execute("INSERT INTO sqlite_sequence (name, seq) VALUES (?, ?)",
                                     (name, seq))
                    elif cur[0] < seq:
                        conn.execute("UPDATE sqlite_sequence SET seq=? WHERE name=?",
                                     (seq, name))

            for name, n in counts.items():
                got = conn.execute(f"SELECT COUNT(*) FROM {_q(name)}").fetchone()[0]
                if got != n:
                    raise RestoreError(f"table « {name} » : {got} lignes écrites sur {n}")
            ok = conn.execute("PRAGMA integrity_check").fetchone()[0]
            if ok != "ok":
                raise RestoreError(f"contrôle d'intégrité en échec : {ok}")
        finally:
            conn.close()

        # Les migrations de init_db() s'appliquent aussi aux données restaurées.
        init_db(tmp)

        src = sqlite3.connect(tmp)
        try:
            dst = sqlite3.connect(db_path, timeout=30.0)
            try:
                src.backup(dst)
            finally:
                dst.close()
        finally:
            src.close()
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)

    return {"counts": counts, "ignored": tables + columns + obsolete}


# ── VEILLE ───────────────────────────────────────────────────────────────────

class Journal:
    """Écrit une sauvegarde JSON chaque fois que la base change.

    Attend que les écritures se calment (`quiet` secondes) pour ne pas produire
    un fichier par champ modifié, sans jamais différer plus de `max_wait`.
    """

    def __init__(self, db_path, backup_dir, app_version="",
                 interval=1.0, quiet=2.0, max_wait=30.0):
        self.db_path = db_path
        self.backup_dir = backup_dir
        self.app_version = app_version
        self.interval, self.quiet, self.max_wait = interval, quiet, max_wait
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._thread = None
        self._last_hash = None
        self.last_path = None
        self.last_time = None
        self.last_error = None

    # -- état --------------------------------------------------------------

    def status(self):
        snaps = list_snapshots(self.backup_dir)
        latest = snaps[0] if snaps else None
        return {
            "dossier": self.backup_dir,
            "nombre": len(snaps),
            "derniere": latest["name"] if latest else None,
            "derniere_quand": latest["when"].isoformat(sep=" ") if latest else None,
            "erreur": self.last_error,
            "veille": bool(self._thread and self._thread.is_alive()),
        }

    # -- écriture ----------------------------------------------------------

    def save_now(self, label=None):
        """Sauvegarde immédiate. Sans étiquette, rien n'est écrit si la base
        n'a pas changé depuis la dernière ; avec, toujours (une copie « avant
        restauration » doit exister même si elle ressemble à la précédente).

        Retourne le chemin écrit, ou None. Ne lève jamais : l'échec est gardé
        dans `last_error`, affiché sur toutes les pages.
        """
        with self._lock:
            try:
                if not os.path.exists(self.db_path):
                    return None
                dump = dump_db(self.db_path, self.app_version)
                if self._last_hash is None:
                    self._last_hash = self._hash_of_latest()
                if label is None and dump["sha256"] == self._last_hash:
                    self.last_error = None
                    return None
                path = write_snapshot(dump, self.backup_dir, label=label)
                self._last_hash = dump["sha256"]
                self.last_path, self.last_time = path, datetime.now()
                self.last_error = None
                prune(self.backup_dir)
                return path
            except Exception as exc:  # noqa: BLE001 — l'erreur est rapportée, pas avalée
                self.last_error = f"{exc.__class__.__name__}: {exc}"
                return None

    def _hash_of_latest(self):
        for snap in list_snapshots(self.backup_dir):
            if snap["label"]:
                continue
            try:
                with open(snap["path"], encoding="utf-8") as f:
                    return json.load(f).get("sha256")
            except (OSError, ValueError):
                return None
        return None

    # -- veille ------------------------------------------------------------

    def start(self):
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, name="aza-journal", daemon=True)
        self._thread.start()

    def stop(self, flush=True):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=5)
        if flush:
            self.save_now()

    def _run(self):
        try:
            watch = sqlite3.connect(self.db_path, timeout=10.0, check_same_thread=False)
        except sqlite3.Error as exc:
            self.last_error = f"veille impossible : {exc}"
            return
        try:
            version = watch.execute("PRAGMA data_version").fetchone()[0]
            first = last = None
            while not self._stop.wait(self.interval):
                try:
                    v = watch.execute("PRAGMA data_version").fetchone()[0]
                except sqlite3.Error:
                    continue
                now = time.monotonic()
                if v != version:
                    version, last = v, now
                    first = first or now
                # max_wait est vérifié même si les écritures continuent : une
                # rafale ininterrompue ne doit pas repousser la sauvegarde à jamais.
                if first and (now - last >= self.quiet or now - first >= self.max_wait):
                    first = last = None
                    self.save_now()
        finally:
            watch.close()
