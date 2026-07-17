param($Config)

$Name = "Gemini CLI"
$Category = "CLI Assistant"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "gemini"
$InstallPath = ""
$DetectionMethod = "PATH & NPM Check"
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

$PathCmd = Get-CommandPathLocal -Name "gemini"
if (-not $PathCmd) {
    $PathCmd = Get-CommandPathLocal -Name "gemini-cli"
}

$NpmGlobalPath1 = Join-Path $env:APPDATA "npm\gemini.cmd"
$NpmGlobalPath2 = Join-Path $env:APPDATA "npm\gemini-cli.cmd"

$ResolvedPath = ""
if ($PathCmd) {
    $ResolvedPath = $PathCmd
} elseif (Test-Path $NpmGlobalPath1) {
    $ResolvedPath = $NpmGlobalPath1
} elseif (Test-Path $NpmGlobalPath2) {
    $ResolvedPath = $NpmGlobalPath2
}

if ($ResolvedPath) {
    $Detected = $true
    $InstallPath = Split-Path $ResolvedPath
    $Executable = Split-Path $ResolvedPath -Leaf
    
    $Timeout = if ($Config.externalCommandTimeoutMs) { $Config.externalCommandTimeoutMs } else { 3000 }
    $Version = & $GetVersionScript -ExecutablePath $ResolvedPath -TimeoutMs $Timeout
    
    $procs = Get-Process -Name "gemini" -ErrorAction SilentlyContinue
    if (-not $procs) {
        $procs = Get-Process -Name "gemini-cli" -ErrorAction SilentlyContinue
    }
    
    if ($procs) {
        $Running = $true
        $Notes = "Processo de execução de comando ativo."
    } else {
        $Notes = "Ferramenta instalada para uso via console."
    }
} else {
    $Notes = "Gemini CLI não localizado no sistema."
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
