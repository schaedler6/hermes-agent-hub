# ==========================================
# Start-HermesHub.ps1
# Script Inicializador Principal
# ==========================================
# PowerShell 7+
# ==========================================

$ProjectRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Get-Location
}

# Garante UTF-8 no console do PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ConfigPath = Join-Path $ProjectRoot "config.local.json"
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $ProjectRoot "config.json"
}
$PluginManagerScript = Join-Path $ProjectRoot "core\PluginManager.ps1"
$DashboardHtml = Join-Path $ProjectRoot "dashboard\index.html"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🚀 INICIANDO HERMES AGENT HUB v0.3.0-rc.1" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Executa o orquestrador de plugins do Core
if (Test-Path $PluginManagerScript) {
    Write-Host "🔍 Executando varredura central via plugins..." -ForegroundColor Yellow
    . $PluginManagerScript
    $Result = Invoke-HermesPluginManager -ConfigPath $ConfigPath
    
    if ($null -eq $Result) {
        Write-Host "✘ Erro Crítico: O Plugin Manager falhou ao executar." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✔ Varredura de plugins concluída com sucesso!" -ForegroundColor Green
    }
} else {
    Write-Host "✘ Erro Crítico: Script do Plugin Manager não localizado em $PluginManagerScript." -ForegroundColor Red
    exit 1
}

# 2. Abre o Dashboard no navegador padrão
if (Test-Path $DashboardHtml) {
    Write-Host "`n🌐 Abrindo o Dashboard no navegador padrão..." -ForegroundColor Yellow
    # Abre o arquivo HTML local diretamente
    Start-Process $DashboardHtml
    Write-Host "✔ Dashboard iniciado com sucesso!" -ForegroundColor Green
} else {
    Write-Host "✘ Erro Crítico: Arquivo do dashboard não localizado em $DashboardHtml." -ForegroundColor Red
    exit 1
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Hermes Hub ativo. O terminal pode ser fechado." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
