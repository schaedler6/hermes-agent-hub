# ==========================================
# run-tests.ps1 — Orquestrador de Testes
# ==========================================

$PSScriptRootLocal = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($PSScriptRootLocal)) {
    $PSScriptRootLocal = Get-Location
}

$TestScript = Join-Path $PSScriptRootLocal "scan.tests.ps1"

Write-Host "Executando suíte de testes do Hermes Discovery Scanner..." -ForegroundColor Cyan
Write-Host "Arquivo de teste: $TestScript"

& $TestScript
$ExitCodeLocal = $LASTEXITCODE

if ($ExitCodeLocal -eq 0) {
    Write-Host "✔ TODOS OS TESTES PASSARAM COM SUCESSO!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✘ A SUÍTE DE TESTES FALHOU!" -ForegroundColor Red
    exit 1
}
