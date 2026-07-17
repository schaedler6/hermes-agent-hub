param($Config)

$Name = "Docker"
$Category = "Development Environment"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "docker"
$InstallPath = ""
$DetectionMethod = "PATH & Process Check"
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

$PathCmd = Get-CommandPathLocal -Name "docker"
if (-not $PathCmd) {
    $PathCmd = Get-CommandPathLocal -Name "docker.exe"
}

$ProcessoAtivo = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue

if ($PathCmd) {
    $Detected = $true
    $InstallPath = Split-Path $PathCmd
    $Executable = Split-Path $PathCmd -Leaf
    
    $Timeout = if ($Config.externalCommandTimeoutMs) { $Config.externalCommandTimeoutMs } else { 3000 }
    $Version = & $GetVersionScript -ExecutablePath $PathCmd -TimeoutMs $Timeout
    if ($Version) {
        $Version = $Version.TrimEnd(',').Trim()
    }
    
    if ($ProcessoAtivo) {
        $Running = $true
        $Notes = "Docker CLI encontrado e Docker Desktop em execução."
    } else {
        $Notes = "Docker CLI encontrado. Docker Desktop inativo."
    }
}
elseif ($ProcessoAtivo) {
    $Detected = $true
    $Running = $true
    $Notes = "Processo 'Docker Desktop' em execução na memória, porém o executável 'docker' CLI não foi localizado."
}
else {
    $Notes = "Docker não localizado."
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
