# ==========================================
# scan.ps1 — Agent Scanner Plugin Entrypoint
# ==========================================

# Carrega o parâmetro opcional Config passado pelo Runner
param(
    $Config = $null
)

$PluginDir = $PSScriptRoot
$ProjectRoot = Split-Path (Split-Path $PluginDir -Parent) -Parent
$ScannerRoot = Join-Path $ProjectRoot "scanner"
$DetectorsDir = Join-Path $ScannerRoot "detectors"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Se não foi passado config, tenta carregar do config.json
if ($null -eq $Config) {
    $ConfigPath = Join-Path $ProjectRoot "config.json"
    if (Test-Path $ConfigPath) {
        $Config = Get-Content $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
    }
}

$Resultados = @()
$ErrosList = @()

if (-not (Test-Path $DetectorsDir)) {
    return [PSCustomObject]@{
        pluginId   = "agent-scanner"
        category   = "agents"
        scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
        status     = "error"
        items      = @()
        warnings   = @()
        errors     = @("Diretório de detectores de agentes não localizado: $DetectorsDir")
    }
}

$Detectors = Get-ChildItem $DetectorsDir -Filter "Detect-*.ps1" -File

foreach ($det in $Detectors) {
    try {
        # Executa o detector modular com o config passado
        $res = & $det.FullName -Config $Config
        if ($res) {
            $Resultados += $res
        }
    } catch {
        $ErrosList += "Falha ao rodar detector $($det.Name): $_"
    }
}

# Estatísticas de Resumo e Alertas
$DetectedCount = ($Resultados | Where-Object { $_.detected -eq $true }).Count
$RunningCount = ($Resultados | Where-Object { $_.running -eq $true }).Count
$NotFoundCount = ($Resultados | Where-Object { $_.detected -eq $false }).Count

$AlertsList = @()
if ($NotFoundCount -gt 5) {
    $AlertsList += "Muitas ferramentas de IA configuradas não foram encontradas localmente."
}
if ($RunningCount -gt 2) {
    $AlertsList += "Vários runtimes de IA locais estão rodando simultaneamente (consumo de CPU/GPU elevado)."
}

# Retorna o objeto de contrato oficial do Hermes
return [PSCustomObject]@{
    pluginId   = "agent-scanner"
    category   = "agents"
    scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    status     = if ($ErrosList.Count -gt 0) { "warning" } else { "success" }
    items      = $Resultados
    warnings   = $AlertsList
    errors     = $ErrosList
}
