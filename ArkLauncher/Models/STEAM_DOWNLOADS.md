# Steam Downloads unter Wine - Problemlösung

## 🐌 Problem: Downloads fallen auf 0 MB/s

Dies ist ein **sehr häufiges Problem** mit Steam unter Wine!

### Ursachen:

1. **Disk I/O Performance**: Wine's Datei-Handling ist langsamer als natives Windows
2. **Fragmentierung**: Viele kleine Schreiboperationen
3. **Steam's Download-Mechanismus**: Verifiziert während des Downloads
4. **macOS Filesystem**: APFS/HFS+ Performance-Unterschiede

---

## ✅ Lösungen (in Reihenfolge der Wirksamkeit)

### Lösung 1: Download-Region ändern ⭐⭐⭐⭐⭐

**Am effektivsten!**

1. Öffnen Sie Steam
2. **Steam** → **Einstellungen** → **Downloads**
3. **Download-Region**: Probieren Sie verschiedene aus:
   - Germany - Frankfurt
   - Germany - Berlin
   - Netherlands - Amsterdam
   - UK - London

**Warum hilft das?**
- Verschiedene Server haben unterschiedliche Protokolle
- Manche Server sind besser für Wine optimiert

### Lösung 2: Download-Cache leeren ⭐⭐⭐⭐

1. **Steam** → **Einstellungen** → **Downloads**
2. **Download-Cache leeren**
3. Steam neu starten

**Warum hilft das?**
- Entfernt korrupte Cache-Dateien
- Resettet Download-Status

### Lösung 3: Kompatibilitäts-Modus verwenden ⭐⭐⭐⭐

Unser Setup wendet dies automatisch an!

```swift
// Bereits in SteamSetupService implementiert:
configureSteamDownloadSettings(in: prefixURL)
```

Dies deaktiviert:
- Bandwidth-Limitierung
- Streaming während Downloads
- Update-Zeit-Beschränkungen

### Lösung 4: Kleinere Spiele zuerst herunterladen ⭐⭐⭐

**Taktik:**
1. Starten Sie mit einem kleinen Spiel (< 1 GB)
2. Lassen Sie es **komplett** fertig werden
3. Dann größere Spiele

**Warum?**
- Steam "lernt" den optimalen Download-Pfad
- Erste Downloads sind immer langsamer

### Lösung 5: Download-Verzeichnis auf schnellere Disk ⭐⭐⭐

Falls Sie eine externe SSD haben:

1. **Steam** → **Einstellungen** → **Downloads**
2. **Steam-Bibliotheksordner**
3. Fügen Sie externe SSD hinzu
4. Installieren Sie Spiele dort

### Lösung 6: Nur 1 Download gleichzeitig ⭐⭐

- Pausieren Sie alle anderen Downloads
- Nur **ein** Spiel aktiv herunterladen

---

## 🔧 Erweiterte Fixes

### macOS System-Optimierungen

#### 1. Disable Spotlight für Wine-Prefix

Spotlight indiziert ständig neue Dateien, was Downloads verlangsamt:

```bash
# In Terminal:
sudo mdutil -i off "/Users/IhrName/Library/Application Support/WineWrapper/Prefixes/SteamSetup"
```

#### 2. Disk Performance prüfen

```bash
# Teste Schreibgeschwindigkeit:
dd if=/dev/zero of=testfile bs=1m count=1024
```

Sollte > 100 MB/s sein. Falls nicht, ist Ihre Disk zu langsam.

#### 3. Freier Speicherplatz

Stellen Sie sicher, dass Sie mindestens:
- **20% freien Speicherplatz** auf der System-Disk haben
- **2x die Spiel-Größe** an freiem Speicher

---

## 🎯 Steam-spezifische Tweaks

### In Steam Console (während Download läuft):

Drücken Sie **`** (Backtick) in Steam, dann:

```
download_debug_content 1
```

Dies zeigt detaillierte Debug-Informationen.

### Download-Scheduler anpassen:

```
@download_scheduler_force_update
```

Erzwingt Update des Download-Planers.

---

## 📊 Typische Download-Geschwindigkeiten unter Wine

| Szenario | Erwartete Geschwindigkeit |
|----------|---------------------------|
| Optimal konfiguriert | 50-80% der nativen Geschwindigkeit |
| Standard-Setup | 20-40% der nativen Geschwindigkeit |
| Ohne Optimierungen | 0-10% (fällt auf 0) |

**Beispiel:**
- Ihre Internet-Verbindung: 100 Mbps
- Erwartete Wine-Geschwindigkeit: 50-80 Mbps (6-10 MB/s)

---

## 🐛 Debugging

### Problem: Download startet, fällt dann auf 0

**Check 1: Disk-Aktivität**
```bash
# In Terminal:
sudo fs_usage -w -f filesys | grep Steam
```

Sollte kontinuierliche Aktivität zeigen.

**Check 2: Netzwerk-Aktivität**
```bash
nettop -p Steam
```

Sollte Download-Traffic zeigen.

**Check 3: Wine-Prozesse**
```bash
ps aux | grep wine
```

Sollte Steam-Prozesse zeigen.

### Problem: Download hängt bei "Allocating disk space"

**Ursache:** Steam reserviert Disk-Space, was unter Wine sehr langsam ist.

**Lösung:**
- Warten Sie geduldig (kann 10-30 Minuten dauern bei großen Spielen)
- Oder: Verwenden Sie ein vorhandenes Spiel-Verzeichnis

---

## 💡 Best Practices

### Für optimale Download-Performance:

1. ✅ Schließen Sie andere Wine-Programme
2. ✅ Schließen Sie Browser und schwere Apps
3. ✅ Verwenden Sie Ethernet statt WLAN
4. ✅ Downloaden Sie nachts (weniger Server-Last)
5. ✅ Starten Sie mit kleinen Spielen
6. ✅ Lassen Sie Steam im Vordergrund
7. ✅ Deaktivieren Sie Auto-Updates für andere Spiele

### Was Sie VERMEIDEN sollten:

1. ❌ Mehrere Downloads gleichzeitig
2. ❌ Andere Disk-intensive Tasks parallel
3. ❌ Steam minimieren während Download
4. ❌ Laptop in Sleep-Modus während Download
5. ❌ VPN während Downloads (verlangsamt oft)

---

## 🚀 Zusammenfassung

### Sofort-Maßnahmen:

```
1. Steam → Einstellungen → Downloads
   ↓
2. Region auf "Germany - Frankfurt" ändern
   ↓
3. Download-Cache leeren
   ↓
4. Steam neu starten
   ↓
5. Kleines Spiel (< 1 GB) zuerst testen
```

### Erwartung:

- ✅ Erste Downloads: Langsamer Start, wird dann besser
- ✅ Nach 2-3 erfolgreichen Downloads: Stabile Geschwindigkeit
- ✅ Geschwindigkeit: 50-80% der nativen Performance

### Falls nichts hilft:

1. Verwenden Sie das externe `steam-on-m1-wine` Skript
2. Oder: Laden Sie Spiele auf einem echten Windows-PC herunter und kopieren Sie sie

---

## 🎮 Alternativen

### Wenn Downloads zu langsam sind:

**Option 1: Remote-Download**
- Verwenden Sie Steam Remote Desktop
- Laden Sie auf Windows-PC herunter
- Spielen Sie via Steam Remote Play

**Option 2: Spiel-Backup**
- Laden Sie auf Windows herunter
- Erstellen Sie Steam-Backup
- Kopieren Sie zu macOS
- Restore in Wine-Steam

**Option 3: Native Versionen**
- Prüfen Sie ob Spiele native macOS-Versionen haben
- Oder: Verwenden Sie GeForce NOW / Xbox Cloud Gaming

---

## ✅ Erfolgs-Geschichten

**Was FUNKTIONIERT:**
- Indie-Spiele (< 5 GB): ✅ Meist problemlos
- Mittelgroße Spiele (5-20 GB): ✅ Mit Geduld möglich
- Große Spiele (> 50 GB): ⚠️ Langsam, aber machbar

**Realistische Zeiten:**
- 1 GB Spiel: ~5-10 Minuten
- 10 GB Spiel: ~30-60 Minuten
- 50 GB Spiel: ~3-6 Stunden

Viel Erfolg! 🍀
