#!/bin/bash
# build_mac.sh — Compile RobotariisSessions pour macOS
# Lance depuis le dossier robotariis_sessions/

echo "🤖 Build RobotariisSessions — macOS"
echo "====================================="

# Vérifier Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 requis. Installe depuis https://python.org"
    exit 1
fi

echo "✓ $(python3 --version)"

# Installer dépendances
echo "→ Installation Flask + PyInstaller..."
pip3 install flask pyinstaller -q 2>/dev/null || pip3 install flask pyinstaller --user -q
echo "✓ Dépendances OK"

# Nettoyer les builds précédents
rm -rf build/ dist/ *.spec

# Créer static/ si absent (dossier vide non versionné)
mkdir -p static

# Compiler
echo "→ Compilation en cours..."
pyinstaller \
    --onedir \
    --name "RobotariisSessions" \
    --add-data "templates:templates" \
    --add-data "static:static" \
    --hidden-import flask \
    --hidden-import jinja2 \
    --hidden-import werkzeug \
    --hidden-import sqlite3 \
    app.py

if [ -f "dist/RobotariisSessions/RobotariisSessions" ]; then
    echo ""
    echo "✅ App créée : dist/RobotariisSessions/"
    echo "   Taille : $(du -sh dist/RobotariisSessions | cut -f1)"
    echo ""
    echo "→ Pour lancer : ./dist/RobotariisSessions/RobotariisSessions"
    echo "→ Puis ouvrir http://localhost:5001"
else
    echo "❌ Échec de la compilation"
    exit 1
fi

# Nettoyer les fichiers temporaires
rm -rf build/ *.spec
echo "✓ Nettoyage OK"
