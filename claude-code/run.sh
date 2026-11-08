#!/usr/bin/env bash
# Startskript des Add-ons "Claude Code" (Kindprozess von tini).
set -euo pipefail

# Login (.claude/.credentials.json), Vertrauen/Remote-Control-Zustimmung (.claude.json),
# Settings und Sitzungsverlauf liegen unter $HOME -> /data ist persistenter Add-on-Speicher.
export HOME=/data
export DISABLE_AUTOUPDATER=1
# NICHT setzen: CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC, DISABLE_GROWTHBOOK, ANTHROPIC_API_KEY,
# ANTHROPIC_BASE_URL -> jede dieser Variablen deaktiviert Remote Control.

SESSION="$(jq -r '.session_name // "Home Assistant"' /data/options.json)"
CREDENTIALS="$HOME/.claude/.credentials.json"
WORKDIR=/homeassistant   # HA-/config (config.yaml: map homeassistant_config, rw)
cd "$WORKDIR"

# ---- Web-Terminal (Ingress) ----------------------------------------------------------
# ttyd lauscht auf dem Ingress-Port; erreichbar nur ueber die HA-Oberflaeche ("Benutzeroberflaeche
# oeffnen"). Darin: `claude` -> /login fuer den einmaligen Login, sonst Diagnose (ha, jq, git ...).
ttyd -W -p 7681 -t fontSize=14 -t 'theme={"background":"#1e1e1e"}' bash -l >/dev/null 2>&1 &

# ---- Erstkonfiguration ohne interaktive Dialoge ----------------------------------------
# Claude Code fragt beim ersten Start nach Vertrauen in das Arbeitsverzeichnis und nach der
# Zustimmung zu Remote Control. Beides steht in /data/.claude.json und wird hier vorbelegt,
# damit nach dem Login nichts mehr bestaetigt werden muss.
mkdir -p "$HOME/.claude"
if [ ! -s "$HOME/.claude.json" ]; then
  jq -n --arg dir "$WORKDIR" '{
    hasCompletedOnboarding: true,
    remoteDialogSeen: true,
    projects: { ($dir): { hasTrustDialogAccepted: true, allowedTools: [], mcpServers: {} } }
  }' > "$HOME/.claude.json"
else
  tmp="$(mktemp)"
  jq --arg dir "$WORKDIR" '
    .hasCompletedOnboarding = true
    | .remoteDialogSeen = true
    | .projects[$dir] = ((.projects[$dir] // {}) + {hasTrustDialogAccepted: true})
  ' "$HOME/.claude.json" > "$tmp" && mv "$tmp" "$HOME/.claude.json"
fi

# ---- Auf Login warten ------------------------------------------------------------------
if [ ! -s "$CREDENTIALS" ]; then
  cat <<'MSG'
==================================================================
 Claude Code: Noch nicht angemeldet.

 Auf der Add-on-Seite "Benutzeroberflaeche oeffnen" (Web-Terminal) und dort eingeben:

   claude

 Im Claude-Prompt:  /login  -> Login-URL im Browser oeffnen -> Code einfuegen -> /exit

 Das Add-on erkennt den Login automatisch und startet Remote Control
 (kein Neustart noetig). Diese Meldung wiederholt sich alle 5 Minuten.
==================================================================
MSG
  n=0
  while [ ! -s "$CREDENTIALS" ]; do
    sleep 10
    n=$((n+1))
    if [ $((n % 30)) -eq 0 ]; then echo "Warte auf Login (Web-Terminal -> claude -> /login) ..."; fi
  done
  echo "Login gefunden."
fi

echo "Starte Claude Code Remote Control als Session \"${SESSION}\" in $(pwd) ..."

# Normalfall: Server-Modus ohne TTY. Vertrauen und Remote-Control-Zustimmung sind oben vorbelegt.
exec claude remote-control --spawn same-dir --name "${SESSION}"

# ---- Fallback: Pseudo-TTY ------------------------------------------------------------
# Falls `claude remote-control` ohne TTY nicht startet (z. B. es wartet auf eine Tastatureingabe),
# die exec-Zeile oben auskommentieren und stattdessen ueber `script` (Paket util-linux-misc) starten:
#
# exec script -qfec "claude remote-control --spawn same-dir --name \"${SESSION}\"" /dev/null
