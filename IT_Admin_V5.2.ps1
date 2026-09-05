# ==============================================================================
# SISTEMA DE ADMINISTRACIÓN IT V5.2 - ZERO TOUCH PROVISIONING (PRODUCTION READY)
# Arquitectura: Máquina de Estados Modular | Motor: PowerShell 7+ / Winget
# ==============================================================================

# 1. VERIFICACIÓN ESTRICTA DE PRIVILEGIOS (UAC)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $PowerShellExe = (Get-Process -Id $PID).Path
    if (-not $PowerShellExe) { $PowerShellExe = "powershell" }
    Start-Process $PowerShellExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# FIX ENCODING: Forzar UTF-8 en consola para caracteres en español y evitar ParseErrors
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- INICIO DE LA MEMORIA RAM DEL SCRIPT Y PROTOCOLOS MODERNOS ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13 -bor [Net.SecurityProtocolType]::Tls12

# Directorio de persistencia seguro (evita ser borrado por limpieza de temporales)
$AppDir = Join-Path $env:LOCALAPPDATA "Otimizer_M"
if (-not (Test-Path $AppDir)) { New-Item -Path $AppDir -ItemType Directory -Force | Out-Null }
$LogPath = Join-Path $AppDir "installs_session.log"

# Migración de log antiguo desde %TEMP% si existiera
$OldTempLog = "$env:TEMP\installs_session.log"
if ((Test-Path $OldTempLog) -and (-not (Test-Path $LogPath))) {
    Copy-Item $OldTempLog $LogPath -Force
}

if (Test-Path $LogPath) { $global:HistorialApps = @(Get-Content $LogPath -Encoding UTF8) } else { $global:HistorialApps = @() }

Write-Host "`n[!] Verificando estado del motor Winget..." -ForegroundColor DarkGray
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "    [ ALERTA ] Winget no está instalado o no se encuentra en el PATH del sistema." -ForegroundColor Red
    Write-Host "    Para aprovisionar aplicaciones, instala 'Instalador de aplicaciones' desde Microsoft Store o GitHub." -ForegroundColor Yellow
} else {
    Write-Host "    [ OK ] Motor Winget operativo." -ForegroundColor Green
}

function Instalar-Paquete {
    param (
        [string]$Nombre,
        [string]$WingetID,
        [switch]$PerUser
    )
    Write-Host "`n[+] Instalando: $Nombre ($WingetID)..." -ForegroundColor Cyan
    $Scope = if ($PerUser) { "" } else { "--scope machine" }
    $ArgList = "install --id $WingetID --exact --silent --accept-package-agreements --accept-source-agreements $Scope --force"
    $Proceso = Start-Process winget -ArgumentList $ArgList -Wait -PassThru -NoNewWindow
    
    if ($Proceso.ExitCode -eq 0 -or $Proceso.ExitCode -eq -1978335189 -or $Proceso.ExitCode -eq 0x8a150056) {
        Write-Host "    [ OK ] Instalación exitosa o ya presente." -ForegroundColor Green
        if ($WingetID -notin $global:HistorialApps) {
            $global:HistorialApps += $WingetID
            $WingetID | Out-File -FilePath $LogPath -Append -Encoding utf8
        }
    } else {
        Write-Host "    [ ERROR ] Fallo. Código: $($Proceso.ExitCode)" -ForegroundColor Red
    }
}

function Crear-PuntoRestauracion {
    param ([string]$Descripcion = "Otimizer_M_Checkpoint")
    Write-Host "`n[+] Creando Punto de Restauración del Sistema..." -ForegroundColor Cyan
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $Descripcion -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "    [ OK ] Punto de restauración creado con éxito." -ForegroundColor Green
    } catch {
        Write-Host "    [ ! ] No se pudo crear el punto de restauración: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "    (Puede estar desactivado en Protección del Sistema o haber alcanzado el límite diario)." -ForegroundColor DarkGray
    }
}

function Procesar-Lote {
    param ([array]$PaquetesAInstalar)
    if ($PaquetesAInstalar.Count -eq 0) { return }
    
    Write-Host "`n[!] RESUMEN DE INSTALACIÓN (STAGING):" -ForegroundColor Cyan
    foreach ($App in $PaquetesAInstalar) { Write-Host " -> $($App.Nombre)" -ForegroundColor White }
    
    do {
        $Confirmacion = (Read-Host "`n¿Proceder con la instalación? (Y/N)").Trim().ToLower()
    } until ($Confirmacion -in @('y', 'n'))
    
    if ($Confirmacion -eq 'y') {
        foreach ($App in $PaquetesAInstalar) {
            Instalar-Paquete -Nombre $App.Nombre -WingetID $App.ID -PerUser:($App.PerUser -eq $true)
        }
        Write-Host "`nLote finalizado exitosamente." -ForegroundColor Green
    } else {
        Write-Host "`nOperación abortada por el administrador." -ForegroundColor Yellow
    }
    Write-Host "Presiona ENTER para continuar..." -ForegroundColor Yellow; Read-Host
}

# 3. MOTOR DE ESTADOS (RUTEO PRINCIPAL)
$EstadoMenu = "Principal"
while ($EstadoMenu -ne "Salir") {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "   SISTEMA DE ADMINISTRACIÓN IT V5.2     " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    switch ($EstadoMenu) {

        "Principal" {
            Write-Host "MENÚ PRINCIPAL" -ForegroundColor Yellow
            Write-Host "1. App Windows (Aprovisionamiento Winget)"
            Write-Host "2. Drivers (Portales Oficiales)"
            Write-Host "3. Post Install (Activación, Tweaks, DNS, HAGS)"
            Write-Host "4. Mantenimiento (Limpieza y Reparación)"
            Write-Host "5. Descargas Windows y Office (ISOs/C2R)"
            Write-Host "6. Arrepentimiento (Deshacer Cambios)"
            Write-Host "0. Salir del Sistema"
            Write-Host "-----------------------------------------" -ForegroundColor Cyan
            $Opcion = Read-Host "Selecciona una opción"
            
            if ($Opcion -eq '1') { $EstadoMenu = "SeccionApps" }
            elseif ($Opcion -eq '2') { $EstadoMenu = "SeccionDrivers" }
            elseif ($Opcion -eq '3') { $EstadoMenu = "SeccionPostInstall" }
            elseif ($Opcion -eq '4') { $EstadoMenu = "SeccionMantenimiento" }
            elseif ($Opcion -eq '5') { $EstadoMenu = "SeccionOS" }
            elseif ($Opcion -eq '6') { $EstadoMenu = "SeccionArrepentimiento" }
            elseif ($Opcion -eq '0') { $EstadoMenu = "Salir" }
        }

        # --- MÓDULO 1: APPS ---
        "SeccionApps" {
            Write-Host "MÓDULO 1: APPS > CATEGORÍAS" -ForegroundColor Yellow
            Write-Host "1. Gaming"
            Write-Host "2. Music"
            Write-Host "3. Chats"
            Write-Host "4. Browsers"
            Write-Host "5. Gestión de archivos y compresión"
            Write-Host "6. Gestores de descarga"
            Write-Host "7. Streaming"
            Write-Host "8. Herramientas"
            Write-Host "9. Remoto & Monitoreo"
            Write-Host "0. Volver al Menú Principal"
            Write-Host "-----------------------------------------" -ForegroundColor Cyan
            $Opcion = Read-Host "Selecciona una categoría"
            switch ($Opcion) {
                '1' { $EstadoMenu = "Gaming" } '2' { $EstadoMenu = "Music" }
                '3' { $EstadoMenu = "Chats" } '4' { $EstadoMenu = "Browsers" }
                '5' { $EstadoMenu = "GestionArchivos" } '6' { $EstadoMenu = "GestoresDescarga" }
                '7' { $EstadoMenu = "Streaming" } '8' { $EstadoMenu = "Herramientas" }
                '9' { $EstadoMenu = "RemotoMonitoreo" }
                '0' { $EstadoMenu = "Principal" }
            }
        }

        "Gaming" {
            Write-Host "APPS > GAMING" -ForegroundColor Yellow
            Write-Host "1. Steam | 2. EA App | 3. Epic Games | 4. Ubisoft Connect | 0. Volver"
            $Entrada = Read-Host "Selecciona apps (Ej: 1 3) o 0 para volver"
            if (($Entrada -split '\s+') -contains '0') { $EstadoMenu = "SeccionApps"; continue }
            $Lista = @()
            foreach ($Opc in ($Entrada -split '\s+')) {
                switch ($Opc) {
                    '1' { $Lista += [pscustomobject]@{ Nombre = "Steam"; ID = "Valve.Steam"; PerUser = $false } }
                    '2' { $Lista += [pscustomobject]@{ Nombre = "EA App"; ID = "ElectronicArts.EADesktop"; PerUser = $false } }
                    '3' { $Lista += [pscustomobject]@{ Nombre = "Epic Games"; ID = "EpicGames.EpicGamesLauncher"; PerUser = $false } }
                    '4' { $Lista += [pscustomobject]@{ Nombre = "Ubisoft Connect"; ID = "Ubisoft.Connect"; PerUser = $false } }
                }
            }
            Procesar-Lote -PaquetesAInstalar $Lista
        }

        "Music" {
            Write-Host "APPS > MUSIC" -ForegroundColor Yellow
            Write-Host "1. Spotify (Oficial EXE) | 2. YouTube Music | 0. Volver"
            $Entrada = Read-Host "Selecciona apps o 0 para volver"
            if (($Entrada -split '\s+') -contains '0') { $EstadoMenu = "SeccionApps"; continue }
            $Lista = @()
            foreach ($Opc in ($Entrada -split '\s+')) {
                switch ($Opc) {
                    '1' { $Lista += [pscustomobject]@{ Nombre = "Spotify"; ID = "Spotify.Spotify"; PerUser = $true } }
                    '2' { $Lista += [pscustomobject]@{ Nombre = "YouTube Music"; ID = "Ytmdesktop.Ytmdesktop"; PerUser = $false } }
                }
            }
            Procesar-Lote -PaquetesAInstalar $Lista
        }

        "Chats" {
            Write-Host "APPS > CHATS" -ForegroundColor Yellow
            Write-Host "1. Discord | 2. WhatsApp | 0. Volver"
            $Entrada = Read-Host "Selecciona apps o 0 para volver"
            if (($Entrada -split '\s+') -contains '0') { $EstadoMenu = "SeccionApps"; continue }
            $Lista = @()
            foreach ($Opc in ($Entrada -split '\s+')) {
                switch ($Opc) {
                    # Discord DEBE ser PerUser=$true porque usa estructura %LocalAppData%
                    '1' { $Lista += [pscustomobject]@{ Nombre = "Discord"; ID = "Discord.Discord"; PerUser = $true } }
                    '2' { $Lista += [pscustomobject]@{ Nombre = "WhatsApp (MS Store)"; ID = "9NKSQCE66MRU"; PerUser = $false } }
                }
            }
            Procesar-Lote -PaquetesAInstalar $Lista
        }

        "Browsers" {
            Write-Host "APPS > BROWSERS" -ForegroundColor Yellow
            Write-Host "1. Chrome | 2. Edge | 3. Firefox | 4. Brave | 0. Volver"
            $Entrada = Read-Host "Selecciona apps o 0 para volver"
            if (($Entrada -split '\s+') -contains '0') { $EstadoMenu = "SeccionApps"; continue }
            $Lista = @()
            foreach ($Opc in ($Entrada -split '\s+')) {
                switch ($Opc) {
                    '1' { $Lista += [pscustomobject]@{ Nombre = "Chrome"; ID = "Google.Chrome"; PerUser = $false } }
                    '2' { $Lista += [pscustomobject]@{ Nombre = "Edge"; ID = "Microsoft.Edge"; PerUser = $false } }
                    '3' { $Lista += [pscustomobject]@{ Nombre = "Firefox"; ID = "Mozilla.Firefox"; PerUser = $false } }
                    '4' { $Lista += [pscustomobject]@{ Nombre = "Brave"; ID = "Brave.Brave"; PerUser = $false } }
                }
            }
            Procesar-Lote -PaquetesAInstalar $Lista
        }

        "GestionArchivos" {
            Write-Host "APPS > GESTIÓN ARCHIVOS" -ForegroundColor Yellow
            Write-Host "1. WinRAR | 2. 7-Zip | 0. Volver"
            $Entrada = Read-Host "Selecciona apps o 0 para volver"
            if (($Entrada -split '\s+') -contains '0') { $EstadoMenu = "SeccionApps"; continue }
            $Lista = @()
            foreach ($Opc in ($Entrada -split '\s+')) {
                switch ($Opc) {
                    '1' { $Lista += [pscustomobject]@{ Nombre = "WinRAR"; ID = "RARLab.WinRAR"; PerUser = $false } }
                    '2' { $Lista += [pscustomobject]@{ Nombre = "7-Zip"; ID = "7zip.7zip"; PerUser = $false } }
                }
            }
            Procesar-Lote -PaquetesAInstalar $Lista
        }

        "GestoresDescarga" {
            Write-Host "APPS > GESTORES DE DESCARGA" -ForegroundColor Yellow
            Write-Host "1. AB Download Manager | 2. qBittorrent | 0. Volver"
            $Entrada = Read-Host "Selecciona apps o 0 para volver"
            if (($Entrada -split '\s+') -contains '0') { $EstadoMenu = "SeccionApps"; continue }
            $Lista = @()
            foreach ($Opc in ($Entrada -split '\s+')) {
                switch ($Opc) {
                    '1' { $Lista += [pscustomobject]@{ Nombre = "AB Download Manager"; ID = "amir1376.ABDownloadManager"; PerUser = $false } }
                    '2' { $Lista += [pscustomobject]@{ Nombre = "qBittorrent"; ID = "qBittorrent.qBittorrent"; PerUser = $false } }
                }
            }
            Procesar-Lote -PaquetesAInstalar $Lista
        }

        "Streaming" {
            Write-Host "APPS > STREAMING" -ForegroundColor Yellow
            Write-Host "1. OBS Studio | 0. Volver"
            $Entrada = Read-Host "Selecciona apps o 0 para volver"
            if (($Entrada -split '\s+') -contains '0') { $EstadoMenu = "SeccionApps"; continue }
            $Lista = @()
            foreach ($Opc in ($Entrada -split '\s+')) {
                switch ($Opc) {
                    '1' { $Lista += [pscustomobject]@{ Nombre = "OBS Studio"; ID = "OBSProject.OBSStudio"; PerUser = $false } }
                }
            }
            Procesar-Lote -PaquetesAInstalar $Lista
        }

        "Herramientas" {
            Write-Host "APPS > HERRAMIENTAS" -ForegroundColor Yellow
            Write-Host "1. MSI Afterburner | 2. CrystalDiskInfo | 3. Visual C++ Redist AIO | 0. Volver"
            $Entrada = Read-Host "Selecciona apps o 0 para volver"
            if (($Entrada -split '\s+') -contains '0') { $EstadoMenu = "SeccionApps"; continue }
            $Lista = @()
            foreach ($Opc in ($Entrada -split '\s+')) {
                switch ($Opc) {
                    '1' { $Lista += [pscustomobject]@{ Nombre = "MSI Afterburner"; ID = "Guru3D.Afterburner"; PerUser = $false } }
                    '2' { $Lista += [pscustomobject]@{ Nombre = "CrystalDiskInfo"; ID = "CrystalDewWorld.CrystalDiskInfo"; PerUser = $false } }
                    '3' {
                        $Lista += [pscustomobject]@{ Nombre = "VC++ Redist (x64)"; ID = "Microsoft.VCRedist.2015+.x64"; PerUser = $false }
                        $Lista += [pscustomobject]@{ Nombre = "VC++ Redist (x86)"; ID = "Microsoft.VCRedist.2015+.x86"; PerUser = $false }
                    }
                }
            }
            Procesar-Lote -PaquetesAInstalar $Lista
        }

        "RemotoMonitoreo" {
            Write-Host "APPS > REMOTO & MONITOREO" -ForegroundColor Yellow
            Write-Host "1. Tailscale | 2. RustDesk | 3. HWiNFO64 | 0. Volver"
            $Entrada = Read-Host "Selecciona apps (Ej: 1 2) o 0 para volver"
            if (($Entrada -split '\s+') -contains '0') { $EstadoMenu = "SeccionApps"; continue }
            $Lista = @()
            foreach ($Opc in ($Entrada -split '\s+')) {
                switch ($Opc) {
                    '1' { $Lista += [pscustomobject]@{ Nombre = "Tailscale"; ID = "Tailscale.Tailscale"; PerUser = $false } }
                    '2' { $Lista += [pscustomobject]@{ Nombre = "RustDesk"; ID = "RustDesk.RustDesk"; PerUser = $false } }
                    '3' { $Lista += [pscustomobject]@{ Nombre = "HWiNFO64"; ID = "REALiX.HWiNFO"; PerUser = $false } }
                }
            }
            Procesar-Lote -PaquetesAInstalar $Lista
        }

        # --- MÓDULO 2: DRIVERS ---
        "SeccionDrivers" {
            Write-Host "MÓDULO 2: DRIVERS > PORTALES DE DESCARGA OFICIALES" -ForegroundColor Yellow
            Write-Host "1. NVIDIA (GeForce Game Ready / Studio)"
            Write-Host "2. AMD (Radeon Graphics / Ryzen Chipsets)"
            Write-Host "3. Intel (Core Processors / Arc Graphics)"
            Write-Host "0. Volver al Menú Principal"
            Write-Host "-----------------------------------------" -ForegroundColor Cyan
            $Opcion = Read-Host "Selecciona el fabricante"
            switch ($Opcion) {
                '1' { Start-Process "https://www.nvidia.com/Download/index.aspx?lang=es"; $EstadoMenu = "Principal"; Start-Sleep -Seconds 1 }
                '2' { Start-Process "https://www.amd.com/es/support/download/drivers.html"; $EstadoMenu = "Principal"; Start-Sleep -Seconds 1 }
                '3' { Start-Process "https://www.intel.la/content/www/xl/es/download-center/home.html"; $EstadoMenu = "Principal"; Start-Sleep -Seconds 1 }
                '0' { $EstadoMenu = "Principal" }
            }
        }

        # --- MÓDULO 3: POST INSTALL ---
        "SeccionPostInstall" {
            Write-Host "MÓDULO 3: POST INSTALL > TWEAKS Y ACTIVACIÓN" -ForegroundColor Yellow
            Write-Host "1. Activación del Sistema (MAS Automático)"
            Write-Host "2. Optimizar Windows (Chris Titus Tech WinUtil)"
            Write-Host "3. Optimizar Apps de Arranque (Startup Delay + WaitForIdleState)"
            Write-Host "4. Optimizar DNS de Red (Auto-Benchmark Multi-Target)"
            Write-Host "5. Desactivar Hibernación (Recuperar espacio en disco)"
            Write-Host "6. Habilitar HAGS (Detección Automática GPU NVIDIA/AMD/Intel Arc)"
            Write-Host "7. Crear Punto de Restauración del Sistema"
            Write-Host "8. Habilitar Telemetría Windows Insider Beta (Fix DiagTrack)"
            Write-Host "9. Inyectar Flags de Rendimiento en Google Chrome"
            Write-Host "0. Volver al Menú Principal"
            Write-Host "-----------------------------------------" -ForegroundColor Cyan
            $Opcion = Read-Host "Selecciona una tarea"
            
            switch ($Opcion) {
                '1' {
                    Write-Host "`n[+] Ejecutando MAS (User-Agent inyectado)..." -ForegroundColor Cyan
                    try { Invoke-Expression (Invoke-RestMethod -Uri "https://get.activated.win" -UserAgent "Mozilla/5.0" -ErrorAction Stop) }
                    catch { Invoke-Expression (curl.exe -s --doh-url https://1.1.1.1/dns-query https://get.activated.win | Out-String) }
                    Read-Host "Presiona ENTER para continuar..."
                }
                '2' {
                    Write-Host "`n[+] Lanzando CTT Windows Utility..." -ForegroundColor Cyan
                    try { Invoke-Expression (Invoke-RestMethod -Uri "https://christitus.com/win" -UserAgent "Mozilla/5.0" -ErrorAction Stop) }
                    catch { Write-Host "    [ ERROR ] Fallo crítico de red." -ForegroundColor Red }
                    Read-Host "Presiona ENTER para continuar..."
                }
                '3' {
                    Write-Host "`n[+] Aplicando Tweak de Registro (Startup Delay + WaitForIdleState)..." -ForegroundColor Cyan
                    $RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
                    if (-not (Test-Path $RegistryPath)) { New-Item -Path $RegistryPath -Force | Out-Null }
                    try {
                        Set-ItemProperty -Path $RegistryPath -Name "StartupDelayInMSec" -Value 0 -Type DWord
                        Set-ItemProperty -Path $RegistryPath -Name "WaitForIdleState" -Value 0 -Type DWord
                        Write-Host "    [ OK ] Valores StartupDelayInMSec=0 y WaitForIdleState=0 inyectados correctamente." -ForegroundColor Green
                    } catch { Write-Host "    [ ERROR ] Fallo al escribir en el registro: $($_.Exception.Message)" -ForegroundColor Red }
                    Read-Host "Presiona ENTER para continuar..."
                }
                '4' {
                    Write-Host "`n[+] Multi-Benchmarking DNS (Google vs Cloudflare vs Quad9)..." -ForegroundColor Cyan
                    try {
                        $Targets = [ordered]@{ "Google" = "8.8.8.8"; "Cloudflare" = "1.1.1.1"; "Quad9" = "9.9.9.9" }
                        $Results = foreach ($Name in $Targets.Keys) {
                            $Time = (1..3 | ForEach-Object {
                                $Ping = Test-Connection $Targets[$Name] -Count 1 -ErrorAction SilentlyContinue
                                # Compatibilidad híbrida: PS 7+ usa .Latency y PS 5.1 usa .ResponseTime
                                if ($null -ne $Ping.Latency) { [double]$Ping.Latency }
                                elseif ($null -ne $Ping.ResponseTime) { [double]$Ping.ResponseTime }
                                else { 999.0 }
                            } | Measure-Object -Average).Average
                            [pscustomobject]@{ Provider = $Name; Latency = [math]::Round([double]$Time, 2); IP = $Targets[$Name] }
                        }
                        $Best = $Results | Sort-Object Latency | Select-Object -First 1
                        Write-Host "    [*] Ganador: $($Best.Provider) con $($Best.Latency)ms" -ForegroundColor Green
                        
                        if ($Best.Provider -eq "Cloudflare") { $DnsServers = "1.1.1.1", "1.0.0.1" }
                        elseif ($Best.Provider -eq "Quad9") { $DnsServers = "9.9.9.9", "149.112.112.112" }
                        else { $DnsServers = "8.8.8.8", "8.8.4.4" }
                        
                        $ActiveAdapters = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }
                        if ($ActiveAdapters) {
                            foreach ($Adapter in $ActiveAdapters) { Set-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex -ServerAddresses $DnsServers }
                            Clear-DnsClientCache; Write-Host "    [ OK ] Caché DNS purgada." -ForegroundColor Green
                        }
                    } catch { Write-Host "    [ ERROR ] Fallo en el test de red: $($_.Exception.Message)" -ForegroundColor Red }
                    Read-Host "Presiona ENTER para continuar..."
                }
                '5' {
                    Write-Host "`n[+] Desactivando Hibernación a nivel de Kernel..." -ForegroundColor Cyan
                    try {
                        powercfg.exe /hibernate off
                        Write-Host "    [ OK ] Hibernación desactivada. Archivo hiberfil.sys purgado con éxito." -ForegroundColor Green
                    } catch { Write-Host "    [ ERROR ] Fallo al ejecutar powercfg." -ForegroundColor Red }
                    Read-Host "Presiona ENTER para continuar..."
                }
                '6' {
                    Write-Host "`n[+] Analizando bus PCIe vía WMI para soporte HAGS..." -ForegroundColor Cyan
                    try {
                        $ControladoresVideo = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
                        $GpuCompatible = $false
                        $ModeloDetectado = ""
                        foreach ($GPU in $ControladoresVideo) {
                            if ($GPU.Name -match "NVIDIA GeForce.*(GTX|RTX)" -or 
                                $GPU.Name -match "AMD Radeon.*RX" -or 
                                $GPU.Name -match "Intel.*Arc.*(A|B)\d{3}") {
                                $GpuCompatible = $true
                                $ModeloDetectado = $GPU.Name
                                break
                            }
                        }
                        
                        if ($GpuCompatible) {
                            Write-Host "    [!] Hardware dedicado detectado: $ModeloDetectado" -ForegroundColor White
                            $RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
                            if (-not (Test-Path $RegistryPath)) { New-Item -Path $RegistryPath -Force | Out-Null }
                            Set-ItemProperty -Path $RegistryPath -Name "HwSchMode" -Value 2 -Type DWord
                            Write-Host "    [ OK ] Hardware Accelerated GPU Scheduling (HAGS) inyectado. Reinicio requerido." -ForegroundColor Green
                        } else {
                            Write-Host "    [ i ] Operación abortada. No se encontró arquitectura GPU dedicada compatible." -ForegroundColor Yellow
                            Write-Host "    [ i ] Compatible con: NVIDIA GTX/RTX, AMD Radeon RX, Intel Arc A/B-series." -ForegroundColor DarkGray
                        }
                    } catch { Write-Host "    [ ERROR ] Fallo crítico al invocar el proveedor WMI de video." -ForegroundColor Red }
                    Read-Host "Presiona ENTER para continuar..."
                }
                '7' {
                    Crear-PuntoRestauracion -Descripcion "Otimizer_M_Manual_Checkpoint"
                    Read-Host "Presiona ENTER para continuar..."
                }
                '8' {
                    Write-Host "`n[+] Configurando telemetría y DiagTrack para Windows Insider Beta..." -ForegroundColor Cyan
                    $PolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
                    if (-not (Test-Path $PolicyPath)) { New-Item -Path $PolicyPath -Force | Out-Null }
                    try {
                        Set-ItemProperty -Path $PolicyPath -Name "AllowTelemetry" -Value 3 -Type DWord
                        Set-Service -Name diagtrack -StartupType Automatic -ErrorAction SilentlyContinue
                        Start-Service -Name diagtrack -ErrorAction SilentlyContinue
                        Write-Host "    [ OK ] Telemetría Nivel 3 (Full) y servicio DiagTrack activados con éxito." -ForegroundColor Green
                    } catch { Write-Host "    [ ERROR ] Fallo al configurar telemetría: $($_.Exception.Message)" -ForegroundColor Red }
                    Read-Host "Presiona ENTER para continuar..."
                }
                '9' {
                    Write-Host "`n[+] Inyectando Flags de rendimiento en Google Chrome..." -ForegroundColor Cyan
                    $ChromeProcs = Get-Process chrome -ErrorAction SilentlyContinue
                    if ($ChromeProcs) {
                        Write-Host "    [!] Cerrando instancias de Google Chrome para actualizar Local State..." -ForegroundColor Yellow
                        $ChromeProcs | Stop-Process -Force
                        Start-Sleep -Seconds 1
                    }
                    
                    $ChromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"
                    $LocalStateFile = Join-Path $ChromeDir "Local State"
                    if (-not (Test-Path $ChromeDir)) { New-Item -Path $ChromeDir -ItemType Directory -Force | Out-Null }
                    
                    try {
                        $JsonData = @{}
                        if (Test-Path $LocalStateFile) {
                            $RawContent = Get-Content -Path $LocalStateFile -Raw -Encoding UTF8
                            if ($RawContent) { $JsonData = $RawContent | ConvertFrom-Json }
                        }
                        
                        if (-not $JsonData.browser) {
                            $JsonData | Add-Member -MemberType NoteProperty -Name "browser" -Value ([pscustomobject]@{}) -Force
                        }
                        
                        $TargetFlags = @(
                            "enable-gpu-rasterization",
                            "ignore-gpu-blocklist",
                            "enable-zero-copy",
                            "enable-parallel-downloading"
                        )
                        
                        $CurrentFlags = @()
                        if ($JsonData.browser.enabled_labs_experiments) {
                            $CurrentFlags = @($JsonData.browser.enabled_labs_experiments)
                        }
                        
                        foreach ($Flag in $TargetFlags) {
                            if ($Flag -notin $CurrentFlags) {
                                $CurrentFlags += $Flag
                            }
                        }
                        
                        $JsonData.browser | Add-Member -MemberType NoteProperty -Name "enabled_labs_experiments" -Value $CurrentFlags -Force
                        $JsonData | ConvertTo-Json -Depth 30 | Set-Content -Path $LocalStateFile -Encoding UTF8
                        Write-Host "    [ OK ] Flags inyectados en Local State: GPU rasterization, Override GPU list, Zero-copy, Parallel downloading." -ForegroundColor Green
                        Write-Host "    [ i ] La aceleración de hardware no se modificó para mantener compatibilidad con Discord/DRM." -ForegroundColor DarkGray
                    } catch {
                        Write-Host "    [ ERROR ] Fallo al inyectar flags en Chrome: $($_.Exception.Message)" -ForegroundColor Red
                    }
                    Read-Host "Presiona ENTER para continuar..."
                }
                '0' { $EstadoMenu = "Principal" }
            }
        }

        # --- MÓDULO 4: MANTENIMIENTO ---
        "SeccionMantenimiento" {
            Write-Host "MÓDULO 4: MANTENIMIENTO > LIMPIEZA Y REPARACIÓN" -ForegroundColor Yellow
            Write-Host "1. Reparación de Integridad del Sistema (DISM + SFC)"
            Write-Host "2. Purgar Archivos Temporales (System, User, Prefetch)"
            Write-Host "3. Limpieza de Almacenamiento Profunda (VeryLowDisk + ResetBase)"
            Write-Host "0. Volver al Menú Principal"
            Write-Host "-----------------------------------------" -ForegroundColor Cyan
            $Opcion = Read-Host "Selecciona una tarea"
            switch ($Opcion) {
                '1' {
                    Write-Host "`n[+] Fase 1/2: DISM RestoreHealth..." -ForegroundColor Yellow; DISM /Online /Cleanup-Image /RestoreHealth
                    Write-Host "`n[+] Fase 2/2: SFC ScanNow..." -ForegroundColor Yellow; sfc /scannow
                    Read-Host "Ciclo completado. Presiona ENTER para continuar..."
                }
                '2' {
                    Write-Host "`n[+] Purgando temporales de usuario y sistema..." -ForegroundColor Cyan
                    foreach ($Dir in @("$env:TEMP\*", "$env:windir\Temp\*")) {
                        Get-ChildItem -Path $Dir -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*Otimizer_M*" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-Host "    [ OK ] Limpieza de archivos temporales completada." -ForegroundColor Green; Read-Host "Presiona ENTER para continuar..."
                }
                '3' {
                    Write-Host "`n[!] ADVERTENCIA: La purga profunda con ResetBase elimina versiones previas de componentes de Windows Update." -ForegroundColor Yellow
                    Write-Host "    Una vez completada, NO podrás desinstalar las actualizaciones instaladas hasta la fecha." -ForegroundColor Yellow
                    $ConfirmResetBase = (Read-Host "`n¿Deseas continuar con la limpieza profunda? (Y/N)").Trim().ToLower()
                    if ($ConfirmResetBase -eq 'y') {
                        Write-Host "`n[+] Iniciando Limpieza de Almacenamiento Inteligente (Zero Touch)..." -ForegroundColor Cyan
                        Start-Process "cleanmgr.exe" -ArgumentList "/verylowdisk" -Wait
                        Write-Host "`n[+] Purgando Component Store de Windows Update..." -ForegroundColor Cyan
                        Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
                        Write-Host "    [ OK ] Limpieza profunda finalizada." -ForegroundColor Green
                    } else {
                        Write-Host "`n[!] Operación cancelada por el usuario." -ForegroundColor DarkGray
                    }
                    Read-Host "Presiona ENTER para continuar..."
                }
                '0' { $EstadoMenu = "Principal" }
            }
        }

        # --- MÓDULO 5: DESCARGAS WINDOWS ---
        "SeccionOS" {
            Write-Host "MÓDULO 5: DESCARGAS WINDOWS > DIRECTORIOS MAS OFICIALES" -ForegroundColor Yellow
            Write-Host "1. Obtener ISOs de Windows"
            Write-Host "2. Obtener instaladores Office (C2R)"
            Write-Host "0. Volver al Menú Principal"
            Write-Host "-----------------------------------------" -ForegroundColor Cyan
            $Opcion = Read-Host "Selecciona una opción"
            switch ($Opcion) {
                '1' { Start-Process "https://massgrave.dev/windows_11_links"; $EstadoMenu = "Principal"; Start-Sleep -Seconds 1 }
                '2' { Start-Process "https://massgrave.dev/office_c2r_links"; $EstadoMenu = "Principal"; Start-Sleep -Seconds 1 }
                '0' { $EstadoMenu = "Principal" }
            }
        }

        # --- MÓDULO 6: ARREPENTIMIENTO ---
        "SeccionArrepentimiento" {
            Write-Host "SALA DE ARREPENTIMIENTO > ROLLBACK QUIRÚRGICO" -ForegroundColor Red
            Write-Host "1. Deshacer Aplicaciones Instaladas (Purga selectiva de Winget)"
            Write-Host "2. Deshacer Tweak de Arranque (Borrar Registro Serialize)"
            Write-Host "3. Restaurar DNS a Automático (Volver a DHCP del ISP)"
            Write-Host "4. Restaurar Hibernación (Reactivar hiberfil.sys)"
            Write-Host "5. Restaurar HAGS (Desactivar Hardware Accelerated GPU Scheduling)"
            Write-Host "6. Restaurar Telemetría a Nivel Básico (Revertir Insider Beta)"
            Write-Host "0. Volver al Menú Principal"
            Write-Host "-----------------------------------------" -ForegroundColor Cyan
            Write-Host "[!] NOTA: Los Tweaks aplicados con CTT deben revertirse desde su interfaz." -ForegroundColor DarkGray
            
            $Opcion = Read-Host "`nSelecciona qué cambio individual deseas revertir"
            switch ($Opcion) {
                '1' {
                    if ($global:HistorialApps.Count -eq 0) {
                        Write-Host "`n[!] No hay aplicaciones registradas para desinstalar." -ForegroundColor Yellow
                    } else {
                        Write-Host "`n[+] APLICACIONES INSTALADAS REGISTRADAS:" -ForegroundColor Cyan
                        for ($i = 0; $i -lt $global:HistorialApps.Count; $i++) {
                            Write-Host "    $($i + 1). $($global:HistorialApps[$i])" -ForegroundColor White
                        }
                        Write-Host "    0. Cancelar y Volver" -ForegroundColor DarkGray
                        
                        $Entrada = Read-Host "`nSelecciona el número de las apps a borrar (Ej: 1 2) o 0 para cancelar"
                        if (($Entrada -split '\s+') -notcontains '0') {
                            $AppsABorrar = @()
                            foreach ($Num in ($Entrada -split '\s+')) {
                                if ([int]::TryParse($Num, [ref]$null)) {
                                    $Indice = [int]$Num - 1
                                    if ($Indice -ge 0 -and $Indice -lt $global:HistorialApps.Count) {
                                        $AppsABorrar += $global:HistorialApps[$Indice]
                                    }
                                }
                            }
                            
                            foreach ($AppID in $AppsABorrar) {
                                Write-Host "`n    -> Desinstalando: $AppID..." -ForegroundColor DarkGray
                                winget uninstall --id $AppID --silent --accept-source-agreements | Out-Null
                                Write-Host "    [ OK ] $AppID eliminado del sistema." -ForegroundColor Green
                            }
                            
                            $global:HistorialApps = $global:HistorialApps | Where-Object { $_ -notin $AppsABorrar }
                            $global:HistorialApps | Out-File -FilePath $LogPath -Force -Encoding utf8
                        } else { Write-Host "    [!] Operación cancelada." -ForegroundColor Yellow }
                    }
                    Read-Host "`nPresiona ENTER para continuar..."
                }
                '2' {
                    Write-Host "`n[+] Eliminando Tweak de arranque (Registro)..." -ForegroundColor Cyan
                    $RegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
                    if (Test-Path $RegistryPath) {
                        Remove-Item -Path $RegistryPath -Force -Recurse | Out-Null
                        Write-Host "    [ OK ] Clave 'Serialize' eliminada. El retraso de inicio volvió a la normalidad de Windows." -ForegroundColor Green
                    } else { Write-Host "    [!] El Tweak de registro no estaba aplicado." -ForegroundColor Yellow }
                    Read-Host "`nPresiona ENTER para continuar..."
                }
                '3' {
                    Write-Host "`n[+] Restaurando DNS a Automático (DHCP)..." -ForegroundColor Cyan
                    $ActiveAdapters = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null }
                    if ($ActiveAdapters) {
                        foreach ($Adapter in $ActiveAdapters) {
                            Set-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex -ResetServerAddresses
                            Write-Host "    [ OK ] DNS automático restaurado en el adaptador: $($Adapter.InterfaceAlias)" -ForegroundColor Green
                        }
                        Clear-DnsClientCache; Write-Host "    [ OK ] Caché DNS purgada." -ForegroundColor Green
                    } else { Write-Host "    [ ERROR ] No se detectaron adaptadores de red activos." -ForegroundColor Red }
                    Read-Host "`nPresiona ENTER para continuar..."
                }
                '4' {
                    Write-Host "`n[+] Restaurando Hibernación a nivel de Kernel..." -ForegroundColor Cyan
                    try {
                        powercfg.exe /hibernate on
                        Write-Host "    [ OK ] Hibernación reactivada con éxito." -ForegroundColor Green
                    } catch { Write-Host "    [ ERROR ] Fallo al ejecutar powercfg." -ForegroundColor Red }
                    Read-Host "`nPresiona ENTER para continuar..."
                }
                '5' {
                    Write-Host "`n[+] Restaurando HAGS (Hardware Accelerated GPU Scheduling)..." -ForegroundColor Cyan
                    $RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
                    if ((Test-Path $RegistryPath) -and ((Get-ItemProperty -Path $RegistryPath -Name "HwSchMode" -ErrorAction SilentlyContinue) -ne $null)) {
                        Remove-ItemProperty -Path $RegistryPath -Name "HwSchMode" -Force -ErrorAction SilentlyContinue
                        Write-Host "    [ OK ] Clave HwSchMode eliminada. HAGS restaurado al valor por defecto. Reinicio requerido." -ForegroundColor Green
                    } else {
                        Write-Host "    [!] HAGS no estaba configurado o ya se encuentra en su valor por defecto." -ForegroundColor Yellow
                    }
                    Read-Host "`nPresiona ENTER para continuar..."
                }
                '6' {
                    Write-Host "`n[+] Restaurando Telemetría al valor predeterminado (Nivel 1)..." -ForegroundColor Cyan
                    $PolicyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
                    if (Test-Path $PolicyPath) {
                        Set-ItemProperty -Path $PolicyPath -Name "AllowTelemetry" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                        Write-Host "    [ OK ] Telemetría restablecida a nivel básico (1)." -ForegroundColor Green
                    }
                    Read-Host "`nPresiona ENTER para continuar..."
                }
                '0' { $EstadoMenu = "Principal" }
                default { Write-Host "    [!] Opción no válida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
            }
        }
    }
}
Write-Host "`nSistema cerrado limpiamente. Desconectando motor." -ForegroundColor DarkGray
Start-Sleep -Seconds 2
