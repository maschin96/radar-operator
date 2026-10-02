# Release bauen und veröffentlichen (#21)

## Reproduzierbarer Ablauf

1. Exakten Commit auschecken; Arbeitsbaum muss sauber sein. Godot **4.7.2** und
   zugehörige Export-Templates installieren. `scripts/install_godot.py` lädt die
   offiziellen Dateien und prüft sie gegen Godots SHA-512-Liste.
2. `./scripts/run_smoke_test.sh` ausführen.
3. `GODOT_EXPORT_MODE=release ./scripts/export_builds.sh` ausführen.
4. `python3 scripts/package_release.py` erzeugt drei Plattform-ZIPs, ein
   korrespondierendes Quellcode-ZIP und `SHA256SUMS.txt` unter `builds/release/`.
5. `python3 scripts/smoke_export.py builds/release` prüft Prüfsumme und nativen
   Headless-Start auf der aktuellen Plattform.

Die ZIP-Verpackung sortiert Einträge, erhält Unix-Modi und verwendet Commitzeit
statt lokaler Uhrzeit. Identische Eingabebinärdateien ergeben identische Archive.
**Bitidentische Godot-Binär-Exporte auf unterschiedlichen Hosts sind nicht belegt.**
Der Workflow pinnt Engine/Template-Version; Runner-Images und Systembibliotheken
bleiben variable Teile der Umgebung.

## GitHub

- [ ] Passender Versionsstand in Projekt, Presets und Changelog; CI grün.
- [ ] Review und Squash-Merge über PR gemäß Repository-Workflow.
- [ ] Tag bevorzugt signiert mit dem bereits eingerichteten persönlichen
  Signierschlüssel (`git tag -s vX.Y.Z -m 'Radar Operator vX.Y.Z'`); Signatur prüfen.
  Kein Signierschlüssel wird automatisch erstellt oder als bestehende Identität ausgegeben.
- [ ] Tag pushen. `Godot CI` testet alle drei Hosts, exportiert, verpackt, prüft
  native Starts und erstellt einen **GitHub-Release-Entwurf** mit Anhängen.
- [ ] Bei erneutem Lauf wird nur ein vorhandener Entwurf aktualisiert. Bereits
  veröffentlichte Release-Anhänge werden nicht automatisch ersetzt.
- [ ] Versionsdatei und Commit im Quellcodearchiv mit den Binärpaketen vergleichen.
- [ ] Installationsmatrix, Renderperformance und beide Playtestrunden abgenommen.
- [ ] Eine externe Person lädt das vorgesehene Paket herunter und startet es.
- [ ] Lizenz, Godot-Drittlizenzen, bekannte Einschränkungen und Prüfsummen enthalten.
- [ ] Entwurf prüfen und erst danach veröffentlichen.

Bestehende Release-Tags bleiben unverändert. Eine v0.5-Veröffentlichung erfolgt
erst nach Plattformabnahme und externen Playtests mit einem neuen Versions-Tag.

## Öffentliche Spieleseite (z. B. itch.io)

- [ ] Projektseite mit Beschreibung, Steuerung, Screenshots, Plattformen und
  GPL-3.0-or-later-Lizenz anlegen; als Entwurf prüfen.
- [ ] Dieselben geprüften Archive und Prüfsummen wie bei GitHub hochladen.
- [ ] Direkten Link auf vollständigen Quellcode des passenden Commits und
  Quellcodearchiv setzen; Lizenztext ohne zusätzliche Nutzungseinschränkungen.
- [ ] Unsig­nierten Plattformstatus und bekannte Einschränkungen klar nennen.
- [ ] Download/Installation mit einem unabhängigen Konto prüfen.
- [ ] Erst nach Abnahme öffentlich schalten. Es wurde noch keine Spieleseite angelegt.
