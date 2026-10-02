# Datenkompatibilität und Wiederherstellung

## Unterstützte Versionen

| Daten | Aktuell | Automatische Migration | Grenze |
| --- | --- | --- | --- |
| Kampagnenprofil | 2 | 1 → 2 | Siege, Bestwerte und Missionskennungen bleiben erhalten; berechtigte Folgemissionen werden ergänzt |
| Einstellungen | 2 | 1 → 2 | Bestehende Werte bleiben; Atmosphäre und Farbenblindheit erhalten sichere Defaults |
| Missionsspielstand | 6 | 5 → 6 | Inhaltsschema 1; vollständiger Zustand wird deterministisch rekonstruiert und verglichen |
| Szenarioinhalt | 1 | keine ältere veröffentlichte Version | Neuere Inhalts-, Netz-, Gelände- und Störmodelle werden abgelehnt |

Save-Formate 1–4 verwenden ältere Simulationsmodelle. Eine verlustfreie Migration
ist nicht zugesichert; die Originaldatei bleibt erhalten und kann mit ihrer
ursprünglichen Spielversion geöffnet werden. Kampagnenfortschritt und Einstellungen
sind unabhängig davon migrierbar. Bei geändertem Inhalt verhindert der Vergleich
des rekonstruierten Zustands eine stille Fortsetzung mit abweichender Simulation.

Migrationen arbeiten auf Kopien, sind idempotent und schreiben erst beim nächsten
regulären Speichern. Ein geladenes Save behält seinen ursprünglichen Szenariopfad,
auch nach erneutem Speichern. Version 6 speichert zusätzlich die Inhaltsversion.
Unbekannte Missionskennungen im Profil bleiben erhalten; fehlende Inhalte sind in
der Missionsauswahl nicht startbar.

## Schutz und Bedienung

Unbekannte neuere Formate, beschädigtes JSON und ungültige Feldtypen werden beim
Laden und vor dem Ersetzen einer vorhandenen Datei geprüft. Profil und Einstellungen
können vorläufig mit Standardwerten weiterlaufen. Ihr Original wird **nicht**
automatisch verschoben oder ersetzt; Speichern auf diesen Pfad bleibt gesperrt.

Wiederherstellung: Den im Spiel angezeigten Dateipfad zuerst sichern und umbenennen
(zum Beispiel `.original` anhängen). Dann neu starten beziehungsweise bei den
Einstellungen erneut übernehmen. Alternativ die zur Datei passende Spielversion
verwenden. Vorläufig erspielter Fortschritt ist bei gesperrtem Profil nicht dauerhaft.

Fixture- und Regressionstests prüfen Migration, Idempotenz, erneutes Speichern/
Laden, deterministische Fortsetzung, fehlerhafte Befehle und bytegenauen Erhalt
inkompatibler Dateien. Die festen JSON-Fixtures stehen in `scripts/tests/fixtures/`.
