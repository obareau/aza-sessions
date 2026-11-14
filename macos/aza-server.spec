# -*- mode: python ; coding: utf-8 -*-
# PyInstaller : le serveur AZA en dossier autonome, universel (Intel + Apple Silicon).
# Lancé par macos/build.sh, qui vérifie ensuite chaque binaire produit.
import os

ROOT = os.path.abspath(os.path.join(SPECPATH, ".."))

a = Analysis(
    [os.path.join(SPECPATH, "server_main.py")],
    pathex=[ROOT],
    datas=[
        (os.path.join(ROOT, "templates"), "templates"),
        (os.path.join(ROOT, "static"), "static"),
    ],
    # Rien de dynamique dans AZA : tous les blueprints sont importés en dur par
    # app.py, que server_main.py importe. Ce qui manquerait, le --selftest le
    # verrait (page en 500).
    hiddenimports=[],
    excludes=["tkinter", "pytest", "gunicorn"],
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="aza-server",
    console=True,
    target_arch="universal2",
    codesign_identity=None,
    strip=False,
    upx=False,
)
coll = COLLECT(exe, a.binaries, a.datas, name="aza-server", strip=False, upx=False)
