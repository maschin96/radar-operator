# Änderungsverlauf

Alle wesentlichen Änderungen an Radar Operator werden in diesem Dokument festgehalten.

## [Unveröffentlicht]

### Hinzugefügt

- versionierter, automatisch validierter Szenariokatalog mit Kampagnenmetadaten
- Hauptmenü und datengetriebene Missionsauswahl mit Tastaturnavigation
- lokales Kampagnenprofil mit Freischaltungen, Ergebnissen und sicherem Zurücksetzen
- persistentes Einstellungsmodell mit sicheren Defaults und Konfliktprüfung für Tastenbelegungen
- gemeinsames UI-Theme und dokumentiertes Designsystem für drei Zielauflösungen
- manuelle Trackpriorität sowie Freigabe, Sperre und Rücknahme über protokollierte Befehle
- validierte Einsatzregeln und erweiterte Erklärungen der automatischen Zielauswahl
- acht zusätzliche automatisierte Testfälle für Katalog, App-Navigation, Profil, Einstellungen und Zielsteuerung
- Tutorial Mission 1 mit eigener, fehlertoleranter Übungskonfiguration, verständlicherem Automatik-Hinweis und verbindlichem Unbeschädigt-Erfolgstest

### Geplant

- v0.5 Public Demo mit handgefertigter Mini-Kampagne
- regelbasierte Steuerung mit manueller Trackpriorität und Einsatzfreigabe
- hochwertige stilisierte 2D-Leitstandpräsentation
- plattformspezifische Laufzeit-, Eingabe- und Barrierefreiheitstests

### Geändert

- zukünftige Produktvision und priorisierte Roadmap dokumentiert
- Produktbacklog in 21 klar abgegrenzte Arbeitspakete strukturiert
- Repository unter `GPL-3.0-or-later` lizenziert

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
