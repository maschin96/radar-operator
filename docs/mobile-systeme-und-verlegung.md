# Mobile Systeme und Verlegung

## Spielablauf

Mobile Systeme werden während eines laufenden Einsatzes in den Lagedetails mit **System verlegen** ausgewählt. Die Karte zeigt vor der Bestätigung Ziel, deterministische Route, Kosten und Gesamtdauer. Ungültige Ziele nennen ihre Ursache, etwa Sperrzone, fehlendes Budget, Mindestabstand oder nicht erreichbare Route.

Eine bestätigte Verlegung durchläuft drei sichtbare Phasen:

1. **Abbau:** Das System bleibt am Ausgangsort, ist aber bereits nicht mehr einsatzbereit.
2. **Fahrt:** Das System bewegt sich mit seiner datengetriebenen Geschwindigkeit entlang der vorberechneten Rasterroute.
3. **Aufbau:** Das System steht am Ziel, bleibt jedoch bis zum Abschluss des Aufbaus offline.

Erst danach wechselt es wieder in den Zustand **Bereit**. Sensoren sammeln währenddessen keine rückwirkenden Scans; Abwehrsysteme brechen laufende Zuweisungen ohne Munitionsverbrauch ab. Die Netzverbindungen folgen der sichtbaren Systemposition, während Energie und Kommunikation für das System bis zur Bereitschaft gesperrt bleiben.

Eine Verlegung kann abgebrochen werden. Während des Abbaus bleibt das System am Ausgangsort; nach Fahrtbeginn baut es am aktuellen Haltepunkt wieder auf. Bereits bezahlte Verlegekosten werden nicht erstattet. Ein zerstörtes oder vollständig ausgefallenes System beendet die Verlegung dauerhaft und bleibt außer Betrieb.

## Datenmodell

Alle Sensor- und Abwehrdefinitionen erben folgende Felder:

- `mobile`
- `relocation_cost`
- `teardown_duration`
- `relocation_speed`
- `setup_duration`
- `relocation_allowed_phases`

Ungültige Kosten, Geschwindigkeiten, Zeiten oder Phasennamen werden beim Laden des Szenarios abgelehnt. Aktuell sind der Kurzstreckensensor und das Nahbereichsgeschütz mobil konfiguriert.

## Determinismus, Save und Replay

Verlege- und Abbruchbefehle werden mit Simulations-Tick und Zielposition im Befehlsprotokoll gespeichert. Ausgangsposition, Route, Phase, Wegindex, Ziel und Restzeit sind Teil des Zustands. Spielstände verwenden deshalb Formatversion 4. Beim Laden wird die Sitzung aus der unveränderlichen ursprünglichen Aufstellung und dem Befehlsprotokoll rekonstruiert.

Replay-Frames enthalten die vollständigen Systemzustände und können dadurch Abbau, Fahrt und Aufbau darstellen. Automatisierte Tests prüfen Routen und Sperrzonen, Kosten, Sensor- und Abwehrsperre, Abbruch, Ausfall, Abschluss sowie Save/Load in allen drei Phasen.
