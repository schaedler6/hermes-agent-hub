# ==========================================
# scan.ps1 — Hello Plugin Entrypoint
# ==========================================

$ItemExemplo = [PSCustomObject]@{
    id          = "hello-item"
    name        = "Hello Item"
    description = "Retorno de exemplo do hello-plugin para testes."
    status      = "active"
}

return [PSCustomObject]@{
    pluginId   = "hello-plugin"
    category   = "examples"
    scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    status     = "success"
    items      = @($ItemExemplo)
    warnings   = @()
    errors     = @()
}
