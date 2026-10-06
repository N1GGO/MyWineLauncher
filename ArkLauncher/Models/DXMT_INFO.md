# Was ist DXMT/DXVK?

## 🎮 Die Technologie

**DXVK** (DirectX Vulkan) ist ein Open-Source-Projekt, das:
- DirectX 9/10/11 nach Vulkan übersetzt
- Ursprünglich für Linux entwickelt wurde
- Von **Philip Rebohle** erstellt wurde

**DXMT** ist eine Variante/Fork, die:
- DirectX nach **Metal** übersetzt (für macOS)
- Speziell für Apple Silicon optimiert ist
- Die gleiche Codebasis wie DXVK nutzt

## 📦 Was wir installieren

In unserem Launcher laden wir **DXVK** von GitHub:
```
https://github.com/doitsujin/dxvk/releases/download/v2.4/dxvk-2.4.tar.gz
```

Diese DLLs funktionieren auf macOS, weil:
1. **Wine** sie lädt (als würden sie unter Windows laufen)
2. **DXVK/DXMT** DirectX-Calls abfängt
3. **Metal** (Apples GPU-API) für das eigentliche Rendering verwendet

## 🔧 Die installierten DLLs

- `d3d11.dll` - DirectX 11
- `dxgi.dll` - DirectX Graphics Infrastructure
- `d3d10core.dll` - DirectX 10
- `d3d9.dll` - DirectX 9

Diese ersetzen die **Wine builtin** Implementierungen und bieten:
- ✅ Bessere Performance
- ✅ GPU-Beschleunigung
- ✅ Kompatibilität mit modernen Spielen

## 💡 Warum ist das wichtig für Steam?

Steam's Chromium-Browser (CEF) verwendet:
- **DirectX 11** für Hardware-Beschleunigung
- Ohne DXMT → schwarzes Fenster
- Mit DXMT → funktionierendes Rendering

## 🎯 Fazit

**DXMT alleine reicht aus** für Steam, weil:
1. Es DirectX → Metal Translation bietet
2. Steam's CEF damit rendern kann
3. Der Wrapper nur zusätzliche Flags setzt (optional)

Das ist der Grund, warum Ihre Beobachtung korrekt war:
> "Liegt es vielleicht nur am DXMT?" - **JA!** ✅
