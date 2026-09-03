# Energie- und Kommunikationsnetz

Das Netzmodell verbindet Infrastruktur und platzierte Systeme über zwei getrennte Graphen. Energieverbindungen werden gelb, Kommunikationsverbindungen blau dargestellt. Die Kartenebene **Energie-/Kommunikationsnetz** lässt sich unabhängig ein- und ausblenden.

## Betriebszustände

| Zustand | Auslöser | Wirkung auf verbundene Systeme |
| --- | --- | --- |
| Online | Quelle und Verbindung sind verfügbar | volle Sensoraktualisierung und Abwehrleistung |
| Notbetrieb | Quelle oder Verbindung fällt aus, mehr als die Hälfte der Reserve bleibt | 85 % Netzwerkqualität |
| Degradiert | höchstens die Hälfte der Reserve bleibt oder ein Wiederanlauf läuft | 50 % Netzwerkqualität, langsamere Sensorupdates und Zielverfolgung |
| Offline | Reserve ist aufgebraucht | keine Sensormessungen oder Trackweitergabe; Abwehr bricht Zuweisungen ohne Munitionsverbrauch ab |

Eine wiederhergestellte Verbindung durchläuft die konfigurierte Wiederanlaufzeit im degradierten Zustand. Jeder Verbindungs- und Zustandswechsel erzeugt ein Ereignis mit Verbindung, Quelle, Verbraucher, Restreserve und Ursache. Die Lagedetails zeigen dieselben Angaben am ausgewählten Objekt.

## Szenariomodell

`ScenarioDefinition.network_model_version` versioniert das Graphschema unabhängig vom übrigen Inhaltsmodell. `network_connections` enthält stabile Verbindungs-IDs:

```gdscript
{
    "id": &"energy_power_command",
    "kind": &"energy", # oder &"communication"
    "source_id": &"north_power",
    "consumer_id": &"capital_command",
    "reserve_duration": 10.0,
    "recovery_duration": 2.0,
}
```

Beim Missionsstart werden platzierte Sensoren und Abwehrsysteme deterministisch mit der nächstgelegenen passenden Quelle verbunden: Kraftwerke liefern Energie, Kommandozentren Kommunikation. `network_defaults` steuert deren Reservezeiten, den Degradationsanteil und die Wiederanlaufzeit. Szenarien ohne passende Quelle behalten für den betreffenden Graphen Direktversorgung; dadurch bleiben frühe Tutorialinhalte kompatibel.

Mehrere Verbindungen zu einem Verbraucher bilden Redundanz: Der beste verfügbare Pfad bestimmt seinen Zustand. Das ältere Feld `energy_connections` wird weiterhin als Energiegraph eingelesen, sollte in neuen Inhalten aber nicht mehr verwendet werden.

## Determinismus und Persistenz

Verbindungen lassen sich über `GameSession.set_network_connection_enabled()` reproduzierbar unterbrechen oder wiederherstellen. Der Befehl wird zusammen mit seinem Simulationstick gespeichert. Restreserven, Wiederanlaufzeiten, Ursachen und Zustände sind Teil des Persistenz-Snapshots; Replay-Frames enthalten den sichtbaren Graphzustand.
