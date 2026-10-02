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

## Produktionssprache der Demo

Die prozedurale Vektorgrafik und synthetischen Signale sind der beabsichtigte finale Stil: keine Fototexturen, Explosionseffekte oder externen Platzhalter. Alle vier Missionen nutzen dieselben Symbole, das gemeinsame Theme und dieselbe Tonbibliothek. Kontakte: Dreieck = feindlich, Quadrat = freundlich, Ring = noch unbestimmt; ein Querstrich und `GESPERRT` kennzeichnen gesperrte Kontakte. Infrastruktur trägt Name und Betriebszustand. Die optionale Blau-/Orange-Palette ist zusätzlich zur kontrastverstärkten Darstellung verfügbar und gilt auch im Replay.

Radarimpulse sind rein dekorativ und behaupten keine erfolgte Messung. Erfassung, Bekämpfung, Erfolg/Fehlversuch, Treffer und Netzzustand erscheinen mit Text am Ereignisort. Effekte dauern höchstens 1,2 Sekunden, die Queue enthält höchstens 32 Einträge. Reduzierte Effekte unterbinden den Radarimpuls, Bewegungsvektoren und die Ausdehnung der Ereignisringe; statische Hinweise bleiben lesbar. Es gibt keine Bildschirmblitze oder Kameraverwacklung.

Bedienklick, Kontakt, Erfolg und Alarm nutzen kurze, weich ein-/ausgeblendete Zweiklangsignale. Der Leitstandhintergrund ist eine leise, nahtlose 55-Hz-Harmonische. Effekte und Atmosphäre laufen über getrennte Godot-Busse unter Master. Sprachausgabe multipliziert ihre eigene Lautstärke mit Master, da Betriebssystem-TTS den Godot-Mixer umgeht. 0 schaltet die jeweilige Kategorie vollständig stumm.

Funksprüche verwenden optional eine lokal installierte deutsche Betriebssystemstimme. Es werden keine fremden Sprachaufnahmen ausgeliefert. Ohne deutsche Stimme stehen Meldungstext und Signaltöne bereit. Die konkrete Stimme variiert deshalb zwischen Plattformen; ihre Verfügbarkeit gehört zur Plattformabnahme. Technische Grundlage: [Godot DisplayServer TTS](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-tts-speak).
