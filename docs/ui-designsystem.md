# UI-Designsystem

Radar Operator verwendet das gemeinsame Godot-Theme `data/ui/radar_theme.tres` für Hauptmenü, Missionsauswahl und Kontrollraum. Die Oberfläche folgt einer dunklen Leitstandpalette mit grünen Betriebszuständen und gelber, deutlich umrandeter Tastaturfokusanzeige.

## Gestaltungsregeln

- Pflichtaktionen besitzen Text und einen klar sichtbaren Fokusrahmen; Farbe allein trägt keine Bedeutung.
- Zustände werden mit den Wörtern `GESPERRT`, `VERFÜGBAR`, `ABGESCHLOSSEN`, `ONLINE`, `AUS` oder einer konkreten Alarmbezeichnung ergänzt.
- Schaltflächen sind mindestens 44 Pixel hoch. Der Standardabstand zwischen Aktionen beträgt 12 Pixel.
- Tooltips erklären Wirkung und Kontext, dürfen aber keine zum Abschluss notwendige Information exklusiv enthalten.
- Dialoge verwenden dieselbe Panel-, Button- und Fokusdarstellung wie die Hauptnavigation.
- Unterstützte Layoutgrößen sind 1280×720, 1920×1080 und 2560×1440. Pflichtinhalte bleiben bei kleineren Inhaltsmengen ohne präzise Mausbewegung erreichbar.

Die headless UI-Tests prüfen die drei Zielauflösungen. Neue UI-Komponenten sollen Theme-Werte verwenden, statt lokale Farben, Ränder und Fokuszustände zu duplizieren.
