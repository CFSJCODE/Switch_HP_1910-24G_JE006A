# Captura somente leitura do HP V1910-24G (JE006A) pela porta de console.
# Uso: powershell -ExecutionPolicy Bypass -File .\hp1910-capture.ps1 [-Port COM3] [-CmdlineMode]
# Nao altera nem salva configuracao. Se o switch pedir usuario/senha, o script para e avisa.
param(
    [string]$Port,
    [switch]$CmdlineMode,          # tenta "_cmdline-mode on"; vale so para a sessao
    [string]$CmdlinePassword = $env:HP1910_CMDLINE_PASSWORD,  # senha do _cmdline-mode (nao versionada)
    [int]$Baud = 38400
)
if ($CmdlineMode -and -not $CmdlinePassword) { Write-Error 'Defina HP1910_CMDLINE_PASSWORD ou passe -CmdlinePassword.'; exit 1 }

if (-not $Port) {
    $usb = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\(COM\d+\)' -and $_.PNPDeviceID -match '^(USB|FTDIBUS)' }
    if (-not $usb) { Write-Error 'Nenhuma porta serial USB encontrada. Conecte o cabo de console.'; exit 1 }
    $Port = ([regex]::Match($usb[0].Name, 'COM\d+')).Value
    Write-Host "Usando $Port ($($usb[0].Name))"
}

$sp = New-Object System.IO.Ports.SerialPort $Port, $Baud, 'None', 8, 'One'
$sp.Handshake = 'None'; $sp.NewLine = "`r"; $sp.ReadTimeout = 500
$sp.Open()

function Read-Until([string[]]$patterns, [int]$timeoutMs = 8000) {
    $buf = ''; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
        $chunk = $sp.ReadExisting()
        if ($chunk) {
            $buf += $chunk; $sw.Restart()
            if ($chunk -match '----\s*More\s*----') { $sp.Write(' ') }
            foreach ($p in $patterns) { if ($buf -match $p) { return $buf } }
        } else { Start-Sleep -Milliseconds 100 }
    }
    return $buf
}

$prompt = '[<\[][^\r\n<>\[\]]+[>\]]\s*$'
$out = New-Object System.Text.StringBuilder
$sp.Write("`r"); Start-Sleep -Milliseconds 300; $sp.Write("`r")
$banner = Read-Until @($prompt, 'Username:', 'Password:', 'login:') 6000
[void]$out.AppendLine("=== banner ===`r`n$banner")
if ($banner -match 'Username:|Password:|login:') {
    $sp.Close(); $out.ToString() | Set-Content -Encoding utf8 hp1910-capture.txt
    Write-Warning 'O switch pediu credenciais. Nada foi enviado. Veja hp1910-capture.txt.'; exit 2
}

if ($CmdlineMode) {
    $sp.WriteLine('_cmdline-mode on')
    $r = Read-Until @('\[Y/N\]', $prompt) 5000; [void]$out.AppendLine($r)
    if ($r -match '\[Y/N\]') { $sp.WriteLine('Y'); $r = Read-Until @('assword', $prompt) 5000; [void]$out.AppendLine($r) }
    if ($r -match 'assword') { $sp.WriteLine($CmdlinePassword); $r = Read-Until @($prompt) 5000; [void]$out.AppendLine(($r -replace [regex]::Escape($CmdlinePassword), '******')) }
}

$cmds = 'display version', 'display current-configuration', 'display interface brief', 'display vlan all', 'display ip interface brief'
foreach ($c in $cmds) {
    $sp.WriteLine($c)
    $r = Read-Until @($prompt) 30000
    [void]$out.AppendLine("`r`n=== $c ===`r`n$r")
}
$sp.Close()
$file = "hp1910-capture-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
($out.ToString() -replace '----\s*More\s*----', '' -replace "`e\[\d*[A-Za-z]", '') | Set-Content -Encoding utf8 $file
Write-Host "Saida salva em $file"
