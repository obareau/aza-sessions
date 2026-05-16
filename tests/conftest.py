"""Fixtures pytest pour aza-sessions."""
import os
import tempfile
import pytest

# Pointer sur la DB temporaire AVANT l'import de app
# (app.py lit DB_PATH depuis os.environ au chargement du module)
_tmp_db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp_db.close()
_TMP_DB_PATH = _tmp_db.name
os.environ["DB_PATH"] = _TMP_DB_PATH

# CONFIG_PATH fictif — pas besoin du vrai config.json en test
_tmp_cfg = tempfile.NamedTemporaryFile(suffix=".json", delete=False)
_tmp_cfg.write(b"{}")
_tmp_cfg.close()
os.environ["CONFIG_PATH"] = _tmp_cfg.name

from app import app as flask_app  # noqa: E402 — import après env setup
from core.init_db import init_db  # noqa: E402


@pytest.fixture(scope="session", autouse=True)
def _setup_db():
    """Initialise la DB temporaire une seule fois pour la session de tests."""
    init_db(_TMP_DB_PATH)
    yield
    # Nettoyage
    try:
        os.unlink(_TMP_DB_PATH)
        os.unlink(_tmp_cfg.name)
    except OSError:
        pass


@pytest.fixture(scope="session")
def app(_setup_db):
    """App Flask configurée pour les tests."""
    flask_app.config.update(
        TESTING=True,
        DB_PATH=_TMP_DB_PATH,
        SECRET_KEY="test-secret",
        WTF_CSRF_ENABLED=False,
    )
    yield flask_app


@pytest.fixture()
def client(app):
    """Client de test Flask."""
    return app.test_client()
