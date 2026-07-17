param($Config)

$Name = "Custom Agents"
$Category = "Custom"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "N/A"
$InstallPath = ""
$DetectionMethod = "Custom Search Paths Scanning"
$Notes = ""

$DetectedPaths = @()
$ProjetosNomes = @()

if ($Config.customSearchPaths) {
    foreach ($path in $Config.customSearchPaths) {
        if (Test-Path $path) {
            $subDirs = Get-ChildItem $path -Directory -ErrorAction SilentlyContinue
            
            # Se o próprio path é um projeto
            $isAgentSelf = (Test-Path (Join-Path $path "requirements.txt")) -or (Test-Path (Join-Path $path "package.json"))
            if ($isAgentSelf -and ($path -match 'agent|hub|assistant|bot')) {
                $DetectedPaths += $path
                $ProjetosNomes += (Split-Path $path -Leaf)
            }
            
            foreach ($sub in $subDirs) {
                if ($Config.exclucoes -and ($Config.exclucoes -contains $sub.Name)) {
                    continue
                }
                
                $hasAgentIndicator = ($sub.Name -match 'agent|hub|assistant|bot') -or 
                                     (Test-Path (Join-Path $sub.FullName ".agents")) -or 
                                     (Test-Path (Join-Path $sub.FullName "SKILL.md"))
                                     
                if ($hasAgentIndicator) {
                    $DetectedPaths += $sub.FullName
                    $ProjetosNomes += $sub.Name
                }
            }
        }
    }
}

if ($DetectedPaths.Count -gt 0) {
    $Detected = $true
    $InstallPath = $DetectedPaths -join " | "
    $Version = "Count: " + $DetectedPaths.Count
    $Notes = "Projetos detectados nos diretórios do usuário: (" + ($ProjetosNomes -join ", ") + ")."
} else {
    $Notes = "Nenhum agente personalizado ou projeto local foi localizado nos caminhos de busca configurados."
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
