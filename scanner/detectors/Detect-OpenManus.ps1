param($Config)

$Name = "OpenManus"
$Category = "Open Source Framework"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "python main.py"
$InstallPath = ""
$DetectionMethod = "Caminhos Conhecidos"
$Notes = ""

$CaminhosVerificar = @(
    (Join-Path $env:USERPROFILE "OpenManus"),
    "C:\OpenManus",
    "C:\Users\SCHAE\Projects\Personal\OpenManus"
)

if ($Config.customSearchPaths) {
    foreach ($path in $Config.customSearchPaths) {
        $CaminhosVerificar += Join-Path $path "OpenManus"
        $CaminhosVerificar += $path
    }
}

foreach ($c in $CaminhosVerificar) {
    if (Test-Path $c) {
        $MainPy = Join-Path $c "main.py"
        $ConfigToml = Join-Path $c "config\config.toml"
        if ((Test-Path $MainPy) -or (Test-Path $ConfigToml)) {
            $Detected = $true
            $InstallPath = $c
            $Notes = "Encontrado em: $c. Arquivos principais de entrada localizados."
            
            $Pyproject = Join-Path $c "pyproject.toml"
            if (Test-Path $Pyproject) {
                $content = Get-Content $Pyproject -Raw -ErrorAction SilentlyContinue
                if ($content -match 'version\s*=\s*"(.*?)"') {
                    $Version = $Matches[1]
                }
            }
            
            $procs = Get-Process -Name "python" -ErrorAction SilentlyContinue
            # Simplificação: assume running=false a menos que o script main.py esteja ativamente rodando
            # e possamos validar a linha de comando sem elevação (o que é inseguro), então mantemos falso por padrão.
            break
        }
    }
}

if (-not $Detected) {
    $Notes = "OpenManus não localizado."
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
