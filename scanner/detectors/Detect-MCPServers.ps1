param($Config)

$Name = "MCP Servers"
$Category = "Context Protocol"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "claude_desktop_config.json"
$InstallPath = ""
$DetectionMethod = "Claude Desktop Config Analysis"
$Notes = ""

$ClaudeConfigPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"

if (Test-Path $ClaudeConfigPath) {
    $Detected = $true
    $InstallPath = $ClaudeConfigPath
    
    try {
        $jsonContent = Get-Content $ClaudeConfigPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($jsonContent) {
            $parsed = ConvertFrom-Json $jsonContent -ErrorAction SilentlyContinue
            if ($parsed -and $parsed.mcpServers) {
                $servers = @()
                foreach ($prop in $parsed.mcpServers.PSObject.Properties) {
                    $servers += $prop.Name
                }
                
                $count = $servers.Count
                $Version = "Configured: $count"
                $Notes = "Arquivo claude_desktop_config.json localizado. Servidores identificados: $count."
            } else {
                $Version = "Configured: 0"
                $Notes = "Arquivo claude_desktop_config.json localizado, mas sem servidores configurados."
            }
        } else {
            $Notes = "Arquivo claude_desktop_config.json está vazio."
        }
    } catch {
        $Notes = "Falha ao ler as configurações do Claude Desktop."
    }
} else {
    $Notes = "Arquivo de configuração do Claude Desktop não localizado."
}

return [PSCustomObject]@{
    name            = $Name
    category        = $Category
    detected        = $Detected
    running         = $Running
    version         = $Version
    executable      = $Executable
    installPath     = $InstallPath
    detectionMethod = $DetectionMethod
    notes           = $Notes.Trim()
    scannedAt       = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}
