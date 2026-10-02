# Radar Operator installieren

Die passende ZIP-Datei aus dem GitHub Release vollständig in einen beschreibbaren
Ordner entpacken. Kein Godot-Editor ist erforderlich. `VERSION.json` nennt Version,
Commit, Engine und den exakt korrespondierenden GPL-Quellcode.

## Windows x86-64

Windows 10/11 mit OpenGL-3.3-fähigem Grafiktreiber ist die geplante Zielumgebung.
Alle Dateien entpacken und `RadarOperator.exe` starten. `RadarOperator.pck` muss im
selben Ordner bleiben. Builds sind nicht mit einem Windows-Codezertifikat signiert.

## macOS (Apple Silicon und Intel)

ZIP entpacken und `Radar Operator.app` öffnen. Die App darf nach „Programme“ kopiert
werden. Der Build ist nicht notarisiert; macOS kann daher den Start zunächst
blockieren. Nur nach Prüfung von Herkunft und Prüfsumme in Systemeinstellungen →
Datenschutz & Sicherheit den Start dieser App ausdrücklich erlauben. Sicherheits-
funktionen nicht global abschalten. Intel-Macs sind noch manuell zu prüfen.

## Linux x86-64

ZIP entpacken, Terminal im entpackten Ordner öffnen:

```sh
chmod +x RadarOperator.x86_64
./RadarOperator.x86_64
```

`RadarOperator.pck` muss neben dem Programm bleiben. Geplante Referenz: Ubuntu 22.04
oder neuer, OpenGL 3.3, X11 oder XWayland, aktueller Grafiktreiber.

## Integrität und Quellcode

`SHA256SUMS.txt` und das passende Archiv in denselben Ordner laden. Linux:
`sha256sum --ignore-missing -c SHA256SUMS.txt`; macOS: `shasum -a 256 -c SHA256SUMS.txt`
(bei einzeln geladenen Archiven fehlende andere Dateien ignorieren). Windows
PowerShell: `Get-FileHash .\RadarOperator-0.2.0-windows.zip -Algorithm SHA256` und mit
der gleichnamigen Zeile vergleichen.

Lizenz: **GPL-3.0-or-later**, vollständiger Text in `LICENSE`. Der vollständige
Projektquellcode liegt als `RadarOperator-<Version>-source.zip` im selben Release;
`VERSION.json` verlinkt zusätzlich den unveränderlichen Commit. Zum Nachbauen
`docs/release-checkliste.md` verwenden. Die Godot-Laufzeit steht unter MIT; ihre
Copyright-/Lizenztexte enthält der mitgelieferte Godot-Engine-Lizenzhinweis.

## Bedienung und Wiederherstellung

Tab / Umschalt+Tab wechselt Bedienelemente, Eingabe aktiviert. Auf der Karte:
Pfeile bewegen das Fadenkreuz, Eingabe platziert/selektiert, Bild auf/ab wählt
Objekte, +/− zoomt, Esc beendet das Platzieren/Verlegen. Leertaste pausiert.
Kontrast, Blau/Orange-Palette, reduzierte Effekte und getrennte Lautstärken stehen
in den Einstellungen. Das UI skaliert automatisch mit der Fenstergröße.

Spielstände und Fortschritt liegen lokal in Godots Benutzerdatenordner. Bei
inkompatiblen oder beschädigten Dateien den im Spiel genannten Pfad sichern und
umbenennen, dann neu starten. Keine Datei wird hierfür automatisch gelöscht.
Details: `docs/datenkompatibilitaet.md` im Quellcodepaket.

## Abnahmestand

Automatisierte Starts prüfen weder Grafiktreiber noch reale Tastatur-/Audioeingabe.
Die manuelle Plattformmatrix und bekannte Einschränkungen stehen in
`KNOWN-ISSUES.md`. Externe Playtests und die öffentliche v0.5-Freigabe stehen aus.
