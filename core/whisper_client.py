import urllib.request
import urllib.parse

WHISPER_URL = "http://192.168.1.100:9000/asr"


def transcribe(audio_bytes: bytes, filename: str = "audio.webm", language: str = "fr") -> str | None:
    boundary = "----WhisperBoundary"
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="audio_file"; filename="{filename}"\r\n'
        f"Content-Type: audio/webm\r\n\r\n"
    ).encode() + audio_bytes + f"\r\n--{boundary}--\r\n".encode()

    params = urllib.parse.urlencode({"task": "transcribe", "language": language, "output": "txt"})
    req = urllib.request.Request(
        f"{WHISPER_URL}?{params}",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read().decode("utf-8").strip() or None
    except Exception:
        return None
