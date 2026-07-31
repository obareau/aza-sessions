import json
import urllib.request

N8N_BASE = "http://192.168.1.100:5678/webhook"

# ── Webhooks disponibles ───────────────────────────────────────────────────
# AZA · ntfy       → POST /webhook/aza-notif
# AZA · Ollama async → POST /webhook/aza-ollama


def _post(path: str, payload: dict) -> bool:
    try:
        data = json.dumps(payload).encode()
        req = urllib.request.Request(
            f"{N8N_BASE}/{path}",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status < 400
    except Exception:
        return False


def notify(message: str, title: str = "AZA", tags: str = "robot", priority: str = "default") -> bool:
    """Envoie une notification ntfy via n8n."""
    return _post("aza-notif", {
        "title": title,
        "message": message,
        "tags": tags,
        "priority": priority,
    })


def ollama_async(prompt: str, notify_title: str = "AZA · Ollama", model: str = "qwen3.5:cloud", temperature: float = 0.7) -> bool:
    """Lance une génération Ollama en arrière-plan — résultat envoyé via ntfy."""
    return _post("aza-ollama", {
        "prompt": prompt,
        "model": model,
        "temperature": temperature,
        "notify_title": notify_title,
    })
