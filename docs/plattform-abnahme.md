# Plattformabnahme für #19

Stand: 2. Oktober 2026. Automatisierte Prüfungen sind von manueller Abnahme getrennt.

## Zielmatrix und geplante Mindestumgebung

| Ziel | Umgebung | Automatisierung | Manuelle Abnahme |
| --- | --- | --- | --- |
| Windows x86-64 | Windows 10/11, OpenGL 3.3 | vollständige Suite und nativer Headless-Exportstart in CI | offen |
| macOS Universal | Apple Silicon / Intel, OpenGL 3.3 | Suite und nativer Headless-Exportstart in CI | ARM64 frühere Sichtprüfung; Intel offen |
| Linux x86-64 | Ubuntu 22.04+, X11/XWayland, OpenGL 3.3 | Suite und nativer Headless-Exportstart in CI | offen |

Die Hardwareanforderungen sind Planungswerte, keine gemessenen Mindestanforderungen.
8 GB RAM und 500 MB freier Speicher sind vorläufig vorgesehen. CI-Nachweise müssen
für den konkreten Release-Commit geprüft werden; die Konfiguration allein belegt
keinen erfolgreichen Plattformlauf.

## Performance und Freigabe

Referenzhardware vor der Messung mit CPU, GPU, RAM, Betriebssystem und Grafiktreiber
festhalten. Ziel: 60 FPS bei 1920×1080, 95. Perzentil der Framezeit höchstens 16,7 ms,
99. Perzentil höchstens 33,3 ms. Nach 30 Sekunden Aufwärmen jeweils 120 Sekunden
Mission 4 bei 1× und 4× sowie deren Replay bei 4× messen. Laufzeit, Renderzeit und
Speicherverbrauch getrennt protokollieren. Headless-Simulationsbudgets ersetzen
keine Messung der dargestellten Bildrate. Diese Renderabnahme steht noch aus.

## Manuelle Prüfschritte

- Frisches Profil: Menü → Mission 1 → Platzierung → Start → Pause → Abschluss →
  Debriefing → Replay → Folgemission ausschließlich mit Tastatur durchlaufen.
- Tab/Umschalt+Tab, sichtbaren Fokus, Eingabe, Esc und konfigurierbare Spieltasten
  prüfen. Karte: Pfeile, Eingabe, Bild auf/ab, +/−; mobile Reserve verlegen/abbrechen.
- 1280×720, 1920×1080 und 2560×1440: Menü, Briefing, Details, Regelvorschau,
  Einstellungen und Replay auf Überlappung und erreichbare Aktionen prüfen.
- Kontrast, Blau/Orange-Palette, reduzierte Bewegung, deaktivierte Warntöne und
  getrennte Lautstärken prüfen. Informationen müssen ohne Farbe erkennbar bleiben.
- Speichern/Neustart/Laden; alte Fixtures und beschädigte/neue Formate prüfen.
  Originaldateien müssen erhalten bleiben und Wiederherstellung verständlich sein.
- Vollständig entpacktes Paket als externe Person ohne Godot-Editor starten;
  Grafik, Audio, Eingabe und Installationshinweise auf allen drei Plattformen prüfen.

Befunde mit Commit, Umgebung, Schritten, Soll/Ist und Schwere dokumentieren.
Abstürze, Datenverlust und unerreichbare kritische Aktionen blockieren die Freigabe.
#19 bleibt bis zur gemessenen Renderperformance und manuellen Zielplattformabnahme
offen. #20 verlangt zusätzlich echte externe Testpersonen.
