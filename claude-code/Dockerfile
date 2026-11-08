# Claude Code Remote Control fuer Home Assistant (Add-on / "App").
# Seit Supervisor 2026.04 wird BUILD_FROM nicht mehr uebergeben -> festes FROM.
FROM node:22-alpine

# bash/git/ripgrep/jq : Laufzeit fuer run.sh und Claude Code
# tini               : PID 1 (config.yaml hat init: false)
# curl/ca-certs      : Download der HA-CLI
# util-linux-misc    : liefert `script` fuer den Pseudo-TTY-Fallback in run.sh
# ttyd               : Web-Terminal fuer Ingress (Login ohne docker exec)
RUN apk add --no-cache bash git ripgrep jq tini curl ca-certificates util-linux-misc ttyd

# Home Assistant CLI ("ha ...") fuer die Supervisor-API (config.yaml: hassio_api: true).
# Der Build laeuft auf dem Zielgeraet, daher reicht uname -m fuer die Architektur.
RUN set -eu; \
    case "$(uname -m)" in \
      x86_64)  HA_ARCH=amd64 ;; \
      aarch64) HA_ARCH=aarch64 ;; \
      *) echo "Nicht unterstuetzte Architektur: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/ha "https://github.com/home-assistant/cli/releases/latest/download/ha_${HA_ARCH}"; \
    chmod +x /usr/local/bin/ha

# Claude Code global installieren; Auto-Update im Container aus (Update = Add-on-Rebuild).
ENV DISABLE_AUTOUPDATER=1
RUN npm install -g @anthropic-ai/claude-code

# HOME=/data auch fuer das Web-Terminal und `docker exec`, damit Login/Settings immer in /data (persistent) landen.
ENV HOME=/data

COPY run.sh /run.sh
RUN chmod +x /run.sh

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/run.sh"]
