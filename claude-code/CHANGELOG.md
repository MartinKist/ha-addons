# Changelog

## 1.1.0
- Umzug vom lokalen Add-on in das Repository `github.com/MartinKist/ha-addons` (neuer Slug `<repo-hash>_claude_code`, eigenes `/data`; einmal neu einloggen).
- **Web-Terminal über Ingress** („Benutzeroberfläche öffnen“, ttyd): Login per `claude` → `/login` direkt aus HA, kein `docker exec` mehr.
- `run.sh` belegt Vertrauen in `/homeassistant` und die Remote-Control-Zustimmung in `/data/.claude.json` vor und wartet auf den Login; Remote Control startet danach automatisch ohne Neustart.

## 1.0.0
- Erste Version: node:22-alpine, Claude Code global, HA-CLI, tini; `homeassistant_api: true`, `hassio_role: homeassistant`.
