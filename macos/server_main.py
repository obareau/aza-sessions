"""Serveur AZA embarqué dans l'app Mac — lancé par le binaire Swift.

Contrat avec `macos/AZASessions/ServerProcess.swift` :

  arguments   --data-dir DIR      base, config.json, copies SQLite
              --backup-dir DIR    sauvegardes JSON (hors de DIR, exprès)
              [--port N]          premier port essayé ; les 20 suivants ensuite
              [--parent-pid PID]  le serveur s'arrête si ce processus disparaît

  stdout      `AZA-READY port=N first=0|1` quand il écoute (first=1 : base neuve)
              `AZA-ERROR <code> <message>` avant de quitter en échec
              `AZA-STOPPED` après la dernière sauvegarde

  SIGTERM     sauvegarde JSON finale, puis sortie (code 0)

⚠️ Le port reste le MÊME d'un lancement à l'autre (l'app le retient) : le
stockage local du navigateur — brouillons de `/vite`, thème, sections repliées —
est rangé par origine `http://127.0.0.1:PORT`. Un port tiré au hasard à chaque
lancement effacerait les brouillons à chaque fois.

`--selftest` : monte l'app dans un dossier jetable et visite toutes les pages.
Sert à vérifier un binaire construit (templates embarqués, modules présents),
sur chaque architecture.
"""
import argparse
import fcntl
import logging
import os
import signal
import sys
import tempfile
import threading

DEFAULT_PORT = 47017


def emit(line):
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def _prepare_env(data_dir, backup_dir):
    os.makedirs(data_dir, exist_ok=True)
    os.makedirs(backup_dir, exist_ok=True)
    db_path = os.path.join(data_dir, "sessions.db")
    os.environ["DB_PATH"] = db_path
    os.environ["CONFIG_PATH"] = os.path.join(data_dir, "config.json")
    os.environ["BACKUPS_DIR"] = os.path.join(data_dir, "copies-sqlite")
    os.environ["JSON_BACKUP_DIR"] = backup_dir
    return db_path


def _lock(data_dir):
    """Un seul serveur par base : deux processus qui écrivent la même base
    sans se connaître, c'est la recette d'une séance qui disparaît."""
    f = open(os.path.join(data_dir, ".verrou"), "w")  # noqa: SIM115 — gardé ouvert exprès
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        f.close()
        return None
    return f


def _make_server(app, first_port):
    from werkzeug.serving import make_server
    ports = [0] if first_port == 0 else range(first_port, first_port + 20)
    last = None
    for port in ports:
        try:
            return make_server("127.0.0.1", port, app, threaded=True)
        except OSError as exc:
            last = exc
    raise last


def serve(args):
    data_dir = os.path.abspath(os.path.expanduser(args.data_dir))
    backup_dir = os.path.abspath(os.path.expanduser(args.backup_dir))
    try:
        db_path = _prepare_env(data_dir, backup_dir)
    except OSError as exc:
        emit(f"AZA-ERROR dossier {exc}")
        return 2
    first = not os.path.exists(db_path)

    lock = _lock(data_dir)
    if lock is None:
        emit(f"AZA-ERROR deja-ouvert un autre serveur AZA utilise déjà {data_dir}")
        return 3

    import app as aza  # après _prepare_env : app.py lit l'environnement à l'import

    logging.getLogger("werkzeug").setLevel(logging.WARNING)
    written, snapshot = aza.demarrer_sauvegardes()
    print(f"[aza] base {db_path}", flush=True)
    print(f"[aza] copie sqlite {written or 'inchangée'}", flush=True)
    print(f"[aza] sauvegarde json {snapshot or 'à jour'} → {backup_dir}", flush=True)
    if aza.journal.last_error:
        print(f"[aza] ⚠ sauvegarde en échec : {aza.journal.last_error}", flush=True)

    try:
        server = _make_server(aza.app, args.port)
    except OSError as exc:
        emit(f"AZA-ERROR port {exc}")
        return 4

    stopping = threading.Event()

    def shutdown(*_):
        if not stopping.is_set():
            stopping.set()
            threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    if args.parent_pid:
        def watch_parent():
            # L'app tuée net (forcer à quitter, plantage) : le serveur passe à
            # launchd. Il sauvegarde et s'en va au lieu de rester orphelin.
            while not stopping.wait(2):
                if os.getppid() != args.parent_pid:
                    print("[aza] app disparue — arrêt", flush=True)
                    shutdown()
        threading.Thread(target=watch_parent, daemon=True).start()

    emit(f"AZA-READY port={server.server_port} first={int(first)}")
    try:
        server.serve_forever()
    finally:
        aza.journal.stop(flush=True)
        if aza.journal.last_error:
            print(f"[aza] ⚠ dernière sauvegarde en échec : {aza.journal.last_error}", flush=True)
        emit("AZA-STOPPED")
        lock.close()
    return 0


def selftest():
    """Visite toutes les pages sans paramètre d'une app montée dans un dossier
    jetable. Une page qui renvoie 500 dans le binaire et pas en développement,
    c'est presque toujours un fichier oublié à l'empaquetage."""
    import sqlite3

    root = tempfile.mkdtemp(prefix="aza-selftest-")
    db_path = _prepare_env(os.path.join(root, "data"), os.path.join(root, "json"))

    import app as aza
    from core import journal as jr

    aza.demarrer_sauvegardes()
    c = sqlite3.connect(db_path)
    c.execute("INSERT INTO sessions (date, title, machines, rating) "
              "VALUES ('2026-11-14T21:00', 'selftest — Scaër', 'MicroFreak', 4)")
    c.commit()
    c.close()

    client = aza.app.test_client()
    failures, visited = [], 0
    for rule in aza.app.url_map.iter_rules():
        if "GET" not in rule.methods or rule.arguments:
            continue
        resp = client.get(rule.rule)
        visited += 1
        if resp.status_code >= 500:
            failures.append(f"{rule.rule} → {resp.status_code}")
    for path in ("/session/1", "/static/vendor/chart.umd.min.js"):
        resp = client.get(path)
        visited += 1
        if resp.status_code != 200:
            failures.append(f"{path} → {resp.status_code}")

    snap = aza.journal.save_now(label="selftest")
    dump = jr.load_file(snap)
    report = jr.restore(db_path, dump)
    if report["counts"].get("sessions") != 1:
        failures.append(f"restauration : {report}")
    aza.journal.stop(flush=False)

    print(f"[selftest] {visited} pages, sqlite {sqlite3.sqlite_version}, "
          f"python {sys.version.split()[0]}, {os.uname().machine}", flush=True)
    if failures:
        for f in failures:
            print(f"[selftest] ✕ {f}", flush=True)
        return 1
    print("[selftest] OK", flush=True)
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="aza-server")
    parser.add_argument("--data-dir")
    parser.add_argument("--backup-dir")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--parent-pid", type=int, default=0)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args(argv)
    if args.selftest:
        return selftest()
    if not args.data_dir or not args.backup_dir:
        parser.error("--data-dir et --backup-dir sont requis")
    return serve(args)


if __name__ == "__main__":
    # Lancé depuis les sources : rendre le dépôt importable (`import app`).
    if not getattr(sys, "frozen", False):
        sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    sys.exit(main())
