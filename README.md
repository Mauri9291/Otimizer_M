# Otimizer_M 🛠️

Script personal de administración IT para Windows, orientado a post-instalación y mantenimiento rápido de un sistema limpio.

> ⚠️ **Uso personal.** No está pensado como herramienta pública ni tiene soporte. Si lo encontraste y lo querés usar, hacelo bajo tu propio riesgo y revisá el código antes.

---

## ¿Qué hace?

Menú interactivo en PowerShell con 6 módulos:

- **Apps** — Instalación silenciosa vía Winget (Gaming, Browsers, Chats, Música, Herramientas, Remoto & Monitoreo)
- **Drivers** — Acceso directo a los portales oficiales de NVIDIA, AMD e Intel
- **Post Install** — Activación MAS, optimización con CTT WinUtil, arranque rápido (StartupDelay + WaitForIdleState), benchmark DNS, hibernación, HAGS, punto de restauración, telemetría Windows Insider (Beta) e inyección de flags en Chrome
- **Mantenimiento** — DISM + SFC, limpieza segura de temporales (sin tocar Prefetch) y Component Store
- **Descargas** — Links directos a ISOs de Windows y Office (vía MAS)
- **Arrepentimiento** — Rollback quirúrgico: desinstala apps de sesión, revierte tweaks de registro, restaura DNS, hibernación, HAGS y telemetría

---

## Uso

Abrir PowerShell como Administrador y ejecutar:

```powershell
$tmp = "$env:TEMP\itadmin.ps1"; if (Test-Path $tmp) { Remove-Item $tmp -Force }; irm https://raw.githubusercontent.com/Mauri9291/Otimizer_M/main/IT_Admin_V5.2.ps1 -OutFile $tmp; powershell -ExecutionPolicy Bypass -File $tmp
```

---

## Requisitos

- Windows 10/11
- PowerShell 5.1 o superior (totalmente compatible con Windows PowerShell 5.1 y PS 7+)
- Winget instalado (viene por defecto en Windows 11 y W10 actualizado)
- Ejecutar siempre como **Administrador**

---

## Notas técnicas

- Las instalaciones usan `--scope machine` por defecto. Los paquetes que no lo soportan (como Spotify) se instalan en modo per-user automáticamente.
- El módulo de Arrepentimiento persiste el historial de instalaciones en `%LOCALAPPDATA%\Otimizer_M\installs_session.log` para poder revertir entre sesiones sin riesgo de auto-borrado por limpieza de temporales.
- HAGS compatible con NVIDIA GTX/RTX, AMD Radeon RX e Intel Arc A/B-series con soporte para reversión completa.
- El benchmark de DNS compara Google, Cloudflare y Quad9 con soporte nativo multiplataforma (híbrido `.Latency` y `.ResponseTime`).
- Flags de Chrome inyectados directamente en `%LOCALAPPDATA%\Google\Chrome\User Data\Local State` (no dependen de accesos directos y respetan el interruptor manual de aceleración por hardware para Discord/DRM).
- Script guardado en UTF-8 con BOM para evitar fallos de parseo en Windows PowerShell 5.1.
