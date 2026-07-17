param($Config)

$Name = "LM Studio"
$Category = "Inference Engine"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "LM Studio.exe"
$InstallPath = ""
$DetectionMethod = "AppData & Process Check"
$Notes = ""

$LocalLMStudio = Join-Path $env:LOCALAPPDATA "Programs\lm-studio\LM Studio.exe"
$ProcessoAtivo = Get-Process -Name "LM Studio" -ErrorAction SilentlyContinue

$ResolvedPath = ""
if (Test-Path $LocalLMStudio) {
    $ResolvedPath = $LocalLMStudio
}

if ($ResolvedPath) {
    $Detected = $true
    $InstallPath = Split-Path $ResolvedPath
    $Executable = Split-Path $ResolvedPath -Leaf
    
    $PackageJson = Join-Path $InstallPath "resources\app\package.json"
    if (Test-Path $PackageJson) {
        $content = Get-Content $PackageJson -Raw -ErrorAction SilentlyContinue
        if ($content -match '"version"\s*:\s*"(.*?)"') {
            $Version = $Matches[1]
        }
    }
    
    if ($ProcessoAtivo) {
        $Running = $true
        $Notes = "LM Studio está em execução."
    } else {
        $Notes = "Instalado no sistema, mas processo inativo no momento."
    }
}
elseif ($ProcessoAtivo) {
    $Detected = $true
    $Running = $true
    $Notes = "Processo 'LM Studio' ativo na memória, porém o executável físico não foi localizado."
}
else {
    $Notes = "LM Studio não localizado no sistema."
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
