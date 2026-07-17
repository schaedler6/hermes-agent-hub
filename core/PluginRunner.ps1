# ==========================================
# PluginRunner.ps1 — Executor Isolado de Plugins
# ==========================================
# PowerShell 7+
# ==========================================

# Garante UTF-8 no console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$CoreDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($CoreDir) -and $null -ne $MyInvocation -and $null -ne $MyInvocation.MyCommand) {
    $CoreDir = Split-Path $MyInvocation.MyCommand.Path -Parent
}
if ([string]::IsNullOrWhiteSpace($CoreDir) -and $null -ne $MyInvocation -and -not [string]::IsNullOrWhiteSpace($MyInvocation.ScriptName)) {
    $CoreDir = Split-Path $MyInvocation.ScriptName -Parent
}
if ([string]::IsNullOrWhiteSpace($CoreDir)) {
    $CoreDir = Get-Location
}
$ContractsScript = Join-Path $CoreDir "PluginContracts.ps1"
if (Test-Path $ContractsScript) {
    . $ContractsScript
}

function Invoke-PluginEntrypoint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PluginDir,
        
        [Parameter(Mandatory=$true)]
        [string]$Entrypoint,
        
        [Parameter(Mandatory=$false)]
        $Config = $null,
        
        [Parameter(Mandatory=$false)]
        [string]$ProjectRoot = ""
    )
    
    $PluginId = Split-Path $PluginDir -Leaf
    
    # 1. Carrega dependências se não estiverem no escopo
    $CoreDir = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($CoreDir) -and $null -ne $MyInvocation -and $null -ne $MyInvocation.MyCommand) {
        $CoreDir = Split-Path $MyInvocation.MyCommand.Path -Parent
    }
    if ([string]::IsNullOrWhiteSpace($CoreDir) -and $null -ne $MyInvocation -and -not [string]::IsNullOrWhiteSpace($MyInvocation.ScriptName)) {
        $CoreDir = Split-Path $MyInvocation.ScriptName -Parent
    }
    if ([string]::IsNullOrWhiteSpace($CoreDir)) {
        $CoreDir = Get-Location
    }
    
    $ValidatorScript = Join-Path $CoreDir "PluginValidator.ps1"
    if (Test-Path $ValidatorScript) {
        . $ValidatorScript
    }
    
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = Split-Path $CoreDir -Parent
    }
    
    # 2. Confirmações de segurança obrigatórias pelo Runner antes da execução:
    
    # A. Verifica se o manifesto existe
    $ManifestPath = Join-Path $PluginDir "plugin.json"
    if (-not (Test-Path $ManifestPath)) {
        return [PSCustomObject]@{
            pluginId   = $PluginId
            category   = "unknown"
            scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            status     = "error"
            items      = @()
            warnings   = @()
            errors     = @("Manifesto plugin.json não localizado.")
        }
    }
    
    # B. Valida Manifesto estruturalmente e detecta Path Traversal/permissões/plataforma
    $ValidationResult = Test-PluginManifest -PluginDir $PluginDir
    if (-not $ValidationResult.Valid) {
        return [PSCustomObject]@{
            pluginId   = $PluginId
            category   = "unknown"
            scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            status     = "error"
            items      = @()
            warnings   = @()
            errors     = $ValidationResult.Errors
        }
    }
    
    # C. Verifica se o plugin está habilitado
    $ManifestJson = Get-Content $ManifestPath -Raw -Encoding utf8 | ConvertFrom-Json
    if (-not $ManifestJson.enabled) {
        return [PSCustomObject]@{
            pluginId   = $PluginId
            category   = $ManifestJson.category
            scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            status     = "error"
            items      = @()
            warnings   = @()
            errors     = @("Plugin desabilitado no manifesto.")
        }
    }
    
    # D. Determina trustLevel efetivo e se é permitido executar
    $EffectiveTrust = Get-EffectiveTrustLevel -PluginId $PluginId -ProjectRoot $ProjectRoot
    if ($EffectiveTrust -eq "untrusted") {
        return [PSCustomObject]@{
            pluginId   = $PluginId
            category   = $ManifestJson.category
            scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            status     = "error"
            items      = @()
            warnings   = @()
            errors     = @("Plugin bloqueado: Nível de confiança efetivo é untrusted.")
        }
    }
    
    # E. Verifica integridade física dos arquivos (builtin e trusted)
    $IntegrityResult = Test-PluginIntegrity -PluginId $PluginId -PluginDir $PluginDir -EffectiveTrustLevel $EffectiveTrust -ProjectRoot $ProjectRoot
    if ($IntegrityResult.Status -eq "corrupted") {
        return [PSCustomObject]@{
            pluginId   = $PluginId
            category   = $ManifestJson.category
            scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            status     = "error"
            items      = @()
            warnings   = @()
            errors     = $IntegrityResult.Errors
        }
    } elseif ($IntegrityResult.Status -eq "missing") {
        return [PSCustomObject]@{
            pluginId   = $PluginId
            category   = $ManifestJson.category
            scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            status     = "error"
            items      = @()
            warnings   = @()
            errors     = $IntegrityResult.Errors
        }
    }
    
    # Inicia a execução do entrypoint resolvido
    $EntrypointFullPath = Join-Path $PluginDir $Entrypoint
    Write-Host "⚡ Executando plugin: $PluginId ($Entrypoint) [Confiança: $EffectiveTrust] ..." -ForegroundColor Cyan
    
    $StartTime = [DateTime]::UtcNow
    $OutputObject = $null
    $ExecutionErrors = @()
    
    try {
        $OutputObject = & $EntrypointFullPath -Config $Config -ErrorAction Stop
    } catch {
        $ExecutionErrors += "Falha na execução do script: $_"
        if ($_.ScriptStackTrace) {
            $ExecutionErrors += "Trace: $($_.ScriptStackTrace)"
        }
    }
    
    if ($ExecutionErrors.Count -gt 0 -or $null -eq $OutputObject) {
        $ErrorMsg = $ExecutionErrors -join " | "
        Write-Host "✘ Erro na execução do plugin '$PluginId': $ErrorMsg" -ForegroundColor Red
        
        return [PSCustomObject]@{
            pluginId   = $PluginId
            category   = $ManifestJson.category
            scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            status     = "error"
            items      = @()
            warnings   = @()
            errors     = $ExecutionErrors
        }
    }
    
    # Valida se a saída obedece ao contrato estruturado
    $ContractValid = Test-PluginOutputContract -Output $OutputObject
    if (-not $ContractValid) {
        Write-Host "⚠ Alerta: A saída do plugin '$PluginId' não obedece ao contrato do Hermes Hub." -ForegroundColor Yellow
        
        $NormalizedItems = @()
        if ($OutputObject -is [array]) {
            $NormalizedItems = $OutputObject
        } elseif ($OutputObject.items -is [array]) {
            $NormalizedItems = $OutputObject.items
        }
        
        return [PSCustomObject]@{
            pluginId   = $PluginId
            category   = if ($OutputObject.category) { $OutputObject.category } else { $ManifestJson.category }
            scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            status     = "warning"
            items      = $NormalizedItems
            warnings   = @("Saída do plugin não aderente ao contrato oficial de dados.")
            errors     = @()
        }
    }
    
    return $OutputObject
}
