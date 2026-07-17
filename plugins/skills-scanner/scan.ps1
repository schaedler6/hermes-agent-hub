# ==========================================
# scan.ps1 — Skills Scanner Plugin Entrypoint
# ==========================================

# Carrega o parâmetro opcional Config passado pelo Runner
param(
    $Config = $null
)

$PluginDir = $PSScriptRoot
$ProjectRoot = Split-Path (Split-Path $PluginDir -Parent) -Parent

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Se não foi passado config, tenta carregar do config.json
if ($null -eq $Config) {
    $ConfigPath = Join-Path $ProjectRoot "config.json"
    if (Test-Path $ConfigPath) {
        $Config = Get-Content $ConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
    }
}

# Resolução dos caminhos de busca de Skills
$SearchPaths = @()
if ($Config.skillSearchPaths) {
    foreach ($path in $Config.skillSearchPaths) {
        $resolved = $path.Replace('$HOME', $env:USERPROFILE).Replace('~', $env:USERPROFILE)
        $SearchPaths += $resolved
    }
} else {
    $SearchPaths += Join-Path $env:USERPROFILE ".hermes\skills"
}

$SkillsCandidatas = @()

# 1. Varredura de pastas de Skills locais
foreach ($searchPath in $SearchPaths) {
    if (Test-Path $searchPath) {
        $SubFolders = Get-ChildItem -Path $searchPath -Directory -ErrorAction SilentlyContinue
        foreach ($folder in $SubFolders) {
            $SkillMdPath = Join-Path $folder.FullName "SKILL.md"
            if (Test-Path $SkillMdPath) {
                $SkillsCandidatas += @{
                    Folder = $folder
                    SkillMd = $SkillMdPath
                    Source = $searchPath
                }
            }
        }
    }
}

$ResultadosSkills = @()
$ErrorsList = @()
$WarningsList = @()

# 2. Processamento e Validação de cada Skill
foreach ($candidate in $SkillsCandidatas) {
    $folder = $candidate.Folder
    $skillMd = $candidate.SkillMd
    $source = $candidate.Source
    
    $errors = @()
    $warnings = @()
    $riskLevel = "low"
    $score = 0
    
    $hasScripts = Test-Path (Join-Path $folder.FullName "scripts")
    $hasReferences = Test-Path (Join-Path $folder.FullName "references")
    $hasTemplates = Test-Path (Join-Path $folder.FullName "templates")
    $hasAssets = Test-Path (Join-Path $folder.FullName "assets")
    $hasTests = Test-Path (Join-Path $folder.FullName "tests")
    
    $fileInfo = Get-Item $skillMd
    $skillMdLength = $fileInfo.Length
    $yamlValid = $false
    $name = $folder.Name
    $description = ""
    
    if ($skillMdLength -eq 0) {
        $errors += "O arquivo SKILL.md está vazio (0 bytes)."
    } else {
        $content = Get-Content $skillMd -Raw -Encoding utf8
        
        # Validação do YAML Frontmatter
        if ($content -match '^---\r?\n([\s\S]*?)\r?\n---') {
            $frontmatter = $Matches[1]
            $yamlValid = $true
            
            if ($frontmatter -match '(?mi)^name:\s*["'']?(.*?)["'']?\s*$') {
                $name = $Matches[1].Trim()
            } else {
                $errors += "Campo 'name' ausente no frontmatter do SKILL.md."
            }
            
            if ($frontmatter -match '(?mi)^description:\s*["'']?(.*?)["'']?\s*$') {
                $description = $Matches[1].Trim()
            } else {
                $errors += "Campo 'description' ausente no frontmatter do SKILL.md."
            }
        } else {
            $errors += "YAML frontmatter ausente ou malformado (delimitadores --- não encontrados)."
        }
        
        # Validação de links locais Markdown
        $LinkRegex = '\[.*?\]\((?!https?:\/\/)(?!#)(?!mailto:)(.*?)\)'
        $MatchesLinks = [regex]::Matches($content, $LinkRegex)
        foreach ($match in $MatchesLinks) {
            $linkTargetRaw = $match.Groups[1].Value
            $linkTargetClean = ($linkTargetRaw -split '#' | Select-Object -First 1).Split('?') | Select-Object -First 1
            if (-not [string]::IsNullOrWhiteSpace($linkTargetClean)) {
                $cleanTargetOs = $linkTargetClean.Replace('/', '\')
                $linkFullPath = Join-Path $folder.FullName $cleanTargetOs
                if (-not (Test-Path $linkFullPath)) {
                    $warnings += "Link local quebrado: '$linkTargetRaw' (arquivo não existe na pasta da skill)."
                }
            }
        }
    }
    
    # Análise Estática de Segurança
    $dangerAlerts = @()
    $allFiles = Get-ChildItem -Path $folder.FullName -File -Recurse -ErrorAction SilentlyContinue
    foreach ($f in $allFiles) {
        if ($f.Extension -match '\.(md|txt|ps1|bat|cmd|sh|js|json|yml|yaml)$') {
            try {
                $fContent = Get-Content $f.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
                if ($fContent) {
                    if ($fContent -match '(?i)Remove-Item\s+.*-(Recurse|Force)') {
                        $dangerAlerts += "Remove-Item com -Recurse ou -Force em $($f.Name)"
                    }
                    if ($fContent -match 'rm\s+-rf') {
                        $dangerAlerts += "Comando 'rm -rf' em $($f.Name)"
                    }
                    if ($fContent -match '(?i)Invoke-Expression\b|(?i)\biex\b') {
                        $dangerAlerts += "Uso de 'Invoke-Expression' ou 'iex' em $($f.Name)"
                    }
                    if ($fContent -match 'curl\s+.*\|\s*(sh|bash|pwsh|powershell)' -or $fContent -match 'wget\s+.*\|\s*(sh|bash|pwsh|powershell)') {
                        $dangerAlerts += "Download e pipe para interpretador de comandos em $($f.Name)"
                    }
                    if ($fContent -match '(?i)-Verb\s+RunAs' -or $fContent -match '(?i)\brunas\b' -or $fContent -match '\bsudo\b') {
                        $dangerAlerts += "Execução solicitando privilégio de administrador em $($f.Name)"
                    }
                    if ($fContent -match '(?i)\b(password|token|secret|api_key|apikey)\b' -and $fContent -notmatch '^#.*password') {
                        $dangerAlerts += "Possível menção ou acesso a credencial/token em $($f.Name)"
                    }
                    if ($fContent -match '(?i)Set-ItemProperty' -or $fContent -match 'reg\s+add' -or $fContent -match '(?i)New-ItemProperty') {
                        $dangerAlerts += "Alteração do registro do Windows em $($f.Name)"
                    }
                    if ($fContent -match '(?i)Net\.WebClient' -or $fContent -match '(?i)Invoke-WebRequest' -or $fContent -match '(?i)Invoke-RestMethod') {
                        if ($fContent -match 'iex' -or $fContent -match 'Invoke-Expression') {
                            $dangerAlerts += "Download e execução remota de scripts em $($f.Name)"
                        } else {
                            $warnings += "Acesso de rede identificado (download/rest) em $($f.Name)."
                        }
                    }
                }
            } catch {
                # Ignora erros de leitura
            }
        }
    }
    
    foreach ($alert in $dangerAlerts) {
        $warnings += "ALERTA CRÍTICO DE SEGURANÇA: $alert"
    }
    
    # Cálculo do Score Estrutural (0 a 100)
    if (Test-Path $skillMd) { $score += 20 }
    if ($yamlValid) { $score += 15 }
    if ($name -and $name -ne $folder.Name) { $score += 10 } elseif ($name) { $score += 5 }
    if ($description) { $score += 10 }
    
    $brokenLinks = $warnings | Where-Object { $_ -match 'Link local quebrado' }
    if ($brokenLinks.Count -eq 0) { $score += 15 }
    
    if ((Test-Path $skillMd) -and $skillMdLength -gt 150) { $score += 10 }
    if ($hasTests) { $score += 10 }
    if ($dangerAlerts.Count -eq 0) { $score += 10 }
    
    # Risco
    if ($dangerAlerts.Count -gt 0) {
        $riskLevel = "high"
    } elseif ($errors.Count -gt 0 -or $warnings.Count -gt 0) {
        $riskLevel = "medium"
    } else {
        $riskLevel = "low"
    }
    
    $ResultadosSkills += [PSCustomObject]@{
        name          = $name
        description   = $description
        path          = $folder.FullName
        source        = $source
        valid         = ($errors.Count -eq 0)
        score         = $score
        riskLevel     = $riskLevel
        hasScripts    = $hasScripts
        hasReferences = $hasReferences
        hasTemplates  = $hasTemplates
        hasAssets     = $hasAssets
        hasTests      = $hasTests
        errors        = $errors
        warnings      = $warnings
        scannedAt     = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    }
}

return [PSCustomObject]@{
    pluginId   = "skills-scanner"
    category   = "skills"
    scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    status     = "success"
    items      = $ResultadosSkills
    warnings   = @()
    errors     = @()
}
