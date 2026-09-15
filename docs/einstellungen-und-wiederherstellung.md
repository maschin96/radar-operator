# Einstellungsdateien und Wiederherstellung

## Unterstütztes Format

Die Einstellungen verwenden weiterhin `format_version: 1`. Gültige bestehende Dateien werden unverändert im bisherigen Schema geladen und gespeichert. Zusätzliche unbekannte Felder bleiben bei einem regulären Speichervorgang erhalten. Dieser Entwicklungsschritt zu #18 führt keine Profil-, Szenario- oder Spielstandmigration ein; diese bleiben offen.

Vor dem Anwenden werden Fenstermodus, echte Wahrheitswerte, endliche Lautstärken zwischen 0 und 1 sowie ganzzahlige, konfliktfreie Tastenbelegungen geprüft. Fehlende Felder, falsche Datentypen und nicht unterstützte Versionsnummern lösen einen kontrollierten Rückfall auf Standardwerte aus.

## Schutz vorhandener Dateien

- Nach einem Ladefehler gelten Standardwerte zunächst nur für die laufende Sitzung. Das Hauptmenü zeigt Ursache und Wiederherstellungshinweis.
- Beschädigte, nicht lesbare oder nicht unterstützte Einstellungsdateien werden weder durch **Übernehmen** noch durch **Standardwerte** überschrieben.
- Der Speicherpfad wird bei jedem Speicherversuch erneut geprüft. Das schützt auch Dateien, die nach dem Start durch eine andere Spielversion ersetzt wurden, und direkte Speicheraufrufe ohne vorheriges Laden.
- Scheitert das Speichern, bleiben aktive Einstellungen, Lautstärke und Tastenbelegung unverändert. Der bearbeitete Entwurf bleibt für einen erneuten Versuch verfügbar.

## Wiederherstellung

Bei einer Datei aus einer neueren Version zuerst die passende Spielversion verwenden. Alternativ die im Hinweis genannte Datei im Dateimanager umbenennen, etwa von `settings.json` in `settings.json.original`. Danach im Spiel die gewünschten Einstellungen erneut übernehmen. Dadurch entsteht eine neue gültige Datei; das Original bleibt unter seinem neuen Namen erhalten. Die ursprüngliche Datei nicht löschen, wenn deren Inhalt noch benötigt wird.

## Prüfung und Grenzen

Sechs zusätzliche Regressionstests prüfen fehlerhafte Feldtypen, bytegleichen Erhalt geschützter Dateien, Änderungen nach dem Laden, Speichern ohne vorheriges Laden, fehlgeschlagene Schreibvorgänge, erneutes Speichern nach manueller Sicherung sowie den sichtbaren Fehlerablauf im Hauptmenü und Einstellungsdialog.

Die Prüfung erfolgt unmittelbar vor dem Schreiben. Gleichzeitige Schreibzugriffe mehrerer Prozesse werden nicht durch Dateisperren synchronisiert. Die automatische Migration älterer Spielstände und der entsprechende Schutz von Kampagnenprofilen sind weitere Arbeitspakete von #18.
