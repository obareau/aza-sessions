"""Vérifie chaque binaire Mach-O d'une app : Intel ET Apple Silicon, macOS minimum.

Usage : python verifier_binaires.py "AZA Sessions.app" 12.0

Un seul binaire compilé pour arm64 seulement, ou pour macOS 14, et l'app ne
s'ouvre pas sur le MacBook Intel sous Monterey — sans message utile. On le
vérifie ici plutôt que de le découvrir au studio.
"""
import os
import re
import subprocess
import sys

REQUIRED = {"x86_64", "arm64"}
MAGICS = {
    b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe",   # Mach-O 64/32
    b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",   # universel
}


def is_macho(path):
    try:
        with open(path, "rb") as f:
            return f.read(4) in MAGICS
    except OSError:
        return False


def archs(path):
    out = subprocess.run(["lipo", "-archs", path], capture_output=True, text=True)
    return set(out.stdout.split()) if out.returncode == 0 else set()


def minimum_macos(path, arch):
    out = subprocess.run(["otool", "-arch", arch, "-l", path],
                         capture_output=True, text=True).stdout
    m = re.search(r"cmd LC_BUILD_VERSION.*?\n\s*minos ([\d.]+)", out, re.S) \
        or re.search(r"cmd LC_VERSION_MIN_MACOSX.*?\n\s*version ([\d.]+)", out, re.S)
    return m.group(1) if m else None


def as_tuple(v):
    return tuple(int(x) for x in v.split("."))


def main(app, minimum):
    problems, checked = [], 0
    for root, _dirs, files in os.walk(app):
        for name in files:
            path = os.path.join(root, name)
            if os.path.islink(path) or not is_macho(path):
                continue
            checked += 1
            rel = os.path.relpath(path, app)
            found = archs(path)
            if not REQUIRED <= found:
                problems.append(f"{rel} : architectures {sorted(found)}, il faut {sorted(REQUIRED)}")
                continue
            for arch in sorted(REQUIRED):
                v = minimum_macos(path, arch)
                if v and as_tuple(v) > as_tuple(minimum):
                    problems.append(f"{rel} [{arch}] : exige macOS {v} (> {minimum})")
    print(f"{checked} binaires Mach-O vérifiés")
    for p in problems:
        print(f"✕ {p}")
    if not checked:
        print("✕ aucun binaire trouvé — mauvais chemin ?")
        return 1
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "12.0"))
