# Steam Netzwerk-Konfiguration unter Wine

## ✅ Standard-Verhalten

**Gute Nachricht:** Steam sollte **sofort** funktionieren!

Wine nutzt:
- macOS's Netzwerk-Stack direkt
- Keine NAT oder Virtualisierung
- DNS von macOS automatisch

## 🔍 Diagnostizieren von Problemen

### Test 1: Kann Steam sich anmelden?

**Ja** → Netzwerk funktioniert!  
**Nein** → Siehe Lösungen unten

### Test 2: Können Sie die Steam-Webseite in Steam sehen?

**Ja** → HTTPS funktioniert!  
**Nein** → SSL-Zertifikate könnten fehlen

### Test 3: Starten Downloads?

**Ja** → Alles perfekt! 🎉  
**Nein** → Siehe Firewall-Einstellungen

---

## 🛠️ Lösungen für häufige Probleme

### Problem 1: "Verbindung zum Steam-Netzwerk fehlgeschlagen"

**Ursache:** Steam-Server nicht erreichbar

**Lösung 1:** DNS-Server prüfen
```bash
# In Terminal:
cat /etc/resolv.conf
```

Sollte Google DNS oder ähnliches zeigen. Falls nicht:
```bash
# Temporär Google DNS verwenden:
export WINEDLLOVERRIDES="dnsapi=n,b"
```

**Lösung 2:** Steam-Server-Region ändern
- In Steam → Einstellungen → Downloads
- Download-Region auf "Germany - Frankfurt" setzen

### Problem 2: SSL-Fehler / HTTPS funktioniert nicht

**Symptom:**
- "Secure Connection Failed" Fehler
- Steam Store zeigt nicht

**Lösung:** SSL-Zertifikate installieren ✅ (macht unser Setup automatisch!)

```swift
// Bereits in SteamSetupService implementiert:
installSSLCertificates(to: prefixURL)
```

### Problem 3: Downloads starten nicht

**Ursache:** Firewall blockiert Steam

**Lösung:** Fügen Sie Wine zur Firewall hinzu:
1. Systemeinstellungen → Netzwerk
2. Firewall → Firewall-Optionen
3. Fügen Sie hinzu: `/Applications/Wine Stable.app`
4. Erlauben Sie eingehende Verbindungen

### Problem 4: Langsame Downloads

**Ursache:** MTU-Einstellungen oder Server-Überlastung

**Lösung 1:** Download-Server ändern
- Steam → Einstellungen → Downloads
- Verschiedene Regionen ausprobieren

**Lösung 2:** Download-Bandbreite begrenzen
- Steam → Einstellungen → Downloads
- Bandbreite auf 80% der verfügbaren setzen

---

## 🔧 Erweiterte Konfiguration

### Manuelle DNS-Konfiguration in Wine

Falls automatisches DNS nicht funktioniert:

```bash
# In Terminal, für den Wine-Prefix:
export WINEPREFIX="/path/to/your/prefix"

# DNS-Server setzen:
cat > "$WINEPREFIX/drive_c/windows/system32/drivers/etc/hosts" << EOF
# Steam Server
208.64.200.0    steampowered.com
208.64.200.0    store.steampowered.com
EOF
```

### Proxy-Konfiguration

Falls Sie einen Proxy verwenden:

```bash
# In Terminal:
export http_proxy="http://proxy.example.com:8080"
export https_proxy="http://proxy.example.com:8080"

# Dann Steam starten
```

---

## 📊 Netzwerk-Tests

### Test mit Wine-Befehl:

```bash
# Teste DNS-Auflösung:
WINEPREFIX=/path/to/prefix wine cmd /c "ping steampowered.com"

# Teste HTTPS:
WINEPREFIX=/path/to/prefix wine cmd /c "curl https://store.steampowered.com"
```

### Was sollte funktionieren:

| Test | Erwartetes Ergebnis |
|------|---------------------|
| DNS-Auflösung | ✅ IP-Adresse wird angezeigt |
| HTTPS-Verbindung | ✅ HTML-Code wird geladen |
| Steam-Login | ✅ Erfolgreich |
| Store-Anzeige | ✅ Webseiten laden |
| Downloads | ✅ Spiele werden heruntergeladen |

---

## 🎯 Zusammenfassung

### Automatisch durch unseren Launcher:

✅ SSL-Zertifikate werden installiert  
✅ DNS wird von macOS übernommen  
✅ Netzwerk funktioniert out-of-the-box  

### Was Sie TUN müssen:

❌ **Nichts!** Es sollte einfach funktionieren.

### Falls Probleme auftreten:

1. Prüfen Sie macOS Firewall-Einstellungen
2. Versuchen Sie andere Download-Regionen
3. Stellen Sie sicher, dass Wine in der Firewall erlaubt ist

---

## 💡 Pro-Tipps

### Schnellere Downloads:

1. **Download-Region optimieren:**
   - Wählen Sie geografisch nahe Server
   - Probieren Sie mehrere aus

2. **Bandbreite nicht limitieren:**
   - Steam → Einstellungen → Downloads
   - "Limit bandwidth" AUS lassen

3. **Steam während Downloads nicht stören:**
   - Keine anderen Downloads parallel
   - Keine Spiele spielen während Downloads

### Problembehandlung:

**Wenn Steam sagt "No Internet":**
```bash
# Test 1: macOS hat Internet?
ping google.com

# Test 2: Wine kann DNS auflösen?
WINEPREFIX=/your/prefix wine cmd /c "ping google.com"

# Test 3: Steam-Server erreichbar?
ping 208.64.200.0
```

**Wenn alles andere fehlschlägt:**
- Starten Sie Steam neu
- Starten Sie macOS neu
- Überprüfen Sie Router/Modem

---

## 🚀 Fazit

**In 99% der Fälle:** Funktioniert sofort ohne Konfiguration!  
**Unser Setup:** Installiert SSL-Zertifikate automatisch  
**Ihr Job:** Steam starten und Spiele genießen! 🎮
