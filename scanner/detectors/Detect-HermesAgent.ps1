param($Config)

$Name = "Hermes Agent"
$Category = "Memory & Context Assistant"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "N/A"
$InstallPath = ""
$DetectionMethod = "Caminhos Padrão & RAG Registry"
$Notes = ""

$HomeHermes = Join-Path $env:USERPROFILE ".hermes"
$SidRag = "C:\Sid\RAG_Obsidian"

$EncontradoHome = Test-Path $HomeHermes
$EncontradoRag = Test-Path $SidRag

if ($EncontradoHome -or $EncontradoRag) {
    $Detected = $true
    $Caminhos = @()
    if ($EncontradoHome) {
        $Caminhos += $HomeHermes
        $InstallPath = $HomeHermes
        
        $SkillsPath = Join-Path $HomeHermes "skills"
        if (Test-Path $SkillsPath) {
            $Skills = Get-ChildItem $SkillsPath -Directory | Select-Object -ExpandProperty Name
            if ($Skills) {
                $Notes += "Skills locais: (" + ($Skills -join ", ") + "). "
            }
        }
    }
    if ($EncontradoRag) {
        $Caminhos += $SidRag
        if ([string]::IsNullOrWhiteSpace($InstallPath)) {
            $InstallPath = $SidRag
        }
        $Notes += "Integração RAG em C:\Sid\RAG_Obsidian ativa. "
    }
    
    $InstallPath = $Caminhos -join " | "
    
    # Verifica se o MCP do Hermes está ativo (processo Node executando MCP_Obsidian ou escutando na porta 8787)
    # Procuramos processos que combinem com "mcp" ou "server"
    $nodeProcs = Get-Process -Name "node" -ErrorAction SilentlyContinue
    if ($nodeProcs) {
        $Running = $true
        $Notes += "Interface MCP ativamente associada à processos Node."
    }
    
    if (Test-Path "C:\Sid\MCP_Obsidian") {
        $Version = "v0.2 (RAG MCP)"
    } else {
        $Version = "v0.1 (Local Notes)"
    }
} else {
    $Notes = "Pasta de configurações .hermes ou projeto RAG não localizados."
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
