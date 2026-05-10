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


def generate_recap(session_data: dict, timeout: int = 30):
    prompt = _PROMPT_TEMPLATE.format(
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
