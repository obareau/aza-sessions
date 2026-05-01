import random

from constants import DEFAULT_OBLIQUE, ITEM_TYPES, VERSION
from db import get_db


def rand_oblique():
    conn = get_db()
    rows = conn.execute(
        "SELECT text FROM obliques WHERE active=1"
    ).fetchall()
    conn.close()
    if not rows:
        return DEFAULT_OBLIQUE[0]
    return random.choice(rows)["text"]


def get_catalogue():
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM catalogue WHERE active=1 ORDER BY type, name"
    ).fetchall()
    conn.close()
    result = {k: [] for k in ITEM_TYPES}
    for r in rows:
        if r["type"] in result:
            result[r["type"]].append(dict(r))
    return result


def get_influences_active():
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM influences WHERE active=1 ORDER BY name"
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def session_to_md(s):
    project_line = f"\n**Projet:** {s['project_title']}" if s['project_title'] else ""
    return f"""# Session {s['date']}

**Mode:** {s['mode'] or '—'}
**Intention:** {s['intention'] or '—'}
**Durée:** {s['duration_min'] or '—'} min
**Énergie:** {'⚡' * (s['energy_level'] or 0)}
**Note:** {'★' * (s['rating'] or 0)}{project_line}

## Machines
{s['machines'] or '—'}

## Effets hardware
{s['effects'] or '—'}

## DAW
{s['daws'] or '—'}

## Synthés iOS
{s['synths_ios'] or '—'}

## Plugins
{s['plugins'] or '—'}

## Signal routing
{s['signal_routing'] or '—'}

## Algo MicroFreak
{s['microfreak_algo'] or '—'}

## Patches / Presets
{s['patches'] or '—'}

## Caractère sonore
{s['character'] or '—'}

## Timestamps intéressants
{s['timestamps'] or '—'}

## Fichier audio
{s['audio_file'] or '—'}

## Tags
{s['tags'] or '—'}

## Influences
{s['influences'] or '—'}

## Lien lore Robōtariis
{s['lore_link'] or '—'}

## Stratégie Robōtariis
> {s['oblique'] or '—'}

## Notes libres
{s['comments'] or '—'}

## Récap session Claude
{s['recap_claude'] or '—'}

---
*À retravailler: {'Oui' if s['to_rework'] else 'Non'} | Potentiel release: {'Oui' if s['release_potential'] else 'Non'}*
*Journal de Sessions Robōtariis v{VERSION}*
"""
