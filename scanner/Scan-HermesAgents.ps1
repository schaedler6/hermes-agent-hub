# ==========================================
# Scan-HermesAgents.ps1
# Orquestrador do Scanner de Agentes
# ==========================================

$ScannerRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScannerRoot)) {
    $ScannerRoot = Get-Location
}
$ProjectRoot = Split-Path $ScannerRoot -Parent

# Garante UTF-8 no console do PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ConfigPath = Join-Path $ProjectRoot "config.json"
$DetectorsDir = Join-Path $ScannerRoot "detectors"
$DataDir = Join-Path $ProjectRoot "data"
$LogsDir = Join-Path $ProjectRoot "logs"
$DashboardDir = Join-Path $ProjectRoot "dashboard"

# Cria os diretórios necessários se não existirem
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
New-Item -ItemType Directory -Force -Path $DashboardDir | Out-Null

# Inicializa o arquivo de log para esta execução
$StartTime = [DateTime]::UtcNow
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path $LogsDir "scan-$Timestamp.log"

# Função auxiliar para gravar logs
function Write-ScanLog {
    param([string]$Mensagem, [string]$Tipo = "INFO")
    $LogTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Linha = "[$LogTime] [$Tipo] $Mensagem"
    Write-Host $Linha
    $Linha | Out-File -FilePath $LogFile -Append -Encoding utf8
}

Write-ScanLog "Iniciando Varredura do Hermes Agent Hub"
Write-ScanLog "Pasta Raiz do Projeto: $ProjectRoot"

# 1. Carrega as Configurações
if (Test-Path $ConfigPath) {
    try {
        $jsonContent = Get-Content $ConfigPath -Raw -Encoding utf8
        $Config = ConvertFrom-Json $jsonContent
        Write-ScanLog "Configurações carregadas com sucesso de config.json."
    } catch {
        Write-ScanLog "Erro ao analisar config.json. Usando padrões. Detalhe: $_" "ERROR"
        $Config = [PSCustomObject]@{
            customSearchPaths = @()
            externalCommandTimeoutMs = 3000
            exclucoes = @("node_modules", "Temp")
        }
    }
} else {
    Write-ScanLog "Arquivo config.json não encontrado. Usando configurações padrões." "WARN"
    $Config = [PSCustomObject]@{
        customSearchPaths = @()
        externalCommandTimeoutMs = 3000
        exclucoes = @("node_modules", "Temp")
    }
}

# 2. Executa os Detectores
$Resultados = @()
$Detectors = Get-ChildItem $DetectorsDir -Filter "Detect-*.ps1" -File

Write-ScanLog "Total de detectores modulares localizados: $($Detectors.Count)"

foreach ($det in $Detectors) {
    Write-ScanLog "Executando detector: $($det.Name) ..."
    try {
        $res = & $det.FullName -Config $Config
        if ($res) {
            $Resultados += $res
            $LogStatus = if ($res.detected) { "ENCONTRADO" } else { "INFO" }
            Write-ScanLog "Agente: $($res.name) | Detectado: $($res.detected) | Em Execução: $($res.running) | Versão: $($res.version)" $LogStatus
        } else {
            Write-ScanLog "Detector $($det.Name) retornou resposta nula." "WARN"
        }
    } catch {
        Write-ScanLog "Falha ao rodar detector $($det.Name): $_" "ERROR"
    }
}

# 3. Estatísticas de Resumo
$DetectedCount = ($Resultados | Where-Object { $_.detected -eq $true }).Count
$RunningCount = ($Resultados | Where-Object { $_.running -eq $true }).Count
$NotFoundCount = ($Resultados | Where-Object { $_.detected -eq $false }).Count

# Alertas simples: se houver alguma ferramenta conhecida não instalada, ou ferramentas rodando que possam consumir recursos
$AlertsCount = 0
$AlertsList = @()
if ($NotFoundCount -gt 5) {
    $AlertsCount++
    $AlertsList += "Muitas ferramentas de IA configuradas não foram encontradas localmente."
}
if ($RunningCount -gt 2) {
    $AlertsCount++
    $AlertsList += "Vários runtimes de IA locais estão rodando simultaneamente (consumo de CPU/GPU elevado)."
}

# 4. Geração de data/agents.json
Write-ScanLog "Escrevendo data/agents.json..."
$JsonPath = Join-Path $DataDir "agents.json"
$JsonContent = ConvertTo-Json -InputObject $Resultados -Depth 5
$JsonContent | Set-Content -Path $JsonPath -Encoding utf8
Write-ScanLog "Arquivo data/agents.json gravado com sucesso."

# 5. Geração de dashboard/data.js
Write-ScanLog "Escrevendo dashboard/data.js..."
$JsDataPath = Join-Path $DashboardDir "data.js"

# Lê o log gerado até o momento com compartilhamento de leitura
$logContent = ""
if (Test-Path $LogFile) {
    try {
        $stream = [System.IO.FileStream]::new($LogFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
        $logContent = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()
    } catch {
        $logContent = "Não foi possível carregar os logs em tempo real."
    }
}

$PayloadJs = [PSCustomObject]@{
    scannedAt = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    agents = $Resultados
    latestLog = $logContent
    summary = [PSCustomObject]@{
        detectedCount = $DetectedCount
        runningCount = $RunningCount
        notFoundCount = $NotFoundCount
        alertsCount = $AlertsCount
        alerts = $AlertsList
    }
}
$JsContent = "window.HERMES_DATA = " + (ConvertTo-Json -InputObject $PayloadJs -Depth 5) + ";"
$JsContent | Set-Content -Path $JsDataPath -Encoding utf8
Write-ScanLog "Arquivo dashboard/data.js gravado com sucesso."

# 6. Geração de data/agents.md
Write-ScanLog "Escrevendo data/agents.md..."
$MdPath = Join-Path $DataDir "agents.md"

$Md = @()
$Md += "# Hermes Agent Inventory"
$Md += ""
$Md += "- **Data e Hora da Varredura:** $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
$Md += "- **Total de Ferramentas Detectadas:** $DetectedCount"
$Md += "- **Total de Ferramentas em Execução:** $RunningCount"
$Md += "- **Total de Ferramentas Não Encontradas:** $NotFoundCount"
$Md += ""
$Md += "## Resumo dos Agentes"
$Md += ""
$Md += "| Nome | Categoria | Status | Em Execução | Versão | Método de Detecção |"
$Md += "| :--- | :--- | :--- | :--- | :--- | :--- |"

foreach ($res in $Resultados) {
    $statusEmoji = if ($res.detected) { "🟢 Instalado" } else { "🔴 Não Encontrado" }
    $runningEmoji = if ($res.running) { "⚡ Sim" } else { "💤 Não" }
    $Md += "| **$($res.name)** | $($res.category) | $statusEmoji | $runningEmoji | $($res.version) | $($res.detectionMethod) |"
}

$Md += ""
$Md += "## Caminhos Encontrados e Detalhes"
$Md += ""
foreach ($res in $Resultados) {
    if ($res.detected) {
        $Md += "### 🤖 $($res.name)"
        $Md += "- **Caminho:** $($res.installPath)"
        $Md += "- **Executável:** $($res.executable)"
        $Md += "- **Notas:** $($res.notes)"
        $Md += ""
    }
}

$Md += "## Alertas e Observações"
$Md += ""
if ($AlertsList.Count -eq 0) {
    $Md += "✔ Nenhum alerta crítico detectado no laboratório."
} else {
    foreach ($al in $AlertsList) {
        $Md += "⚠ $al"
    }
}

$Md | Set-Content -Path $MdPath -Encoding utf8
Write-ScanLog "Arquivo data/agents.md gravado com sucesso."

# 7. Finaliza o Log
$EndTime = [DateTime]::UtcNow
$Duration = $EndTime - $StartTime
Write-ScanLog "Varredura concluída em $($Duration.TotalSeconds.ToString('F2')) segundos."
Write-ScanLog "Status Final: Sucesso. Arquivos gerados nas pastas data/ e dashboard/."
