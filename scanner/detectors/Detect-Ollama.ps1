param($Config)

$Name = "Ollama"
$Category = "Inference Engine"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "ollama.exe"
$InstallPath = ""
$DetectionMethod = "Registry & PATH Check"
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

$PathCmd = Get-CommandPathLocal -Name "ollama"
if (-not $PathCmd) {
    $PathCmd = Get-CommandPathLocal -Name "ollama.exe"
}

$LocalOllama = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"
$SystemOllama = "C:\Program Files\Ollama\ollama.exe"

$ResolvedPath = ""
if ($PathCmd) {
    $ResolvedPath = $PathCmd
} elseif (Test-Path $LocalOllama) {
    $ResolvedPath = $LocalOllama
} elseif (Test-Path $SystemOllama) {
    $ResolvedPath = $SystemOllama
}

$ProcessoAtivo = Get-Process -Name "ollama" -ErrorAction SilentlyContinue

if ($ResolvedPath) {
    $Detected = $true
    $InstallPath = Split-Path $ResolvedPath
    $Executable = Split-Path $ResolvedPath -Leaf
    
    $Timeout = if ($Config.externalCommandTimeoutMs) { $Config.externalCommandTimeoutMs } else { 3000 }
    $Version = & $GetVersionScript -ExecutablePath $ResolvedPath -TimeoutMs $Timeout
    
    if ($ProcessoAtivo) {
        $Running = $true
        $Notes = "Serviço ativo e rodando no background."
    } else {
        $Notes = "Instalado no sistema, mas processo inativo no momento."
    }
}
elseif ($ProcessoAtivo) {
    $Detected = $true
    $Running = $true
    $Notes = "Processo 'ollama' ativo na memória, porém o executável físico não foi localizado."
}
else {
    $Notes = "Ollama não localizado."
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
