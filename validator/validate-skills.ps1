# ==========================================
# validate-skills.ps1 — Validador de SKILL.md
# ==========================================
# Estrutura inicial do validador de Skills.
# PowerShell 7+
# ==========================================

param(
    [Parameter(Mandatory=$false)]
    [string]$SkillPath
)

function Write-Info {
    param([string]$Msg)
    Write-Host "• $Msg" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Msg)
    Write-Host "✔ $Msg" -ForegroundColor Green
}

function Write-ErrorDetail {
    param([string]$Msg)
    Write-Host "✘ $Msg" -ForegroundColor Red
}

Write-Host "===== HERMES AGENT HUB - VALIDADOR DE SKILLS =====" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($SkillPath)) {
    # Busca por qualquer pasta de skill no perfil do Hermes por padrão
    $SkillPath = Join-Path $env:USERPROFILE ".hermes\skills"
}

Write-Info "Diretório de verificação de Skills: $SkillPath"

if (-not (Test-Path $SkillPath)) {
    Write-ErrorDetail "Caminho de Skills não existe: $SkillPath"
    exit 1
}

$SkillsValidadas = 0
$FalhasTotais = 0

# Obtém todos os arquivos SKILL.md recursivos
$SkillFiles = Get-ChildItem $SkillPath -Filter "SKILL.md" -Recurse -File -ErrorAction SilentlyContinue

if ($SkillFiles.Count -eq 0) {
    Write-Info "Nenhum arquivo SKILL.md foi localizado para validação."
    exit 0
}

Write-Info "Encontrados $($SkillFiles.Count) arquivos SKILL.md para auditoria."

foreach ($file in $SkillFiles) {
    $RelPath = $file.FullName.Replace($SkillPath, "").TrimStart("\")
    Write-Host "`nAuditando: $RelPath ..." -ForegroundColor Yellow
    
    $erros = @()
    $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    
    # Regra 1: Presença de Frontmatter YAML
    # Deve iniciar com --- e ter outro --- delimitando
    if ($content -match '^---\r?\n([\s\S]*?)\r?\n---') {
        $frontmatter = $Matches[1]
        
        # Regra 2: Presença do campo 'name' no frontmatter
        if ($frontmatter -notmatch 'name:\s*\S+') {
            $erros += "Falta o campo 'name' no YAML frontmatter."
        }
        
        # Regra 3: Presença do campo 'description' no frontmatter
        if ($frontmatter -notmatch 'description:\s*\S+') {
            $erros += "Falta o campo 'description' no YAML frontmatter."
        }
    } else {
        $erros += "Arquivo SKILL.md não contém YAML frontmatter válido delimitado por ---."
    }
    
    # Regra 4: Validação de tamanho básico do Markdown
    if ($content.Length -lt 20) {
        $erros += "O corpo do arquivo SKILL.md está vazio ou muito curto."
    }
    
    # Exibe resultado da validação deste arquivo
    if ($erros.Count -eq 0) {
        Write-Success "Habilidade '$RelPath' validada com sucesso! Sem violações de estrutura."
    } else {
        Write-ErrorDetail "Habilidade '$RelPath' possui $($erros.Count) falhas de conformidade:"
        foreach ($err in $erros) {
            Write-ErrorDetail "  - $err"
        }
        $FalhasTotais += $erros.Count
    }
    $SkillsValidadas++
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Resumo do Validador:" -ForegroundColor Cyan
Write-Host "Habilidades Auditadas: $SkillsValidadas" -ForegroundColor Cyan
Write-Host "Erros de Conformidade: $FalhasTotais" -ForegroundColor (if ($FalhasTotais -gt 0) { "Red" } else { "Green" })
Write-Host "==========================================" -ForegroundColor Cyan

if ($FalhasTotais -gt 0) {
    exit 1
} else {
    exit 0
}
