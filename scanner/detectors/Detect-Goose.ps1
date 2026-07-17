param($Config)

$Name = "Goose"
$Category = "CLI Assistant"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "goose"
$InstallPath = ""
$DetectionMethod = "PATH & AppData Check"
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

$PathCmd = Get-CommandPathLocal -Name "goose"
if (-not $PathCmd) {
    $PathCmd = Get-CommandPathLocal -Name "goose.exe"
}

$LocalCargoBin = Join-Path $env:USERPROFILE ".cargo\bin\goose.exe"
$LocalGooseApp = Join-Path $env:LOCALAPPDATA "Programs\goose\goose.exe"

$ResolvedPath = ""
if ($PathCmd) {
    $ResolvedPath = $PathCmd
} elseif (Test-Path $LocalGooseApp) {
    $ResolvedPath = $LocalGooseApp
} elseif (Test-Path $LocalCargoBin) {
    $ResolvedPath = $LocalCargoBin
}

if ($ResolvedPath) {
    $Detected = $true
    $InstallPath = Split-Path $ResolvedPath
    $Executable = Split-Path $ResolvedPath -Leaf
    
    $Timeout = if ($Config.externalCommandTimeoutMs) { $Config.externalCommandTimeoutMs } else { 3000 }
    $Version = & $GetVersionScript -ExecutablePath $ResolvedPath -TimeoutMs $Timeout
    
    $procs = Get-Process -Name "goose" -ErrorAction SilentlyContinue
    if ($procs) {
        $Running = $true
        $Notes = "Processo ativo."
    } else {
        $Notes = "Goose CLI encontrado."
    }
} else {
    $Notes = "Goose não localizado."
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
