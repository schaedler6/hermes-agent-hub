param($Config)

$Name = "Claude Code"
$Category = "CLI Assistant"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "claude"
$InstallPath = ""
$DetectionMethod = "PATH & NPM Global Check"
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

$PathCmd = Get-CommandPathLocal -Name "claude"
if (-not $PathCmd) {
    $PathCmd = Get-CommandPathLocal -Name "claude.cmd"
}

$NpmGlobalPath = Join-Path $env:APPDATA "npm\claude.cmd"
$NpmGlobalExists = Test-Path $NpmGlobalPath

$ResolvedPath = ""
if ($PathCmd) {
    $ResolvedPath = $PathCmd
} elseif ($NpmGlobalExists) {
    $ResolvedPath = $NpmGlobalPath
}

if ($ResolvedPath) {
    $Detected = $true
    $InstallPath = Split-Path $ResolvedPath
    $Executable = Split-Path $ResolvedPath -Leaf
    
    # Obtém a versão com o timeout configurado
    $Timeout = if ($Config.externalCommandTimeoutMs) { $Config.externalCommandTimeoutMs } else { 3000 }
    $Version = & $GetVersionScript -ExecutablePath $ResolvedPath -TimeoutMs $Timeout
    
    # Verifica se há processo ativo
    $procs = Get-Process -Name "claude" -ErrorAction SilentlyContinue
    if ($procs) {
        $Running = $true
        $Notes = "Executável em uso ativo no console."
    } else {
        $Notes = "Disponível globalmente para execução via CLI."
    }
} else {
    $Notes = "Claude Code não está instalado ou disponível no PATH."
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
