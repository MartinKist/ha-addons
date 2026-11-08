# Claude Code – Remote Control auf Home Assistant /config

Home-Assistant-Add-on (in der aktuellen HA-Oberflaeche heissen Add-ons „Apps“) aus dem Repository
`https://gitlab.com/MartinKist/ha-addons`, das
[Claude Code](https://code.claude.com/docs/en/overview) im **Remote-Control-Server-Modus**
auf dem HA-Konfigurationsverzeichnis laufen laesst. Die Session wird aus der Claude-App
bzw. unter <https://claude.ai/code> gesteuert, der `claude`-Prozess und alle Dateien bleiben
auf dem HA-Geraet.

| Container          | Bedeutung                                   |
|--------------------|---------------------------------------------|
| `/homeassistant`   | HA `/config` (lesen + schreiben)            |
| `/data`            | `$HOME` von Claude Code: Login, Settings, Sitzungen (persistent) |
| `/data/options.json` | Add-on-Optionen (`session_name`)          |

## Voraussetzungen

- Claude-Abo **Pro, Max, Ultra, Team oder Enterprise**. API-Keys und Tokens aus
  `claude setup-token` funktionieren fuer Remote Control **nicht**.
- Fuer den einmaligen Login nur ein Browser: Das Add-on bringt ein Web-Terminal (Ingress) mit.
- Ausgehender Internetzugang des HA-Geraets (api.anthropic.com).

## Dateien

```
claude-code/
├── config.yaml                 Add-on-Metadaten, Mapping, Ingress, Optionen, Version
├── Dockerfile                  node:22-alpine + Claude Code + ha-CLI + ttyd + tini
├── run.sh                      Startskript (Web-Terminal, Erstkonfiguration, Login-Erkennung, exec claude remote-control)
├── CHANGELOG.md                wird in HA unter "Changelog" angezeigt
└── README.md                   diese Datei ("Dokumentation" in HA)
```

## Installation

1. **Einstellungen → Add-ons/Apps → Add-on-Store** (bzw. „App installieren“) öffnen,
   oben rechts **⋮ → Repositories** → `https://gitlab.com/MartinKist/ha-addons` hinzufügen.
2. Ggf. **⋮ → Nach Updates suchen** und Seite neu laden; Abschnitt **Martin Kistler HA Add-ons** →
   **Claude Code** → **Installieren**. Der Supervisor baut das Image auf dem Geraet (dauert einige Minuten).
3. Unter **Konfiguration** den `session_name` setzen (pro HA-Instanz einen eigenen Namen, dann sind die
   Sessions in der Claude-App unterscheidbar).
4. **Starten**. Ohne Login wartet das Add-on und schreibt die Anleitung ins **Protokoll**.

## Einmaliger Login (ueber das Web-Terminal)

Seit 1.1.0 kein `docker exec` mehr noetig:

1. Auf der Add-on-Seite **„Benutzeroberflaeche oeffnen“** (Ingress). Es oeffnet sich ein Terminal im Container
   (`HOME=/data`, Arbeitsverzeichnis `/homeassistant`).
2. `claude` eingeben, im Claude-Prompt **`/login`** → Login-URL im Browser oeffnen (claude.ai-Konto waehlen) →
   Code zurueck ins Terminal einfuegen → **`/exit`**.
3. Fertig. `run.sh` erkennt die Anmeldedaten innerhalb von 10 s und startet Remote Control; die Session erscheint
   unter **claude.ai → Code** (und in der Claude-App unter Code) mit dem konfigurierten `session_name`.

Vertrauen in `/homeassistant` und die Remote-Control-Zustimmung belegt `run.sh` beim Start in `/data/.claude.json`
vor, deshalb entfallen die frueheren Dialoge. Login, Settings und Sitzungen liegen in `/data` und ueberleben
Neustarts und Updates (nicht aber ein Deinstallieren).

Das Web-Terminal taugt auch zur Diagnose (`ha core info`, `jq`, `git`, `claude --version`). Haengt Remote
Control, das Add-on neu starten.

**Umzug vom frueheren lokalen Add-on** (`local_claude_code`): Das Repository-Add-on hat einen anderen Slug und
damit ein eigenes `/data`. Einfachster Weg: neues Add-on installieren, Login wie oben, altes Add-on deinstallieren
und den Ordner `claude-code` aus `addons` loeschen. Wer `settings.json` (Berechtigungen) und die Memory-Notizen
(`/data/.claude/projects/`) mitnehmen will, kopiert sie vorher aus dem alten Container, z. B. mit
`docker cp addon_local_claude_code:/data/.claude/settings.json /config/claude-migrate/` (Advanced SSH & Web Terminal)
und im Web-Terminal des neuen Add-ons von `/homeassistant/claude-migrate/` nach `/data/.claude/`; danach den
Ordner loeschen (enthaelt keine Zugangsdaten, aber Arbeitsnotizen).

## Berechtigungen (Beispiel `settings.json`)

Die Datei `/data/.claude/settings.json` wird **nicht** vom Add-on angelegt, sie ist Laufzeit-
konfiguration. Beispiel, das Lesen/Bearbeiten in `/config` sowie Konfigurationspruefung und
Core-Neustart ohne Rueckfrage erlaubt:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Edit",
      "Bash(ha core check)",
      "Bash(ha core restart)"
    ]
  }
}
```

Anlegen z. B. so:

```bash
# im Web-Terminal des Add-ons:
mkdir -p /data/.claude && cat > /data/.claude/settings.json <<'JSON'
{ "permissions": { "allow": ["Read", "Edit", "Bash(ha core check)", "Bash(ha core restart)"] } }
JSON
```

Die `ha`-CLI ist im Image enthalten; `hassio_api: true` + `hassio_role: homeassistant` in
`config.yaml` erlauben `ha core check` / `ha core restart` ueber die Supervisor-API.

## Update

Claude Code aktualisiert sich im Container nicht selbst (`DISABLE_AUTOUPDATER=1`); beim Rebuild wird die
jeweils aktuelle Claude-Code-Version per `npm install -g` geholt.

1. Im Repository `config.yaml` → `version` hochzaehlen, `CHANGELOG.md` ergaenzen, committen.
2. Add-on-Store → **⋮ → Nach Updates suchen** → Add-on **aktualisieren**.
   Alternativ im Web-Terminal: `ha apps update <slug>` (Slug siehe Add-on-URL, z. B. `1a2b3c4d_claude_code`).

## Fallback: Start ohne TTY schlaegt fehl

Der Supervisor startet den Container ohne Terminal. Normalerweise reicht das, da Vertrauen
und Remote-Control-Zustimmung von `run.sh` vorbelegt werden. Falls das Protokoll trotzdem
`Workspace not trusted` zeigt oder auf eine Eingabe wartet, in `run.sh` die Zeile

```bash
exec claude remote-control --spawn same-dir --name "${SESSION}"
```

auskommentieren und den Fallback darunter aktivieren:

```bash
exec script -qfec "claude remote-control --spawn same-dir --name \"${SESSION}\"" /dev/null
```

`script` stammt aus dem Paket `util-linux-misc`, das im Dockerfile bereits installiert wird.
Danach `version` hochzaehlen und committen.

## Fehlersuche

- Protokoll: Add-on-Seite → **Protokoll**, oder im Web-Terminal `ha apps logs <slug>`.
- Web-Terminal oeffnet sich nicht: Add-on-Protokoll pruefen (ttyd startet als erstes in `run.sh`);
  Ingress braucht eine HA-Anmeldung im Browser.
- `Remote Control requires a claude.ai subscription`: nicht mit claude.ai-Konto angemeldet,
  oder `ANTHROPIC_API_KEY`/`ANTHROPIC_AUTH_TOKEN` gesetzt.
- `Remote Control requires a full-scope login token`: Token aus `claude setup-token` wird
  verwendet. Stattdessen `/login` wie oben.
- Add-on erscheint nicht im Store: Supervisor-Log pruefen (**Einstellungen → System →
  Protokolle → Supervisor**), dort meldet der Supervisor Fehler in `config.yaml` oder `repository.yaml`.
- Session nach Neustart des Add-ons weg: `claude remote-control` holt Sessions desselben
  Verzeichnisses beim naechsten Start zurueck (bis ca. 4 Stunden nach dem Stopp).
