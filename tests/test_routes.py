"""Smoke tests — vérifie que les routes principales répondent sans crasher."""
import pytest


ROUTES = [
    "/",
    "/new",
    "/stats",
    "/catalogue",
    "/patcher",
    "/sysex",
    "/about",
    "/presets",
    "/presets/stats",
    "/search",
    "/live",
    "/projects",
    "/samples",
    "/tracks",
    "/wishlist",
    "/inspirations",
    "/mirack",
    "/obliques",
    "/influences",
    "/settings",
]


@pytest.mark.parametrize("url", ROUTES)
def test_route_smoke(client, url):
    """Chaque route doit répondre 200 ou 302 (redirect) — pas de 500."""
    resp = client.get(url, follow_redirects=False)
    assert resp.status_code in (200, 302), (
        f"Route {url} a retourné {resp.status_code}"
    )


def test_index_html(client):
    """La page d'accueil doit contenir le mot 'session' (insensible à la casse)."""
    resp = client.get("/", follow_redirects=True)
    assert resp.status_code == 200
    assert b"session" in resp.data.lower()


def test_new_form_html(client):
    """Le formulaire /new doit contenir un champ date."""
    resp = client.get("/new")
    assert resp.status_code == 200
    assert b"date" in resp.data.lower()


def test_about_html(client):
    """La page /about doit contenir 'AZA' ou 'about' (insensible à la casse)."""
    resp = client.get("/about")
    assert resp.status_code == 200
    assert b"aza" in resp.data.lower() or b"about" in resp.data.lower()
