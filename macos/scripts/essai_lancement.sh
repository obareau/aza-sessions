#!/usr/bin/env bash
# Lance l'app comme un usager et vérifie le chemin qu'il emprunte :
#   fenêtre chargée → séance saisie → sauvegarde JSON écrite → fermeture
#   → serveur arrêté → la saisie faite juste avant la fermeture est sauvegardée.
#
# « Le serveur répond » ne veut pas dire « l'app marche » : on lit le journal
# de l'app pour savoir que la FENÊTRE a affiché une page d'AZA.
#
# Usage : essai_lancement.sh "/chemin/AZA Sessions.app" [dossier de sortie]
set -euo pipefail

APP="$1"
OUT="${2:-$PWD/essai-lancement}"
BID="com.robotariis.aza-sessions"
LOGS="$HOME/Library/Logs/AZA Sessions"
JSON_DIR="$OUT/sauvegardes"

ok()   { printf '  ✓ %s\n' "$*"; }
fail() {
  printf '  ✕ %s\n' "$*" >&2
  # Les journaux dans la sortie de la CI, pas seulement dans l'artefact.
  for f in "$LOGS/app.log" "$LOGS/serveur.log"; do
    [ -f "$f" ] && { echo "── $(basename "$f")"; tail -40 "$f"; }
  done
  [ -d "$LOGS" ] && cp -R "$LOGS" "$OUT/logs" || true
  exit 1
}

mkdir -p "$JSON_DIR"
rm -rf "$LOGS"
# Sauvegardes hors de ~/Documents : sur une machine de CI, rien ne répondrait
# à la demande d'accès au dossier Documents.
defaults write "$BID" BackupDirectory "$JSON_DIR"
defaults delete "$BID" ServerPort 2>/dev/null || true

echo "▸ Lancement de $APP ($(uname -m), macOS $(sw_vers -productVersion))"
open "$APP"

PORT=47017
for _ in $(seq 1 90); do
  curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 1
done
curl -sf "http://127.0.0.1:$PORT/health" >/dev/null || fail "le serveur ne répond pas"
ok "serveur prêt sur $PORT : $(curl -s "http://127.0.0.1:$PORT/health")"

for _ in $(seq 1 60); do
  grep -q "page chargée" "$LOGS/app.log" 2>/dev/null && break
  sleep 1
done
grep -q "page chargée" "$LOGS/app.log" 2>/dev/null || fail "la fenêtre n'a chargé aucune page"
ok "fenêtre : $(grep 'page chargée' "$LOGS/app.log" | head -1)"

TAG="essai-$(uname -m)-$$"
curl -sf -o /dev/null -X POST --data-urlencode "comments=$TAG première" \
  -d "machines=MicroFreak" "http://127.0.0.1:$PORT/vite" || fail "saisie refusée"
for _ in $(seq 1 20); do
  grep -lq "$TAG première" "$JSON_DIR"/*.json 2>/dev/null && break
  sleep 1
done
grep -lq "$TAG première" "$JSON_DIR"/*.json 2>/dev/null || fail "aucune sauvegarde JSON après la saisie"
ok "sauvegarde JSON écrite par la veille : $(ls "$JSON_DIR" | tail -1)"

screencapture -x "$OUT/capture-$(uname -m).png" 2>/dev/null && ok "capture d'écran" \
  || echo "  (capture d'écran indisponible)"

# Saisie puis fermeture immédiate : seule la sauvegarde de fermeture peut la contenir.
curl -sf -o /dev/null -X POST --data-urlencode "comments=$TAG dernière" \
  "http://127.0.0.1:$PORT/vite" || fail "seconde saisie refusée"
pkill -TERM -x "AZA Sessions" || fail "app introuvable pour la fermer"
for _ in $(seq 1 20); do
  pgrep -f "aza-server/aza-server" >/dev/null || break
  sleep 1
done
pgrep -f "aza-server/aza-server" >/dev/null && fail "le serveur a survécu à l'app"
for _ in $(seq 1 10); do
  pgrep -x "AZA Sessions" >/dev/null || break
  sleep 1
done
# Vu en CI : serveur arrêté mais app bloquée à la fermeture, pour toujours.
pgrep -x "AZA Sessions" >/dev/null && fail "l'app ne s'est pas fermée"
ok "app et serveur arrêtés"
grep -q "AZA-STOPPED" "$LOGS/serveur.log" || fail "le serveur ne s'est pas arrêté proprement"
grep -lq "$TAG dernière" "$JSON_DIR"/*.json 2>/dev/null \
  || fail "la saisie faite juste avant la fermeture n'est dans aucune sauvegarde"
ok "la dernière saisie est sauvegardée"

cp -R "$LOGS" "$OUT/logs"
defaults delete "$BID" BackupDirectory 2>/dev/null || true
echo "▸ Essai réussi"
