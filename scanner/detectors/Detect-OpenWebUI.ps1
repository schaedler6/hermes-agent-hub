param($Config)

$Name = "Open WebUI"
$Category = "UI Interface"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "N/A"
$InstallPath = ""
$DetectionMethod = "Process & Docker & Path Check"
$Notes = ""

# Procura se há processos com nome 'open-webui' ou processos do python associados ao Open WebUI
$procs = Get-Process -Name "*open-webui*" -ErrorAction SilentlyContinue
if (-not $procs) {
    # Verifica processos python que possam estar rodando o open-webui
    $pyProcs = Get-Process -Name "python" -ErrorAction SilentlyContinue
    if ($pyProcs) {
        # Como obter a CommandLine sem privilégios administrativos elevados às vezes falha,
        # fazemos verificação de portas locais de escuta (3000, 8080) caso tenhamos netstat ou similar,
        # ou se o usuário configurou
    }
}

# Verifica se o Docker está instalado e se o contêiner do Open WebUI está ativo
# Sem fazer chamadas bloqueantes lentas
$dockerPath = Get-Command -Name "docker" -ErrorAction SilentlyContinue
if ($dockerPath) {
    # Executa de forma segura com timeout rápido (2s)
    $GetVersionScript = Join-Path $PSScriptRoot "../Get-AgentVersion.ps1"
    $res = & $GetVersionScript -ExecutablePath "docker" -ArgsList "ps -a --filter name=open-webui --format '{{.Status}}'" -TimeoutMs 2000
    if ($res -ne "desconhecida" -and -not [string]::IsNullOrWhiteSpace($res)) {
        $Detected = $true
        $InstallPath = "Docker Container"
        $Notes += "Contêiner Docker 'open-webui' detectado. Status: $res. "
        if ($res -match "Up") {
            $Running = $true
        }
    }
}

# Verifica pastas conhecidas
$CommonPath = Join-Path $env:USERPROFILE ".open-webui"
if (Test-Path $CommonPath) {
    $Detected = $true
    if ([string]::IsNullOrWhiteSpace($InstallPath)) {
        $InstallPath = $CommonPath
    }
    $Notes += "Pasta de dados local .open-webui encontrada. "
}

if ($procs) {
    $Detected = $true
    $Running = $true
    $Notes += "Processo ativo em execução local."
}

if (-not $Detected) {
    $Notes = "Open WebUI não localizado nos caminhos padrão."
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
