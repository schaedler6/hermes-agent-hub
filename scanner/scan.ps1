# ==========================================
# 🔍 Hermes Agent Hub - Discovery Scanner
# ==========================================
# Fase 1: Discovery Scanner
# PowerShell 7+
# ==========================================

$ScannerRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScannerRoot)) {
    $ScannerRoot = Get-Location
}
$ProjectRoot = Split-Path $ScannerRoot -Parent

$ConfigPath = Join-Path $ProjectRoot "config.json"
$DetectorsDir = Join-Path $ScannerRoot "detectors"
$OutputDir = Join-Path $ProjectRoot "output"
$LogsDir = Join-Path $ProjectRoot "logs"

# Cria os diretórios básicos do Scanner se não existirem
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

# Inicializa o Arquivo de Log
$DataLog = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path $LogsDir "scan-$DataLog.log"

# Define arquivo geral scan.log (acumulado)
$GeneralLogFile = Join-Path $LogsDir "scan.log"

function Write-Log {
    param([string]$Mensagem, [string]$Tipo = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Linha = "[$Timestamp] [$Tipo] $Mensagem"
    Write-Host $Linha
    
    $Linha | Out-File -FilePath $LogFile -Append -Encoding utf8
    $Linha | Out-File -FilePath $GeneralLogFile -Append -Encoding utf8
}

Write-Log "Iniciando Hermes Agent Hub - Discovery Scanner"
Write-Log "Diretório de Varredura: $ScannerRoot"
Write-Log "Diretório do Projeto: $ProjectRoot"

# 1. Carrega as Configurações
if (-not (Test-Path $ConfigPath)) {
    Write-Log "Arquivo de configuração config.json não encontrado na raiz! Usando defaults." "WARN"
    $Config = [PSCustomObject]@{
        customSearchPaths = @()
        externalCommandTimeoutMs = 2000
        exclucoes = @("node_modules", "Temp", "cache")
    }
} else {
    try {
        $json = Get-Content $ConfigPath -Raw -Encoding utf8
        $Config = ConvertFrom-Json $json
        Write-Log "Configurações carregadas com sucesso."
    } catch {
        Write-Log "Erro ao processar config.json! Usando defaults. Detalhe: $_" "ERROR"
        $Config = [PSCustomObject]@{
            customSearchPaths = @()
            externalCommandTimeoutMs = 2000
            exclucoes = @("node_modules", "Temp", "cache")
        }
    }
}

# 2. Carrega as Funções Auxiliares
$HelperPath = Join-Path $DetectorsDir "Helper-Functions.ps1"
if (-not (Test-Path $HelperPath)) {
    Write-Log "Erro Crítico: Helper-Functions.ps1 não localizado em $DetectorsDir!" "ERROR"
    exit 1
}
. $HelperPath
Write-Log "Funções auxiliares importadas com sucesso."

# 3. Executa os Detectores Modulares
$Resultados = @()

$Detectors = Get-ChildItem $DetectorsDir -Filter "Detect-*.ps1" -File
Write-Log "Localizados $($Detectors.Count) detectores modulares."

foreach ($detectorFile in $Detectors) {
    $NomeDetector = $detectorFile.BaseName
    Write-Log "Executando detector: $NomeDetector ..."
    
    try {
        $res = & $detectorFile.FullName -Config $Config
        if ($res) {
            $Resultados += $res
            $StatusLog = if ($res.status -eq "Encontrado") { "ENCONTRADO" } else { "INFO" }
            Write-Log "Agente: $($res.nome) | Status: $($res.status) | Versão: $($res.versao)" $StatusLog
        } else {
            Write-Log "Detector $NomeDetector não retornou nenhum objeto válido." "WARN"
        }
    } catch {
        Write-Log "Falha ao executar detector $NomeDetector: $_" "ERROR"
    }
}

# 4. Grava Saída JSON
Write-Log "Escrevendo relatório em formato JSON..."
$JsonPath = Join-Path $OutputDir "agents.json"
$ResultadosJson = ConvertTo-Json -InputObject $Resultados -Depth 5
$ResultadosJson | Set-Content -Path $JsonPath -Encoding utf8
Write-Log "Relatório JSON gravado com sucesso em: $JsonPath"

# Se a pasta do Dashboard existir e tiver pasta public, copia o JSON para lá para o React ler
$DashboardPublic = Join-Path $ProjectRoot "dashboard\public"
if (Test-Path $DashboardPublic) {
    $DashboardJsonPath = Join-Path $DashboardPublic "agents.json"
    $ResultadosJson | Set-Content -Path $DashboardJsonPath -Encoding utf8
    Write-Log "Cópia do relatório JSON gravada em: $DashboardJsonPath"
}

# 5. Grava Saída Markdown
Write-Log "Escrevendo relatório em formato Markdown..."
$MdPath = Join-Path $OutputDir "agents.md"

$MdConteudo = @()
$MdConteudo += "# Hermes Agent Hub — Relatório do Discovery Scanner"
$MdConteudo += ""
$MdConteudo += "Relatório gerado automaticamente para listar os agentes de IA, ambientes de execução e servidores de contexto instalados nesta máquina."
$MdConteudo += ""
$MdConteudo += "**Data de Execução:** $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
$MdConteudo += "**Mecanismo de Escaneamento:** PowerShell 7+ Discovery Module"
$MdConteudo += ""
$MdConteudo += "## 📊 Resumo das Detecções"
$MdConteudo += ""
$MdConteudo += "| Nome do Agente | Categoria | Status | Versão | Método de Detecção |"
$MdConteudo += "| :--- | :--- | :--- | :--- | :--- |"

foreach ($res in $Resultados) {
    $statusEmoji = if ($res.status -eq "Encontrado") { "🟢 Encontrado" } else { "🔴 Não Encontrado" }
    $MdConteudo += "| **$($res.nome)** | $($res.categoria) | $statusEmoji | $($res.versao) | $($res.metodo_deteccao) |"
}

$MdConteudo += ""
$MdConteudo += "---"
$MdConteudo += ""
$MdConteudo += "## 🔍 Detalhes Individuais"
$MdConteudo += ""

foreach ($res in $Resultados) {
    $MdConteudo += "### 🤖 $($res.nome)"
    $MdConteudo += ""
    $MdConteudo += "- **Categoria:** $($res.categoria)"
    $MdConteudo += "- **Status:** $($res.status)"
    $MdConteudo += "- **Versão:** $($res.versao)"
    $MdConteudo += "- **Caminho:** $($res.caminho)"
    $MdConteudo += "- **Executável:** $($res.executavel)"
    $MdConteudo += "- **Método de Detecção:** $($res.metodo_deteccao)"
    $MdConteudo += "- **Data da Verificação:** $($res.data_verificacao)"
    $MdConteudo += "- **Observações:** $($res.observacoes)"
    $MdConteudo += ""
    $MdConteudo += "---"
    $MdConteudo += ""
}

$MdConteudo | Set-Content -Path $MdPath -Encoding utf8
Write-Log "Relatório Markdown gravado com sucesso em: $MdPath"

# Copia também para o public do dashboard para download se desejado
if (Test-Path $DashboardPublic) {
    $DashboardMdPath = Join-Path $DashboardPublic "agents.md"
    $MdConteudo | Set-Content -Path $DashboardMdPath -Encoding utf8
    Write-Log "Cópia do relatório Markdown gravada em: $DashboardMdPath"
}

# Copia o log de varredura acumulado também
if (Test-Path $DashboardPublic) {
    $DashboardLogPath = Join-Path $DashboardPublic "scan.log"
    Copy-Item -Path $GeneralLogFile -Destination $DashboardLogPath -Force -ErrorAction SilentlyContinue
}

Write-Log "Hermes Agent Hub - Discovery Scanner concluído com sucesso!"
