# ==========================================
# Build-Distribution.ps1
# Script de Empacotamento Clean-Room do Hermes Hub
# ==========================================

$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
$DistDir = Join-Path $ProjectRoot "dist"
$StagingDir = Join-Path $ProjectRoot "dist_clean"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "📦 CONSTRUINDO DISTRIBUIÇÃO CLEAN-ROOM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Limpa pastas anteriores
if (Test-Path $StagingDir) {
    Remove-Item $StagingDir -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path $DistDir) {
    Remove-Item $DistDir -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

# 2. Lista de diretórios e arquivos públicos a serem copiados
$PublicItems = @(
    "LICENSE",
    "README.md",
    "README.pt-BR.md",
    "RELEASE_NOTES_v0.3.0-rc.1.md",
    "PUBLISHING_SUMMARY.md",
    "Start-HermesHub.ps1",
    "config.json",
    "config.example.json",
    ".gitattributes",
    ".gitignore",
    "config",
    "scanner",
    "validator",
    "assets",
    "core",
    "plugins",
    "tools",
    "dashboard",
    "docs",
    "tests"
)

foreach ($item in $PublicItems) {
    $src = Join-Path $ProjectRoot $item
    $dest = Join-Path $StagingDir $item
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 3. Limpeza de dados locais indesejados no staging
$StagingDataDir = Join-Path $StagingDir "data"
$StagingLogsDir = Join-Path $StagingDir "logs"

Remove-Item (Join-Path $StagingDataDir "plugin-trust.json") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StagingDataDir "trusted-integrity.json") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StagingDataDir "agents.json") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StagingDataDir "agents.md") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StagingDataDir "skills.json") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StagingDataDir "skills.md") -Force -ErrorAction SilentlyContinue

Remove-Item (Join-Path $StagingDir "dashboard\data.js") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StagingDir "dashboard\skills-data.js") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StagingDir "dashboard\plugins-data.js") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $StagingDir "config.local.json") -Force -ErrorAction SilentlyContinue

if (Test-Path $StagingLogsDir) {
    Remove-Item $StagingLogsDir -Recurse -Force -ErrorAction SilentlyContinue
}

# 4. Compacta a pasta de staging para dist/
$ZipPath = Join-Path $DistDir "hermes-agent-hub-v0.3.0-rc.1.zip"
Write-Host "⚡ Compactando arquivos em $ZipPath..." -ForegroundColor Yellow

# Usa PowerShell nativo Compress-Archive
Compress-Archive -Path "$StagingDir\*" -DestinationPath $ZipPath -Force

# 5. Calcula Checksum SHA-256 do ZIP
Write-Host "⚡ Calculando Checksum SHA-256..." -ForegroundColor Yellow
$HashStream = Get-FileHash -Path $ZipPath -Algorithm SHA256
$ChecksumPath = Join-Path $DistDir "hermes-agent-hub-v0.3.0-rc.1.zip.sha256"
$HashStream.Hash | Set-Content $ChecksumPath -Encoding utf8

# 6. Cria o RELEASE_MANIFEST.json
$ManifestPath = Join-Path $DistDir "RELEASE_MANIFEST.json"
$Manifest = [ordered]@{
    name = "Hermes Agent Hub"
    version = "v0.3.0-rc.1"
    createdAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    zipSha256 = $HashStream.Hash
    zipSize = (Get-Item $ZipPath).Length
    powershellMinimum = "7.0"
    supportedPlatforms = @("windows")
    testCount = 66
    license = "MIT"
    limitations = @(
        "Sem sandbox nativo de sistema operacional",
        "Aprovação e validação de código de terceiros local necessária"
    )
    includedFiles = $PublicItems
}
$Manifest | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath -Encoding utf8

Write-Host "✔ Distribuição empacotada com sucesso na pasta dist/!" -ForegroundColor Green
