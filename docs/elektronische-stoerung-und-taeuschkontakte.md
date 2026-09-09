# Elektronische Störung und Täuschkontakte

## Abstraktes Modell

Radar Operator modelliert elektronische Kampfführung bewusst als spielerische Informationsunsicherheit, nicht als Nachbildung realer Verfahren. Szenarien definieren versionierte Störzonen mit Fläche, Stärke, betroffenen Sensortypen und zeitlich interpolierten Stärkekurven. Störung kann gleichzeitig:

- die Erfassungswahrscheinlichkeit senken,
- den Positionsfehler vergrößern,
- Sensoraktualisierungen verlangsamen und
- Klassifikationsevidenz reduzieren.

Die Karte zeigt nur bekannte Interferenzbereiche und deren aktuelle Stärke. Sie verrät keine verborgenen Sender oder Wahrheitspositionen.

## Täuschkontakte und Indizien

Täuschsender erzeugen deterministisch verrauschte Sensorreturns entlang einer datengetriebenen Route. Diese Returns durchlaufen dieselbe Track-Fusion wie andere Messungen. Für UI und Einsatzregeln existiert kein Feld „ist Täuschung“.

Tracks zeigen ausschließlich beobachtbare Indizien:

- Signal-Konsistenz,
- Interferenzniveau,
- Abstützung durch einen oder mehrere Sensoren sowie
- den daraus abgeleiteten Hinweis **Mögliche Täuschung**.

Der Hinweis ist keine Wahrheitsanzeige. Spätere konsistente Messungen und unabhängige Sensorabstützung können ihn entkräften. Enden die auffälligen Returns, wächst die Trackunsicherheit und der Track geht nach dem normalen Zeitlimit verloren. Einsatzregeln bewerten auch solche Tracks ausschließlich anhand von Position, Klassifikation, Konfidenz, Priorität und anderen spielersichtbaren Zuständen.

## Determinismus und Replay

Jeder Return verwendet Seed, abstrahierte Sender-ID, Sensor-ID und Zeitfenster für reproduzierbare Abweichungen. Stärkeunterschiede, auffällige Returns und Trackänderungen werden mit Simulationszeit protokolliert. Replay-Frames und Save-Rekonstruktion enthalten die spielersichtbaren Interferenz- und Evidenzwerte.

Spielstände verwenden Formatversion 5. Automatisierte Tests prüfen Störkurven und Sensorfilter, Messauswirkungen, identische Seeds, Entstehung und Entkräftung auffälliger Tracks, die Trennung von interner Wahrheit und Spielerinformation den späteren Trackverlust sowie Save/Load und identische Replay- und Ereignisverläufe während aktiver Täuschmessungen. Interne Sender-Zeitfenster und Return-Zähler bleiben außerhalb der Spieler- und Replay-Snapshots.
