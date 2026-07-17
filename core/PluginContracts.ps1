# ==========================================
# PluginContracts.ps1 — Definições de Contrato
# ==========================================
# PowerShell 7+
# ==========================================

# Garante UTF-8 no console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-MandatoryFields {
    return @("id", "name", "version", "author", "description", "category", "entrypoint", "enabled", "supportedPlatforms", "permissions", "outputs")
}

function Get-SupportedCategories {
    return @("agents", "skills", "models", "workflows", "examples", "mcp")
}

function Get-AllowedPermissions {
    return @("filesystem.read", "filesystem.write.project", "process.read", "process.version", "config.read", "output.write.project")
}

# Valida se a saída do plugin obedece ao contrato de dados padrão
function Test-PluginOutputContract {
    param(
        [Parameter(Mandatory=$true)]
        $Output
    )
    
    if ($null -eq $Output) { return $false }
    
    # Verifica a existência das propriedades requeridas
    $RequiredProperties = @("pluginId", "category", "scannedAt", "status", "items", "warnings", "errors")
    foreach ($prop in $RequiredProperties) {
        if (-not (Get-Member -InputObject $Output -Name $prop -ErrorAction SilentlyContinue)) {
            return $false
        }
    }
    
    # Valida status permitido
    $AllowedStatus = @("success", "warning", "error")
    if ($AllowedStatus -notcontains $Output.status) {
        return $false
    }
    
    return $true
}
