#!/bin/bash
# Journal de Sessions Robōtariis v0.3.1
# Double-clic pour lancer

cd "$(dirname "$0")"

echo "🤖 Journal de Sessions Robōtariis v0.3.1"
echo "=========================================="

# Vérifier Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 non trouvé. Installe Python depuis https://python.org"
    read -p "Appuie sur Entrée pour quitter..."
    exit 1
fi

echo "✓ Python3 trouvé : $(python3 --version)"

# Installer Flask si absent
if ! python3 -c "import flask" &> /dev/null; then
    echo "→ Installation de Flask..."
    python3 -m pip install flask --break-system-packages -q
    echo "✓ Flask installé"
else
    echo "✓ Flask présent"
fi

# Ouvrir le navigateur après 1.5 secondes
(sleep 1.5 && open http://localhost:5000) &

echo ""
echo "→ Lancement sur http://localhost:5000"
echo "→ Ctrl+C pour arrêter"
echo ""

python3 app.py
