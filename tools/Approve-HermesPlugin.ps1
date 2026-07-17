# tools/Approve-HermesPlugin.ps1
# Script de aprovação explícita e assinatura de integridade do Hermes Hub
# ==========================================

param(
    [Parameter(Mandatory=$true)]
    [string]$PluginId,
    
    [switch]$RefreshBuiltinIntegrity
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ToolsDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ToolsDir)) { $ToolsDir = Get-Location }
$ProjectRoot = Split-Path $ToolsDir -Parent

$CoreDir = Join-Path $ProjectRoot "core"
. (Join-Path $CoreDir "PluginContracts.ps1")
. (Join-Path $CoreDir "PluginValidator.ps1")

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🔌 APROVAÇÃO E ASSINATURA DE PLUGIN HERMES" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Localiza a pasta do plugin nos diretórios de pesquisa configurados
$ConfigPath = Join-Path $ProjectRoot "config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Arquivo config.json não encontrado."
    exit 1
}

$Config = Get-Content $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
$PathsToSearch = $Config.pluginPaths
if ($null -eq $PathsToSearch) { $PathsToSearch = @(".\plugins") }

$PluginDir = $null
foreach ($searchPath in $PathsToSearch) {
    $ResolvedSearchPath = Join-Path $ProjectRoot $searchPath
    if (Test-Path $ResolvedSearchPath) {
        # Busca recursiva pela pasta do ID correspondente
        $Dirs = Get-ChildItem $ResolvedSearchPath -Directory -Recurse -ErrorAction SilentlyContinue
        # Inclui o próprio ResolvedSearchPath na busca
        $Dirs += Get-Item $ResolvedSearchPath -ErrorAction SilentlyContinue
        foreach ($dir in $Dirs) {
            if ($dir.Name -eq $PluginId) {
                # Confirma se tem o plugin.json
                if (Test-Path (Join-Path $dir.FullName "plugin.json")) {
                    $PluginDir = $dir.FullName
                    break
                }
            }
        }
    }
    if ($null -ne $PluginDir) { break }
}

if ($null -eq $PluginDir) {
    Write-Error "Erro: Pasta do plugin com ID '$PluginId' não foi localizada sob os caminhos configurados."
    exit 1
}

Write-Host "Plugin localizado em: $PluginDir" -ForegroundColor Gray

# 2. Executa validação de conformidade do manifesto (sem integridade, que será gerada agora)
$ValResult = Test-PluginManifest -PluginDir $PluginDir
if (-not $ValResult.Valid) {
    Write-Error "Erro: O plugin '$PluginId' possui erros no manifesto e não pode ser aprovado:"
    foreach ($err in $ValResult.Errors) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    exit 1
}

$Manifest = $ValResult.Manifest

# 3. Determina confiança efetiva prévia
$BuiltinStorePath = Join-Path $ProjectRoot "config\builtin-plugins.json"
$IsBuiltin = $false
if (Test-Path $BuiltinStorePath) {
    $BuiltinList = Get-Content $BuiltinStorePath -Raw -Encoding utf8 | ConvertFrom-Json
    if ($BuiltinList -contains $PluginId) {
        $IsBuiltin = $true
    }
}

if ($IsBuiltin) {
    Write-Host "[MÓDULO OFICIAL] O plugin '$PluginId' é considerado BUILTIN pela distribuição." -ForegroundColor Green
    if (-not $RefreshBuiltinIntegrity) {
        Write-Error "Erro: O plugin '$PluginId' é builtin. Para atualizar sua baseline de integridade de desenvolvimento, execute com o parâmetro -RefreshBuiltinIntegrity."
        exit 1
    }
} else {
    Write-Host "[MÓDULO DE TERCEIROS] Solicitando aprovação local para confiança 'trusted'." -ForegroundColor Yellow
}

# 4. Apresenta metadados do plugin e permissões solicitadas
Write-Host "`nDetalhes do Manifesto:" -ForegroundColor Cyan
Write-Host "  Nome: $($Manifest.name)"
Write-Host "  Versão: $($Manifest.version)"
Write-Host "  Autor: $($Manifest.author)"
Write-Host "  Descrição: $($Manifest.description)"
Write-Host "  Categoria: $($Manifest.category)"
Write-Host "  Entrypoint: $($Manifest.entrypoint)"

Write-Host "`nPermissões Solicitadas:" -ForegroundColor Cyan
if ($Manifest.permissions -and $Manifest.permissions.Count -gt 0) {
    foreach ($perm in $Manifest.permissions) {
        Write-Host "  [+] $perm" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [Nenhuma permissão declarada]" -ForegroundColor Gray
}

# 5. Lista arquivos executáveis incluídos no plugin
Write-Host "`nArquivos Executáveis Identificados:" -ForegroundColor Cyan
$HashesBefore = Get-PluginHashes -PluginDir $PluginDir
if ($HashesBefore.Keys.Count -eq 0) {
    Write-Error "Erro: Nenhum arquivo relevante ou executável localizado na pasta do plugin."
    exit 1
}
foreach ($file in $HashesBefore.Keys) {
    Write-Host "  * $file (Hash: $($HashesBefore[$file]))" -ForegroundColor Gray
}

# 6. Solicitação interativa de aprovação
Write-Host "`n==========================================" -ForegroundColor Cyan
if ($IsBuiltin) {
    Write-Host "AVISO: Esta ação irá reescrever a integridade do plugin builtin oficial." -ForegroundColor Yellow
    $PromptMessage = "Deseja atualizar a baseline builtin de '$PluginId'? (S/N): "
} else {
    Write-Host "ATENÇÃO: Aprove apenas plugins de origens conhecidas e cujos scripts você revisou." -ForegroundColor Yellow
    $PromptMessage = "Deseja aprovar e marcar o plugin '$PluginId' como TRUSTED? (S/N): "
}

$Confirm = Read-Host -Prompt $PromptMessage
if ($Confirm.Trim().ToLower() -notmatch '^(s|y|sim|yes)$') {
    Write-Host "Aprovação cancelada pelo usuário." -ForegroundColor Yellow
    exit 0
}

# 7. Registra aprovação no trust store externo correspondente (se for trusted de terceiros)
if (-not $IsBuiltin) {
    $DataDir = Join-Path $ProjectRoot "data"
    if (-not (Test-Path $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    }
    
    $TrustStorePath = Join-Path $ProjectRoot "data\plugin-trust.json"
    $TrustedList = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $TrustStorePath) {
        try {
            $StoreList = Get-Content $TrustStorePath -Raw -Encoding utf8 | ConvertFrom-Json
            if ($StoreList -is [array]) {
                foreach ($item in $StoreList) { $TrustedList.Add($item) }
            }
        } catch {}
    }
    
    if (-not $TrustedList.Contains($PluginId)) {
        $TrustedList.Add($PluginId)
    }
    
    $TrustedList | ConvertTo-Json | Set-Content $TrustStorePath -Encoding utf8
    Write-Host "✔ Plugin registrado no trust store externo ('data/plugin-trust.json')." -ForegroundColor Green
}

# 8. Calcula os hashes dos arquivos finais no disco e gera o registro de integridade
$FinalHashes = Get-PluginHashes -PluginDir $PluginDir

$IntegrityStorePath = $null
if ($IsBuiltin) {
    $IntegrityStorePath = Join-Path $ProjectRoot "config\builtin-integrity.json"
} else {
    $IntegrityStorePath = Join-Path $ProjectRoot "data\trusted-integrity.json"
}

$IntegrityStore = [ordered]@{}
if (Test-Path $IntegrityStorePath) {
    try {
        $CurrentStore = Get-Content $IntegrityStorePath -Raw -Encoding utf8 | ConvertFrom-Json
        $StoreMembers = Get-Member -InputObject $CurrentStore -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($member in $StoreMembers) {
            $IntegrityStore[$member] = $CurrentStore.$member
        }
    } catch {}
}

$FilesObj = [ordered]@{}
foreach ($key in $FinalHashes.Keys) {
    $FilesObj[$key] = $FinalHashes[$key]
}

# Adiciona ou atualiza registro
$IntegrityStore[$PluginId] = [ordered]@{
    pluginId   = $PluginId
    version    = $Manifest.version
    approvedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    algorithm  = "SHA256"
    files      = $FilesObj
}

$IntegrityStore | ConvertTo-Json -Depth 5 | Set-Content $IntegrityStorePath -Encoding utf8
Write-Host "✔ Baseline de integridade salva com sucesso em '$IntegrityStorePath'." -ForegroundColor Green

# 9. Verifica novamente o registro salvo contra os arquivos físicos
$EffectiveTrust = if ($IsBuiltin) { "builtin" } else { "trusted" }
$VerifyResult = Test-PluginIntegrity -PluginId $PluginId -PluginDir $PluginDir -EffectiveTrustLevel $EffectiveTrust -ProjectRoot $ProjectRoot

if ($VerifyResult.Status -eq "valid") {
    Write-Host "✔ Verificação pós-aprovação concluída: integridade VALIDADA com sucesso!" -ForegroundColor Green
    Write-Host "O plugin '$PluginId' está pronto para ser executado!" -ForegroundColor Green
} else {
    Write-Error "Erro crítico: A verificação de integridade pós-aprovação falhou:"
    foreach ($err in $VerifyResult.Errors) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    exit 1
}
