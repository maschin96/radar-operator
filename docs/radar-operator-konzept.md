# Radar Operator – Spielkonzept und technische Planung

## 1. Dokumentstatus

- **Arbeitstitel:** Radar Operator
- **Genre:** taktische Echtzeitstrategie, Management und Simulation
- **Plattform für das MVP:** Desktop (Windows, Linux, macOS)
- **Engine:** Godot 4
- **Technologiesprache:** zunächst GDScript; ein späterer Wechsel einzelner rechenintensiver Module zu C# bleibt möglich
- **Darstellung:** 2D-Radarkarte mit Bedienoberfläche; kein begehbarer 3D-Kontrollraum im MVP
- **Setting:** vollständig fiktives Land mit abstrahierten Systemen und Leistungswerten
- **Ziel dieses Dokuments:** verbindliche Produkt- und Technikgrundlage für den ersten spielbaren Prototypen

## 2. Vision

Der Spieler leitet die Luftverteidigung eines fiktiven Landes aus einem Radarkontrollraum. Er schützt Hauptstadt, Energieversorgung, Industrie und weitere kritische Infrastruktur, indem er ein belastbares Netzwerk aus Sensoren, Kommunikation und Abwehrsystemen plant.

Das Spiel ist kein klassisches Tower-Defense-Spiel. Die zentrale Herausforderung ist die Arbeit mit unvollständigen Informationen. Ein Kontakt ist zunächst nur ein unsicheres Signal. Erst die Kombination mehrerer Sensoren, fortlaufende Beobachtung und kluge Priorisierung machen aus ihm ein belastbares Lagebild.

Die wichtigste Spielerfantasie lautet:

> Ich erkenne aus einem chaotischen, unvollständigen Lagebild die tatsächliche Bedrohung und treffe rechtzeitig die entscheidenden Maßnahmen.

## 3. Designprinzipien

### 3.1 Information ist die wichtigste Ressource

Sensorabdeckung allein reicht nicht. Qualität, Aktualität, Überlappung und Verbindung der Sensoren entscheiden darüber, wie zuverlässig ein Kontakt bewertet werden kann.

### 3.2 Entscheidungen statt Mikromanagement

Der Spieler definiert Prioritäten, Einsatzregeln und Positionen. Untergeordnete Systeme führen geeignete Standardaktionen automatisch aus. Manuelle Eingriffe bleiben für kritische Situationen möglich.

### 3.3 Jede Niederlage muss erklärbar sein

Nach einer Mission zeigt eine Auswertung, wann ein Kontakt entdeckt wurde, wie sich die Klassifizierung entwickelte, welche Systeme reagierten und weshalb ein Ziel getroffen oder geschützt wurde.

### 3.4 Mehrere sinnvolle Lösungen

Karten und Szenarien dürfen nicht auf eine einzige optimale Aufstellung hinauslaufen. Kosten, Gelände, Energie, begrenzte Munition und unterschiedliche Schutzziele sollen mehrere Strategien ermöglichen.

### 3.5 Glaubwürdige Atmosphäre, abstrahierte Simulation

Oberfläche, Ton und Informationsfluss vermitteln einen glaubwürdigen Kontrollraum. Länder, Systeme, Verfahren, Reichweiten und Wirkungsmodelle bleiben jedoch fiktiv und spielorientiert.

## 4. Zielgruppe und Spielerlebnis

Das Spiel richtet sich an Spieler, die Systeme beobachten, Pläne verbessern und aus Fehlern lernen möchten. Angestrebt wird eine Mischung aus der Übersichtlichkeit eines Strategiespiels und der Anspannung einer Leitstandsimulation.

Eine Mission dauert im MVP ungefähr 15 bis 30 Minuten. Die Simulation kann pausiert sowie beschleunigt werden. Schwierigkeit entsteht vor allem aus Informationsunsicherheit, Zeitdruck, mehreren gleichzeitigen Bedrohungen und begrenzten Ressourcen.

## 5. Kernspielschleife

1. Auftrag, Karte, Infrastruktur und verfügbare Mittel prüfen.
2. Sensoren, Kommunikationsknoten und Abwehrsysteme platzieren.
3. Simulation starten und einlaufende Kontakte beobachten.
4. Kontakte klassifizieren, markieren und priorisieren.
5. Einsatzregeln oder Systemzuweisungen an die Lage anpassen.
6. Angriff abwehren und Schäden begrenzen.
7. Ereignisverlauf auswerten und die Aufstellung verbessern.

## 6. Missionsphasen

### 6.1 Vorbereitung

Der Spieler erhält eine strategische Karte, ein Budget, bekannte Lageinformationen und eine Liste schützenswerter Infrastruktur. Er platziert Systeme nur auf erlaubten Flächen. Reichweiten, Geländeeinfluss, Energieversorgung und Netzwerkverbindungen werden direkt visualisiert.

### 6.2 Einsatz

Die Simulation läuft in Echtzeit mit Pause und Zeitbeschleunigung. Unbekannte Signale werden zu Tracks zusammengeführt. Deren Position und Identität bleiben zunächst unsicher. Der Spieler passt Prioritäten und Regeln an, während automatische Systeme die konkrete Verfolgung und Bekämpfung übernehmen.

### 6.3 Auswertung

Eine Zeitleiste und Kartenwiedergabe erklären Entdeckung, Klassifizierung, Entscheidungen, Systemreaktionen, Treffer und Schäden. Kennzahlen unterstützen das Lernen, ohne die Mission nur auf einen Punktestand zu reduzieren.

## 7. Spielsysteme

### 7.1 Kritische Infrastruktur

Infrastruktur ist nicht nur ein Trefferpunktziel, sondern Teil eines funktionalen Netzes.

| Typ | Funktion im Spiel | Folge eines Ausfalls |
| --- | --- | --- |
| Hauptstadt/Kommandozentrum | politische und operative Stabilität | schlechtere Koordination oder Missionsniederlage |
| Kraftwerk | erzeugt Energie | angeschlossene Systeme arbeiten eingeschränkt |
| Umspannwerk | verteilt Energie regional | lokaler Netzausfall |
| Kommunikationszentrum | verbindet Sensoren und Abwehr | langsamere oder fehlende Track-Weitergabe |
| Fabrik | erzeugt Nachschub zwischen Missionen | weniger Ersatzteile oder Munition |
| Flugplatz | stellt zusätzliche Reaktionsoptionen bereit | geringere operative Flexibilität |
| ziviles Zentrum | beeinflusst Legitimität und Bewertung | hohe politische und humanitäre Kosten |

Für das MVP werden zunächst Kommandozentrum, Kraftwerk und Fabrik umgesetzt.

### 7.2 Sensoren

Sensoren verwenden abstrahierte Werte:

- Erfassungsreichweite
- Aktualisierungsintervall
- Klassifizierungsstärke
- Positionsgenauigkeit
- Störfestigkeit
- Energiebedarf
- Mobilität
- Kosten

MVP-Typen:

- **Kurzstreckensensor:** günstig, häufige Aktualisierung, begrenzte Abdeckung
- **Frühwarnsensor:** große Reichweite, teuer, langsamer und stärker vom Netzwerk abhängig

Spätere Typen können passive Sensoren, mobile Sensoren und optische Bestätigungsposten umfassen.

### 7.3 Tracks und Unsicherheit

Ein erfasstes Objekt wird nicht unmittelbar vollständig angezeigt. Der Spieler sieht einen Track mit:

- geschätzter Position
- Bewegungsvektor
- Unsicherheitsradius
- Alter der letzten Messung
- Identitätswahrscheinlichkeiten
- meldenden Sensoren
- Prioritätsstufe

Mögliche Klassifizierungsfolge:

`Unbekannt → Luftkontakt → Verdächtig → Feindlich bestätigt`

Bei Verlust der Sensorverbindung bleibt der Track kurzfristig erhalten. Seine vorhergesagte Position bewegt sich weiter, während die Unsicherheit anwächst.

### 7.4 Abwehrsysteme

MVP-Rollen:

- **Geschützsystem:** kurze Reichweite, geringe Kosten, letzte Verteidigungslinie
- **Kurzstreckensystem:** Objektschutz mit begrenzter Munition
- **Mittelstreckensystem:** regionale Abdeckung, teuer und langsamer nachzuladen

Zustände eines Systems:

`Offline → Bereitschaft → Zielzuweisung → Verfolgung → Einsatz → Nachladen → Bereitschaft`

Zielauswahl berücksichtigt Bedrohungsgrad, Zeit bis zum möglichen Einschlag, Wert des bedrohten Objekts, Erfolgswahrscheinlichkeit, Munition und bereits zugewiesene Abwehrmaßnahmen.

### 7.5 Einsatzregeln

Der Spieler kann für das MVP mindestens folgende Regeln konfigurieren:

- nur bestätigte feindliche Kontakte bekämpfen
- verdächtige Kontakte in einer Schutzzone priorisieren
- Infrastruktur nach Schutzwert priorisieren
- automatische oder manuelle Freigabe verwenden

Zu aggressive Regeln können Fehlentscheidungen verursachen; zu restriktive Regeln kosten Reaktionszeit.

### 7.6 Energie und Kommunikation

Systeme benötigen Energie und eine Verbindung zum Führungsnetz. Ausfälle erzeugen keine sofortige binäre Wirkung: Notstrom oder lokaler Betrieb ermöglichen zeitlich begrenzte, schlechtere Funktion.

Für das MVP wird das Netz als Graph modelliert. Knoten sind Anlagen, Kanten sind abstrakte Verbindungen. Eine vollständige Wirtschaftssimulation ist nicht vorgesehen.

### 7.7 Gegnerische Bedrohungen

Das MVP verwendet drei fiktive Signaturklassen mit unterschiedlichen Geschwindigkeiten, Erkennbarkeiten und Zielpräferenzen. Konkrete reale Waffensysteme werden nicht nachgebildet.

Spätere Szenarien können Ablenkungen, Täuschkontakte, Sättigungsangriffe, Störungen und Angriffe aus mehreren Richtungen kombinieren.

## 8. Umfang des MVP

### Enthalten

- eine 2D-Karte
- eine handgefertigte Mission
- drei Infrastrukturtypen
- zwei Sensortypen
- drei Abwehrrollen
- drei Bedrohungsklassen
- Platzierungsmodus mit Budget
- Sensorerfassung und Track-Fusion
- Unsicherheitsradius und Kontaktklassifizierung
- automatische Zielpriorisierung
- Pause sowie 1×, 2× und 4× Geschwindigkeit
- Missionsende, Kennzahlen und einfache Ereigniszeitleiste
- Speichern eines laufenden Szenarios

### Nicht enthalten

- begehbarer 3D-Kontrollraum
- Multiplayer
- nationale Meta-Kampagne
- komplexe Diplomatie oder Politik
- realistische physikalische Radar- oder Flugkörpersimulation
- Workshop-Integration
- vollständiger Szenario-Editor

## 9. Benutzeroberfläche

### 9.1 Hauptansicht

- zentrale taktische Karte
- obere Leiste für Missionszeit, Geschwindigkeit, Budget und Alarmstufe
- linke Leiste für Bau- und Platzierungsoptionen
- rechte Leiste für Auswahl, Trackdetails und Systemstatus
- untere Ereignisleiste für Warnungen und wichtige Meldungen

### 9.2 Kartenebenen

- Gelände und administrative Karte
- kritische Infrastruktur
- Energie- und Kommunikationsverbindungen
- Sensorreichweiten
- Abwehrreichweiten
- Messungen und fusionierte Tracks
- Bewegungsverlauf und Unsicherheitsflächen
- Warnungen, Auswahl und Befehle

### 9.3 Barrierefreiheit

- Informationen nie ausschließlich über Farbe vermitteln
- skalierbare Benutzeroberfläche
- frei belegbare Tastaturkürzel
- Pause ohne spielerische Strafe
- getrennte Lautstärkeregler für Ambiente, Warnungen und Sprache
- hoher Kontrast und optional reduzierte Bildschirm-Effekte

## 10. Audio und Atmosphäre

Die Präsentation verwendet gedämpfte Farben, Radarimpulse, Relaisgeräusche und sachliche Meldungen. Warnungen besitzen Prioritäten und Abklingzeiten, damit sie sich nicht überlagern. Die Alarmstufe verändert Ambiente und Interface subtil, ohne Informationen zu verdecken.

## 11. Technische Umsetzung mit Godot 4

### 11.1 Technische Leitentscheidungen

- Godot 4.7 als Feature-Basis; Entwicklungs- und Testversion ist Godot 4.7.2.
- GDScript mit statischer Typisierung für schnelle Iteration und einfache Builds.
- Simulationslogik bleibt unabhängig von Szenenbaum und Darstellung testbar.
- Feste Simulationsschritte statt an die Bildrate gekoppelter Logik.
- Datengetriebene Definitionen über Godot `Resource`-Typen; JSON nur für externe Inhalte oder Exporte.
- Deterministische Zufallsquelle pro Mission über gespeicherten Seed.
- Git-freundliche Textressourcen und kleine, klar verantwortete Szenen.

### 11.2 Repository-Struktur

```text
RadarOperator/
├── project.godot
├── data/
│   ├── scenarios/
│   ├── sensors/
│   ├── defenses/
│   ├── infrastructure/
│   └── threats/
├── docs/
├── scenes/
│   ├── app/
│   └── gameplay/
├── scripts/
│   ├── app/
│   ├── core/
│   ├── simulation/
│   ├── systems/
│   ├── ui/
│   └── tests/
└── .github/
    ├── workflows/
    └── ISSUE_TEMPLATE/
```

Generierte Godot-Importdaten, Testlogs und Desktop-Builds sind bewusst vom Repository ausgeschlossen.

### 11.3 Architektur

```text
App/Composition Root
├── Scenario Loader
├── Simulation
│   ├── World State
│   ├── Fixed-step Clock
│   ├── Movement System
│   ├── Sensor System
│   ├── Track Fusion System
│   ├── Defense System
│   ├── Infrastructure System
│   └── Event Log
├── Presentation
│   ├── Tactical Map
│   ├── Overlays
│   ├── Panels
│   └── Audio Manager
└── Persistence
    ├── Save/Load
    └── Replay Data
```

Der Simulationskern arbeitet auf einfachen Zustandsobjekten und gibt Ereignisse aus. UI-Knoten lesen den Zustand und senden Spielerbefehle an die Simulation. Sie verändern Simulationsobjekte nicht direkt.

### 11.4 Simulationszeit

Die Simulation verwendet einen Akkumulator und eine feste Tickdauer, voraussichtlich 0,1 Sekunden. Darstellung interpoliert bei Bedarf zwischen Zuständen. Pause und Zeitfaktoren verändern die Zufuhr von Simulationszeit, nicht die Tickdauer.

### 11.5 Entitäten und Daten

Jede Entität besitzt mindestens:

- stabile ID
- Typ-ID
- Fraktion
- Position
- aktiven Zustand
- Schadenszustand
- optionale Signatur-, Sensor-, Abwehr- oder Infrastrukturdaten

Ein vollständiges ECS ist für das MVP nicht erforderlich. Kleine typisierte Zustandsklassen und klar getrennte Systeme reichen aus und vermeiden unnötige Komplexität.

### 11.6 Sensorberechnung

Pro Sensor-Tick wird geprüft:

1. Liegt das Ziel innerhalb der abstrakten Reichweite?
2. Welche Modifikatoren gelten für Entfernung, Gelände, Signatur und Störung?
3. Wird eine Messung erzeugt?
4. Welche Positionsabweichung und Klassifizierungsinformation enthält sie?
5. Welchem bestehenden Track kann die Messung zugeordnet werden?

Sichtbarkeits- oder Reichweitenmasken werden beim Platzieren beziehungsweise bei Kartenänderungen vorberechnet und zwischengespeichert.

### 11.7 Track-Fusion

Messungen werden nach räumlicher Nähe, Bewegungsmodell und Aktualität einem Track zugeordnet. Für das MVP genügt ein verständliches probabilistisches Näherungsverfahren; ein wissenschaftlich exakter Filter ist nicht nötig.

Für jeden Track werden Position, Geschwindigkeit, Unsicherheit und Klassifizierungswerte aktualisiert. Der Algorithmus muss über feste Seeds reproduzierbar und durch Unit-Tests prüfbar sein.

### 11.8 Rendering

Viele Radarsymbole und Reichweiten werden gebündelt in spezialisierten `Node2D`-Klassen gezeichnet. Vollwertige `Control`-Knoten werden nur für interaktive Panels, Tooltips und ausgewählte Objekte verwendet. Dadurch bleibt die Karte auch bei vielen Kontakten performant.

### 11.9 Gegner-KI

Die erste Mission nutzt datengetriebene Angriffspakete und Wegpunkte. Ein einfacher Utility-Entscheider bestimmt Zielwechsel oder Abbruch anhand von Schutzgrad, Zielwert und Missionszustand. Maschinelles Lernen ist nicht vorgesehen.

### 11.10 Speichern und Replay

Ein Spielstand enthält Szenario-ID, Inhaltsversion, Seed, Simulationszeit, Entitätszustände, Tracks, Ressourcen und Spielerregeln. Für Replay und Auswertung werden wichtige Befehle und Ereignisse mit Zeitstempel protokolliert. Regelmäßige Snapshots können später schnelles Springen auf der Zeitleiste ermöglichen.

### 11.11 Tests und Qualität

- Unit-Tests für Simulation, Priorisierung und Serialisierung
- deterministische Szenario-Smoke-Tests
- manuelle visuelle Prüfung der Hauptauflösungen
- Debug-Overlay für IDs, Sensorwerte, Tracks und Zustandswechsel
- Profiler-Prüfung mit deutlich mehr Kontakten als im MVP-Szenario

Die Auswahl eines Godot-Test-Frameworks erfolgt beim Projekt-Setup. Wenn eine externe Erweiterung vermieden werden soll, können headless ausführbare Test-Szenen verwendet werden.

## 12. Inhaltsmodell

Systemdefinitionen werden als benutzerdefinierte Godot Resources gepflegt. Beispielhafte Felder einer Sensordefinition:

```gdscript
class_name SensorDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var detection_range: float
@export var update_interval: float
@export_range(0.0, 1.0) var classification_strength: float
@export var position_error: float
@export var power_demand: float
@export var purchase_cost: int
```

Alle Zahlen sind abstrakte Balancingwerte und keine Abbildung realer Anlagen.

## 13. Meilensteine

### M0 – Projektbasis

Godot-Projekt, Verzeichnisstruktur, Konventionen, Testweg und Startszene funktionieren.

### M1 – Simulations-Sandbox

Kontakte bewegen sich deterministisch auf einer Karte; Zeitsteuerung und Debug-Anzeige funktionieren.

### M2 – Informationsspiel

Sensoren erzeugen Messungen, Tracks werden fusioniert und Unsicherheit wird sichtbar.

### M3 – Abwehrspiel

Platzierung, Budget, Zielpriorisierung, Abwehrzustände und Schäden bilden eine vollständige Spielschleife.

### M4 – Vertical Slice

Eine Mission ist vom Briefing über den Einsatz bis zur verständlichen Auswertung spielbar und atmosphärisch präsentiert.

## 14. Hauptrisiken und Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
| --- | --- |
| Informationsüberlastung | gestufte Darstellung, Filter, klare Prioritäten und Tutorial |
| unverständliche Track-Fusion | Debug-Ansicht und erklärende Trackdetails |
| zu viel Automatisierung | relevante Regeln und manuelle Freigabe anbieten |
| zu viel Mikromanagement | Standardautomatik und Gruppenregeln bereitstellen |
| dominante Aufstellung | Szenario-Variation, Kosten, Gelände und mehrere Zielwerte |
| schlechte Performance | fester Tick, vorberechnete Masken, gebündeltes Rendering |
| nicht reproduzierbare Fehler | fester Seed, Befehlslog und deterministische Tests |
| zu großer Umfang | strikte MVP-Grenzen und klar abgegrenzte GitHub Issues |

## 15. Definition of Done für den ersten Prototyp

Der Prototyp gilt als erfolgreich, wenn ein neuer Spieler ohne externe Erklärung:

1. Sensoren und Abwehrsysteme platzieren kann,
2. den Unterschied zwischen Messung und Track versteht,
3. mindestens eine Bedrohung anhand wachsender Information priorisiert,
4. eine vollständige Angriffswelle erlebt,
5. in der Auswertung nachvollziehen kann, warum Infrastruktur geschützt oder getroffen wurde,
6. die Mission anschließend mit einer erkennbar verbesserten Aufstellung erneut spielen kann.

## 16. Produktentscheidungen für v0.5

- Die öffentliche Demo verwendet eine handgefertigte Mini-Kampagne statt einer prozeduralen nationalen Lage.
- Konfigurierbare Regeln bleiben der Kern; manuelle Trackpriorität und Einsatzfreigabe ergänzen sie für kritische Entscheidungen.
- Der Kontrollraum bleibt eine hochwertige stilisierte 2D-Oberfläche und wird nicht als begehbarer 3D-Raum umgesetzt.
- Die visuelle Tonalität ist nüchtern und retro-technisch, ohne reale Staaten oder Systeme abzubilden.
- Ein vollständiger Szenario-Editor ist nicht Teil der v0.5 Public Demo.
- Der Quellcode wird unter `GPL-3.0-or-later` veröffentlicht.

Die verbindliche Zukunftsvision, Qualitätsziele und Roadmap stehen in [Produktvision v0.5 Public Demo](produktvision-v0.5.md).

## Versionierter Szenariokatalog

Szenarien werden als `ScenarioDefinition`-Ressourcen unter `data/scenarios/` automatisch gefunden. Der Katalog lädt ausschließlich Szenarioressourcen, sortiert sie deterministisch nach `campaign_order` und validiert vor dem Start:

- `content_version` gegen die aktuell unterstützte Inhaltsversion,
- eindeutige Szenario-IDs und Kampagnenpositionen,
- Anzeigename, Kurzbeschreibung, erwartete Dauer und Lernziele,
- Freischaltreferenzen auf vorhandene Szenarien,
- alle bisherigen Entitäts-, Wellen-, Karten- und Tutorialreferenzen.

Eine neue Mission benötigt mindestens `scenario_id`, `display_name`, `summary`, `campaign_order`, `expected_duration_minutes` und `learning_objectives`. Abhängige Missionen nennen ihre Vorgänger in `unlock_requires`. Ungültige oder inkompatible Inhalte blockieren den Katalog mit einer konkreten Fehlermeldung, statt erst während einer Spielsitzung abzustürzen.
