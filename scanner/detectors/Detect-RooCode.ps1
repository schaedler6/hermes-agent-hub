param($Config)

$Name = "Roo Code"
$Category = "IDE Extension"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "VS Code Extension"
$InstallPath = ""
$DetectionMethod = "VS Code Extension Check"
$Notes = ""

$VscodeExtPath = Join-Path $env:USERPROFILE ".vscode\extensions"

if (Test-Path $VscodeExtPath) {
    $Matches = Get-ChildItem $VscodeExtPath -Directory -Filter "roocode.roo-cline-*" -ErrorAction SilentlyContinue
    if (-not $Matches) {
        $Matches = Get-ChildItem $VscodeExtPath -Directory -Filter "*roo-cline-*" -ErrorAction SilentlyContinue
    }
    
    if ($Matches) {
        $Detected = $true
        $InstallPath = $Matches[0].FullName
        if ($Matches[0].Name -match 'roo-cline-(.*)') {
            $Version = $Matches[1]
        }
        $Notes = "Extensão instalada no VS Code detectada em: " + $Matches[0].Name
    }
}

if (-not $Detected) {
    $Notes = "Extensão Roo Code não localizada."
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
