"""Tests DB — vérifie que init_db() crée bien toutes les tables attendues."""
import sqlite3
import os
import pytest

from core.db import get_db

# Récupère le chemin DB depuis la variable d'env injectée par conftest
_TMP_DB_PATH = os.environ["DB_PATH"]


EXPECTED_TABLES = [
    "sessions",
    "catalogue",
    "obliques",
    "influences",
    "projects",
    "sample_banks",
    "inspiring_tracks",
    "gear_wishlist",
    "inspirations",
    "mirack_modules",
    "prompter_scripts",
    "live_session",
    "patch_layouts",
    "patch_nodes",
    "patch_connections",
    "sysex_banks",
]


def test_all_tables_exist():
    """Toutes les tables attendues doivent exister après init_db()."""
    conn = sqlite3.connect(_TMP_DB_PATH)
    cursor = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
    )
    existing = {row[0] for row in cursor.fetchall()}
    conn.close()

    missing = [t for t in EXPECTED_TABLES if t not in existing]
    assert not missing, f"Tables manquantes : {missing}"


def test_get_db_row_factory():
    """get_db() doit retourner une connexion avec row_factory = sqlite3.Row."""
    conn = get_db(_TMP_DB_PATH)
    assert conn.row_factory is sqlite3.Row, (
        "get_db() doit configurer row_factory = sqlite3.Row"
    )
    conn.close()


def test_obliques_seeded():
    """La table obliques doit contenir les stratégies par défaut après init."""
    conn = get_db(_TMP_DB_PATH)
    count = conn.execute("SELECT COUNT(*) FROM obliques").fetchone()[0]
    conn.close()
    assert count > 0, "La table obliques est vide — init_db() n'a pas peuplé les données"


def test_catalogue_seeded():
    """La table catalogue doit contenir les items par défaut après init."""
    conn = get_db(_TMP_DB_PATH)
    count = conn.execute("SELECT COUNT(*) FROM catalogue").fetchone()[0]
    conn.close()
    assert count > 0, "La table catalogue est vide — init_db() n'a pas peuplé les données"


def test_sessions_schema():
    """La table sessions doit avoir les colonnes clés : id, date, rating, recap_claude."""
    conn = sqlite3.connect(_TMP_DB_PATH)
    cursor = conn.execute("PRAGMA table_info(sessions)")
    columns = {row[1] for row in cursor.fetchall()}
    conn.close()

    required = {"id", "date", "rating", "recap_claude", "project_id", "title"}
    missing = required - columns
    assert not missing, f"Colonnes manquantes dans sessions : {missing}"
