# Änderungsverlauf

Alle wesentlichen Änderungen an Radar Operator werden in diesem Dokument festgehalten.

## [Unveröffentlicht]

### Geplant

- v0.5 Public Demo mit handgefertigter Mini-Kampagne
- regelbasierte Steuerung mit manueller Trackpriorität und Einsatzfreigabe
- hochwertige stilisierte 2D-Leitstandpräsentation
- plattformspezifische Laufzeit-, Eingabe- und Barrierefreiheitstests

## [0.2.0] – 2026-08-29

### Hinzugefügt

- versionierter, automatisch validierter Szenariokatalog mit Kampagnenmetadaten
- Hauptmenü und datengetriebene Missionsauswahl mit Tastaturnavigation
- lokales Kampagnenprofil mit Freischaltungen, Ergebnissen und sicherem Zurücksetzen
- persistentes Einstellungsmodell mit sicheren Defaults und Konfliktprüfung für Tastenbelegungen
- gemeinsames UI-Theme und dokumentiertes Designsystem für drei Zielauflösungen
- manuelle Trackpriorität sowie Freigabe, Sperre und Rücknahme über protokollierte Befehle
- drei missionsreferenzierbare Einsatzregelprofile sowie ein sicherer Editor für benannte eigene Profile mit Konfliktprüfung und unverbindlicher Vorschau
- strukturierte Erklärungen für Zuweisung, Nicht-Zuweisung und Abbruch einschließlich aller Bewertungsanteile und geprüften Trackkandidaten
- acht zusätzliche automatisierte Testfälle für Katalog, App-Navigation, Profil, Einstellungen und Zielsteuerung
- neun weitere deterministische Testfälle für Freigabegrenzen, Profilvorschau, Entscheidungserklärungen, UI-Integration und Inhaltsreferenzen
- Tutorial Mission 1 mit eigener, fehlertoleranter Übungskonfiguration, verständlicherem Automatik-Hinweis und verbindlichem Unbeschädigt-Erfolgstest

### Behoben

- #6: Laufende Einsätze werden bei Sperre, fehlender Freigabe, Klassifikationsverlust, Reichweitenverlust oder Ausfall ohne Munitionsverbrauch abgebrochen.
- Manuelle Freigaben prüfen Einsatzgrenzen; Ablehnungen mit Ursache und Zeitstempel bleiben über Save/Load erhalten.
- Trackdetails erklären Einsatzbereitschaft je System; Kartenbeschriftungen zeigen Priorität und Freigabestatus.

### Migration

- Spielstände verwenden Formatversion 2, da vollständige Regelprofile und abgelehnte Befehle deterministisch rekonstruiert werden. Ältere Formatversionen werden mit einer eindeutigen Meldung abgelehnt; die allgemeine Save-Migration folgt in #18.

### Geändert

- zukünftige Produktvision und priorisierte Roadmap dokumentiert
- Produktbacklog in 21 klar abgegrenzte Arbeitspakete strukturiert
- Repository unter `GPL-3.0-or-later` lizenziert
- Projekt- und Desktop-Exportversionen auf 0.2.0 vereinheitlicht
- Desktop-Exports legen ihre Zielordner zuverlässig an und prüfen die erzeugten Artefakte
- die Testsuite verhindert abweichende Projekt-, Export- und Changelog-Versionen

## [0.1.0] – 2026-08-26

### Hinzugefügt

- vollständiger Godot-4-Projektaufbau mit taktischem Kontrollraum
- deterministische Fixed-step-Simulation mit Zeitsteuerung
- datengetriebene Szenarien, Bedrohungen, Sensoren und Abwehrsysteme
- Sensorerfassung, Messungen, Track-Fusion und Unsicherheitsdarstellung
- Platzierung, Budget, Reichweiten und Zielpriorisierung
- Infrastruktur-, Energie-, Schadens- und Missionssysteme
- Hauptoberfläche, Ereignisprotokoll, Missionsbericht und Replay-Daten
- deterministisches Speichern und Laden
- Barrierefreiheitsoptionen und synthetische Warntöne
- Tutorial Mission 1 mit zehn kontextuellen Lernschritten
- 59 automatisierte Unit-, Integrations- und End-to-End-Testfälle
- Desktop-Export-Presets für macOS, Windows und Linux

### Geprüft

- vollständige Testabnahme mit Godot 4.7.2
- nativer Start des macOS-Debug-Exports
- erfolgreiche Erzeugung und Formatprüfung der Windows- und Linux-Debug-Builds
