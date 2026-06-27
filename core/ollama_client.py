import json
import urllib.request
import urllib.error

OLLAMA_URL   = "http://192.168.1.100:11434/api/generate"
OLLAMA_MODEL = "qwen3.5:latest"
CODER_MODEL  = "qwen2.5-coder:7b"

_PROMPT_TEMPLATE = """Tu es un archiviste de l'univers AZA — une dystopie sonore Dark Ambient / Industriel, Scaër, Bretagne.
Rédige un récit de session en français, entre 80 et 150 mots, à la première personne, dans un style sombre, concis et atmosphérique.
Ne mentionne pas de prix, de marques commerciales de manière promotionnelle, ni de termes techniques comme "BPM" ou "plugin".
Intègre naturellement les éléments fournis sans les lister.

Données de session :
- Durée : {duration_min} min
- Mode : {mode}
- Intention : {intention}
- Machines : {machines}
- Effets : {effects}
- DAW : {daws}
- Synthés iOS : {synths_ios}
- Plugins : {plugins}
- Stratégie oblique : {oblique}
- Notes live : {notes_live}

Récit :"""

_PROMPT_LORE = """Tu es un archiviste de l'univers AZA — une dystopie Dark Ambient / Industriel, Scaër, Bretagne.
Rédige un court récit de session d'écriture du lore, en français, entre 80 et 150 mots, à la première personne,
dans un style sombre et atmosphérique. Synthétise ce qui a été écrit/exploré sans tout lister.

Données de session :
- Durée : {duration_min} min
- Intention : {intention}
- Stratégie oblique : {oblique}
- Notes : {notes_live}

Récit :"""

_PROMPT_VEILLE = """Tu es l'assistant d'Olivier, qui documente une session de veille technologique / codage d'outils
pour son écosystème créatif AZA. Rédige un résumé factuel en français, entre 60 et 120 mots, à la première personne,
clair et concret. Mentionne les pistes explorées et ce qui reste à faire, sans jargon promotionnel.

Données de session :
- Durée : {duration_min} min
- Intention : {intention}
- Notes : {notes_live}

Résumé :"""

_PROMPTS_BY_TYPE = {"lore": _PROMPT_LORE, "veille": _PROMPT_VEILLE}


def generate_recap(session_data: dict, timeout: int = 30):
    template = _PROMPTS_BY_TYPE.get(session_data.get("session_type") or "music", _PROMPT_TEMPLATE)
    prompt = template.format(
        duration_min=session_data.get("duration_min", "?"),
        mode=session_data.get("mode") or "—",
        intention=session_data.get("intention") or "—",
        machines=session_data.get("machines") or "—",
        effects=session_data.get("effects") or "—",
        daws=session_data.get("daws") or "—",
        synths_ios=session_data.get("synths_ios") or "—",
        plugins=session_data.get("plugins") or "—",
        oblique=session_data.get("oblique") or "—",
        notes_live=session_data.get("notes_live") or "—",
    )
    payload = json.dumps({
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.8},
        # désactive le chain-of-thought de qwen3.5
        "think": False,
    }).encode()

    try:
        req = urllib.request.Request(
            OLLAMA_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read())
            return body.get("response", "").strip() or None
    except Exception:
        return None


_REWRITE_TEMPLATE = """Tu es un correcteur littéraire pour l'univers AZA — dystopie sonore Dark Ambient / Industriel.
Réécris le texte suivant en corrigeant l'orthographe, la grammaire et la fluidité.
Conserve exactement le sens, la longueur approximative, le style à la première personne et l'atmosphère sombre.
Ne rajoute pas de contenu. Ne résume pas. Retourne uniquement le texte corrigé, sans commentaire.

Texte original :
{text}

Texte corrigé :"""


def rewrite_recap(text: str, timeout: int = 30):
    if not text or not text.strip():
        return None
    prompt = _REWRITE_TEMPLATE.format(text=text.strip())
    payload = json.dumps({
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.3},
        "think": False,
    }).encode()

    try:
        req = urllib.request.Request(
            OLLAMA_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read())
            return body.get("response", "").strip() or None
    except Exception:
        return None


_REVIEW_TEMPLATE = """You are a senior Python/Flask developer reviewing a git diff for a small Flask+SQLite app.
Be concise. Point out only real issues: bugs, security problems, broken logic, missing edge cases.
If the diff looks fine, say so in one line. Skip style nits.

```diff
{diff}
```

Review:"""


def review_diff(diff: str, timeout: int = 60):
    if not diff.strip():
        return "Empty diff — nothing to review."
    prompt = _REVIEW_TEMPLATE.format(diff=diff[:6000])
    payload = json.dumps({
        "model": CODER_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.2},
    }).encode()

    try:
        req = urllib.request.Request(
            OLLAMA_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read())
            return body.get("response", "").strip() or None
    except Exception as e:
        return f"Ollama unreachable: {e}"
