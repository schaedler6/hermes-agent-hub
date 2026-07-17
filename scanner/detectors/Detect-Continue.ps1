param($Config)

$Name = "Continue"
$Category = "IDE Extension"
$Detected = $false
$Running = $false
$Version = "desconhecida"
$Executable = "VS Code Extension"
$InstallPath = ""
$DetectionMethod = "VS Code Extension & Profile Check"
$Notes = ""

$ProfilePath = Join-Path $env:USERPROFILE ".continue"
$VscodeExtPath = Join-Path $env:USERPROFILE ".vscode\extensions"

$EncontradoProfile = Test-Path $ProfilePath
$EncontradoVSCode = $false
$VsCodeFolder = ""

if (Test-Path $VscodeExtPath) {
    $Matches = Get-ChildItem $VscodeExtPath -Directory -Filter "continue.continue-*" -ErrorAction SilentlyContinue
    if ($Matches) {
        $EncontradoVSCode = $true
        $VsCodeFolder = $Matches[0].FullName
        if ($Matches[0].Name -match 'continue\.continue-(.*)') {
            $Version = $Matches[1]
        }
    }
}

if ($EncontradoProfile -or $EncontradoVSCode) {
    $Detected = $true
    $Caminhos = @()
    if ($EncontradoProfile) {
        $Caminhos += $ProfilePath
        $Notes += "Pasta de configurações encontrada em .continue. "
    }
    if ($EncontradoVSCode) {
        $Caminhos += $VsCodeFolder
        $Notes += "Extensão do VS Code detectada."
    }
    $InstallPath = $Caminhos -join " | "
} else {
    $Notes = "Continue não localizado."
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
