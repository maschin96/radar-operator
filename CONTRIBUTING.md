# Zu Radar Operator beitragen

Danke für dein Interesse an Radar Operator. Kleine, klar abgegrenzte Änderungen sind am einfachsten zu prüfen und zusammenzuführen.

Der allgemeine Ablauf für Branches, Commits, Pull Requests, Reviews und Releases ist im [agilen Git-Workflow](AGILE_GIT_WORKFLOW.md) definiert. Die folgenden Hinweise ergänzen ihn um projektspezifische Anforderungen.

## Entwicklungsumgebung

1. Godot 4.7.2 installieren.
2. Repository forken oder klonen.
3. `project.godot` im Godot Project Manager importieren.
4. Vor einer Änderung die vollständige Suite ausführen:

   ```sh
   ./scripts/run_smoke_test.sh
   ```

## Arbeitsweise

- Für Fehler oder größere Funktionen zuerst ein GitHub Issue anlegen.
- Pro Pull Request nur eine klar beschriebene Änderung umsetzen.
- Simulationslogik und Darstellung getrennt halten.
- Neue Balancingwerte als Godot Resources unter `data/` pflegen.
- Änderungen an der Simulation mit deterministischen Tests abdecken.
- Keine generierten Ordner wie `.godot/` oder `builds/` committen.
- `.gd.uid`-Dateien gehören zum Godot-Projekt und werden mitgeführt.
- Neue Assets müssen selbst erstellt, passend lizenziert und in der Änderung dokumentiert sein.
- Mit einem Beitrag bestätigst du, dass du ihn unter `GPL-3.0-or-later` veröffentlichen darfst.

## Stil

- GDScript statisch typisieren, soweit Godot dies sinnvoll unterstützt.
- Dateien und Ordner in `snake_case`, benannte Klassen in `PascalCase` schreiben.
- Tabs für Godot- und GDScript-Dateien, zwei Leerzeichen für Markdown und YAML verwenden.
- Warnungen gezielt beheben und nicht global deaktivieren.
- Reale Staaten, Organisationen und Waffensysteme nicht detailgetreu nachbilden.

## Pull-Request-Checkliste

- [ ] Projekt wird mit Godot 4.7.2 fehlerfrei importiert.
- [ ] `./scripts/run_smoke_test.sh` besteht vollständig.
- [ ] Neue oder geänderte Mechaniken sind getestet.
- [ ] Dokumentation und `CHANGELOG.md` sind bei Bedarf aktualisiert.
- [ ] Der Pull Request enthält keine Builds, Logs, Savegames oder Zugangsdaten.

## Fehler melden

Bitte Godot-Version, Betriebssystem, reproduzierbare Schritte, erwartetes Verhalten und relevante Logauszüge angeben. Savegames oder Logs vor dem Hochladen auf persönliche Daten prüfen.

## Lizenz

Beiträge werden unter der [GNU General Public License v3.0 or later](LICENSE) veröffentlicht. Fremdcode und Assets müssen GPL-kompatibel sein und ihre Herkunft sowie Lizenz nachvollziehbar dokumentieren.
