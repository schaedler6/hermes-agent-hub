param($Config)

$Name = "Codex"
$Category = "CLI Assistant"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "codex"
$InstallPath = ""
$DetectionMethod = "PATH & Profile Search"
$Notes = ""

$GetVersionScript = Join-Path $PSScriptRoot "../Get-AgentVersion.ps1"

function Get-CommandPathLocal {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

$PathCmd = Get-CommandPathLocal -Name "codex"
if (-not $PathCmd) {
    $PathCmd = Get-CommandPathLocal -Name "codex.exe"
}

$UserProfilePath = Join-Path $env:USERPROFILE ".codex"
$AppLocalPath = Join-Path $env:LOCALAPPDATA "Programs\codex\codex.exe"

$ResolvedPath = ""
if ($PathCmd) {
    $ResolvedPath = $PathCmd
} elseif (Test-Path $AppLocalPath) {
    $ResolvedPath = $AppLocalPath
}

if ($ResolvedPath) {
    $Detected = $true
    $InstallPath = Split-Path $ResolvedPath
    $Executable = Split-Path $ResolvedPath -Leaf
    
    $Timeout = if ($Config.externalCommandTimeoutMs) { $Config.externalCommandTimeoutMs } else { 3000 }
    $Version = & $GetVersionScript -ExecutablePath $ResolvedPath -TimeoutMs $Timeout
    
    $procs = Get-Process -Name "codex" -ErrorAction SilentlyContinue
    if ($procs) {
        $Running = $true
        $Notes = "Processo ativo."
    } else {
        $Notes = "Executável encontrado."
    }
}
elseif (Test-Path $UserProfilePath) {
    $Detected = $true
    $InstallPath = $UserProfilePath
    $Notes = "Pasta .codex encontrada no perfil do usuário."
}
else {
    $Notes = "Codex não localizado."
}

return [PSCustomObject]@{
    name            = $Name
    category        = $Category
    detected        = $Detected
    running         = $Running
    version         = $Version
    executable      = $Executable
    installPath     = $InstallPath
    detectionMethod = $DetectionMethod
    notes           = $Notes.Trim()
    scannedAt       = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}
