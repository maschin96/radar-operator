# Vertical-Slice-QA und bekannte Einschränkungen

## Abnahmeumfang

Der Vertical Slice umfasst eine vollständige Mission von Briefing und Vorbereitung über eine datengetriebene Angriffswelle bis zur Auswertung. Unterstützte Entwicklungsauflösungen sind 1920×1080 und 2560×1440. Das UI skaliert über Godots `canvas_items`-Stretch-Modus.

Die automatisierte Suite führt Projektimport, Parserprüfung, Unit- und Integrationstests aus. Sie deckt Simulationszeit, Datenvalidierung, Bedrohungsbewegung, Sensorik, Track-Fusion, Platzierung, Abwehr, Infrastruktur, UI-Fluss, Auswertung und Persistenz ab.

Letzte Gesamtabnahme: 4. September 2026 mit Godot 4.7.2. Der Projekt-Smoke-Test und alle 94 Testfälle bestanden ohne Scriptfehler. Neben der vollständigen 180-Sekunden-Vertical-Slice-Mission wurde Tutorial Mission 1 vom Briefing über alle zehn Lernschritte bis zur Auswertung automatisiert durchgespielt. Hauptnavigation, Missionskatalog, Profilfortschritt, Einstellungen, Netzgraph, Sichtbarkeitsmasken, mobile Systeme sowie die drei Zielauflösungen werden zusätzlich headless geprüft.

Der geführte Referenzpfad der Tutorialmission muss mit einem unbeschädigten Kraftwerk, mindestens einer erfolgreichen Abwehr und ohne Zieleinschlag enden. Dafür nutzt die Mission bewusst eigene, fehlertolerante Übungswerte; die Balance der freien Mission bleibt unverändert.

## Steuerung

- Mittlere Maustaste: Karte verschieben
- Mausrad: Karte zoomen
- Pfeiltasten bei fokussierter Karte: Karte verschieben
- Leertaste: Pause beziehungsweise 1× fortsetzen
- `1`, `2`, `4`: Zeitfaktor
- `B`: Briefing ein- oder ausblenden

## Barrierefreiheit im MVP

- Trackzustände unterscheiden sich durch Farbe, Symbolform, Text und Klassifikationsbezeichnung.
- Hoher Kontrast kann für Tracks zugeschaltet werden.
- Bewegungsvektoren lassen sich über „Reduzierte Effekte“ ausblenden.
- Warntöne lassen sich unabhängig deaktivieren.
- Die Simulation kann jederzeit ohne Strafe pausiert werden.
- Zentrale Aktionen sind per Maus und Tastatur erreichbar.

## Performanceziel

Der reguläre Inhalt umfasst drei gleichzeitige Bedrohungsklassen. Der automatisierte Stress-Smoke-Test verarbeitet 200 gleichzeitige Kontakte, sechs Sensoren und 300 Simulationsschritte. Das lokale Referenzbudget beträgt zehn Sekunden und wurde auf der ARM64-macOS-Entwicklungsmaschine erreicht. Auf variabel ausgelasteten GitHub-Runnern gilt ein CI-Budget von 15 Sekunden. Vor einer Veröffentlichung wird das relative Simulationsziel durch eine benannte Referenzhardware und feste Render-Frame-Time-Budgets ergänzt.

## Export-Abnahme

- macOS Universal: Debug-ZIP erfolgreich erzeugt, App-Bundle nativ headless gestartet und mit Exitcode 0 beendet.
- Windows x86-64: Debug-EXE erfolgreich erzeugt und als PE32+-Programm validiert.
- Linux x86-64: Debug-Programm erfolgreich erzeugt und als ELF-64-Programm validiert.
- Ein plattformneutraler PCK-Export wurde ebenfalls erfolgreich erzeugt.

Die Build-Pipeline ist damit für alle drei MVP-Zielplattformen funktionsfähig. Native Start-, Eingabe- und Leistungstests auf Windows- und Linux-Hardware sind mangels entsprechender Runner nicht Teil dieser lokalen macOS-Abnahme und bleiben vor einer öffentlichen Veröffentlichung verpflichtend.

## Bekannte Einschränkungen

- Tutorial Mission 1 und das ursprüngliche Vertical-Slice-Szenario sind über die Missionsauswahl erreichbar; weitere Kampagnenmissionen fehlen noch.
- Das Geländemodell nutzt bewusst abstrakte Höhenzonen statt einer hochauflösenden topografischen Karte.
- Elektronische Störungen und Täuschkontakte sind noch nicht spielbar. Mobile Systeme nutzen bewusst eine abstrahierte Rasterroute statt einer detaillierten Straßen- oder Fahrphysik.
- Einsatzregelprofile, Vorschau und Entscheidungserklärungen sind spielbar. Missionen können ein Startprofil referenzieren; eine kampagnenweite Profilbibliothek ist noch nicht vorgesehen.
- Das Replay speichert sekündliche spielersichtbare Zustände, bietet aber noch keine animierte Scrubber-Oberfläche.
- Sprachmeldungen sind noch durch priorisierte synthetische Warntöne ersetzt.
- Grafik und Ton sind konsistente MVP-Assets, noch keine finale Produktionsqualität.
- Export-Presets und geprüfte Debug-Builds sind für macOS, Windows und Linux vorhanden. Signierung, Notarisierung und Store-Pakete sind nicht Teil des Vertical Slice.
- Windows- und Linux-Builds wurden lokal erzeugt und strukturell geprüft, aber noch nicht auf nativer Zielhardware gestartet.

## Nächste Produktionsphase

1. Missionsauswahl und Tutorial Mission 2 für manuelle Zielpriorisierung und Energieausfälle.
2. Zusätzliche Missionskarten und Balancing der Geländezonen.
3. Störmechaniken und Täuschkontakte.
4. Animierte Replay-Zeitleiste und filterbare Entscheidungsereignisse.
5. Externe Spieltests, Balancing-Telemetrie und finale Audio-/Grafikproduktion.
6. Signierte Plattform-Builds und plattformspezifische Eingabe-/Leistungstests.
