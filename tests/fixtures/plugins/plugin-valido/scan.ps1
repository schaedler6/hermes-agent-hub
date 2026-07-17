# Entrypoint do plugin válido de fixture
return [PSCustomObject]@{
    pluginId   = "plugin-valido"
    category   = "examples"
    scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    status     = "success"
    items      = @([PSCustomObject]@{ id = "valido-item"; name = "Item Valido" })
    warnings   = @()
    errors     = @()
}
