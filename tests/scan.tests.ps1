# ==========================================
# scan.tests.ps1 — Suíte de Testes
# ==========================================

$TestRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($TestRoot)) {
    $TestRoot = Get-Location
}
$ProjectRoot = Split-Path $TestRoot -Parent
$ScannerDir = Join-Path $ProjectRoot "scanner"
$DetectorsDir = Join-Path $ScannerDir "detectors"

# Função de Assert Simples
function Assert-True {
    param([bool]$Condition, [string]$Msg)
    if (-not $Condition) {
        Write-Host "  ✘ FALHA: $Msg" -ForegroundColor Red
        $global:TestFailures++
    } else {
        Write-Host "  ✔ OK: $Msg" -ForegroundColor Green
        $global:TestSuccesses++
    }
}

Write-Host "Iniciando Testes Unitários do Discovery Scanner..." -ForegroundColor Cyan
$global:TestFailures = 0
$global:TestSuccesses = 0

# Teste 1: Existência dos Arquivos do Projeto
Write-Host "`n[Teste 1] Validando estrutura de arquivos..." -ForegroundColor Yellow
Assert-True (Test-Path (Join-Path $ScannerDir "scan.ps1")) "scan.ps1 existe em scanner/"
Assert-True (Test-Path (Join-Path $ProjectRoot "config.json")) "config.json existe na raiz"
Assert-True (Test-Path (Join-Path $DetectorsDir "Helper-Functions.ps1")) "Helper-Functions.ps1 existe"
Assert-True (Test-Path (Join-Path $DetectorsDir "Detect-HermesAgent.ps1")) "Detect-HermesAgent.ps1 existe"
Assert-True (Test-Path (Join-Path $DetectorsDir "Detect-Ollama.ps1")) "Detect-Ollama.ps1 existe"

# Teste 2: Parsing e Importação do Helper-Functions
Write-Host "`n[Teste 2] Validando Helper-Functions..." -ForegroundColor Yellow
try {
    . (Join-Path $DetectorsDir "Helper-Functions.ps1")
    Assert-True ($null -ne (Get-Command "Get-CommandPath" -ErrorAction SilentlyContinue)) "Get-CommandPath carregado"
    Assert-True ($null -ne (Get-Command "Invoke-WithTimeout" -ErrorAction SilentlyContinue)) "Invoke-WithTimeout carregado"
    Assert-True ($null -ne (Get-Command "Get-VersionSafe" -ErrorAction SilentlyContinue)) "Get-VersionSafe carregado"
} catch {
    Assert-True $false "Erro ao carregar Helper-Functions: $_"
}

# Teste 3: Comportamento de Timeout do Helper
Write-Host "`n[Teste 3] Validando comportamento de Timeout..." -ForegroundColor Yellow
$res = Invoke-WithTimeout -FilePath "cmd.exe" -ArgumentList "/c ping 127.0.0.1 -n 3" -TimeoutMs 500
Assert-True ($res.TimedOut -eq $true) "Função detecta timeout corretamente"

# Teste 4: Executando os detectores individuais em isolamento (Mock Config)
Write-Host "`n[Teste 4] Executando detectores com Configuração Mock..." -ForegroundColor Yellow
$MockConfig = [PSCustomObject]@{
    customSearchPaths = @()
    externalCommandTimeoutMs = 1000
    exclucoes = @()
}

$Detectors = Get-ChildItem $DetectorsDir -Filter "Detect-*.ps1" -File
foreach ($det in $Detectors) {
    try {
        $resObj = & $det.FullName -Config $MockConfig
        Assert-True ($null -ne $resObj) "Detector $($det.BaseName) executado sem erros"
        Assert-True ($resObj.nome -ne $null) "Detector $($det.BaseName) retornou campo 'nome'"
        Assert-True ($resObj.status -match 'Encontrado|Não Encontrado') "Detector $($det.BaseName) retornou status válido"
        Assert-True ($resObj.data_verificacao -ne $null) "Detector $($det.BaseName) retornou data_verificacao"
    } catch {
        Assert-True $false "Erro crítico no detector $($det.BaseName): $_"
    }
}

# Resumo Final dos Testes
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Resumo dos Testes:" -ForegroundColor Cyan
Write-Host "Sucessos: $global:TestSuccesses" -ForegroundColor Green

$color = if ($global:TestFailures -gt 0) { "Red" } else { "Green" }
Write-Host "Falhas: $global:TestFailures" -ForegroundColor $color
Write-Host "==========================================" -ForegroundColor Cyan

if ($global:TestFailures -gt 0) {
    exit 1
} else {
    exit 0
}
