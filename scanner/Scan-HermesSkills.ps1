# ==========================================
# Scan-HermesSkills.ps1
# Orquestrador do Scanner de Agent Skills
# ==========================================
# PowerShell 7+
# ==========================================

# Garante UTF-8 no console do PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScannerRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScannerRoot)) {
    $ScannerRoot = Get-Location
}
$ProjectRoot = Split-Path $ScannerRoot -Parent

$ConfigPath = Join-Path $ProjectRoot "config.json"
$DataDir = Join-Path $ProjectRoot "data"
$LogsDir = Join-Path $ProjectRoot "logs"
$DashboardDir = Join-Path $ProjectRoot "dashboard"

# Cria os diretórios necessários se não existirem
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null
New-Item -ItemType Directory -Force -Path $DashboardDir | Out-Null

# Inicializa o arquivo de log para esta execução
$StartTime = [DateTime]::UtcNow
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path $LogsDir "skills-scan-$Timestamp.log"

function Write-SkillsLog {
    param([string]$Mensagem, [string]$Tipo = "INFO")
    $TimeStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$TimeStr] [$Tipo] $Mensagem"
    
    # Adiciona ao arquivo de log em UTF-8
    $LogLine | Out-File -FilePath $LogFile -Append -Encoding utf8
    
    # Imprime no terminal com cores apropriadas
    switch ($Tipo) {
        "ENCONTRADO" { Write-Host $LogLine -ForegroundColor Green }
        "ALERTA"     { Write-Host $LogLine -ForegroundColor Yellow }
        "ERRO"       { Write-Host $LogLine -ForegroundColor Red }
        default      { Write-Host $LogLine -ForegroundColor Gray }
    }
}

Write-SkillsLog "Iniciando Varredura de Agent Skills do Hermes" "INFO"
Write-SkillsLog "Pasta Raiz do Projeto: $ProjectRoot" "INFO"

# 1. Carrega o arquivo config.json
if (-not (Test-Path $ConfigPath)) {
    Write-SkillsLog "Arquivo config.json não encontrado em $ConfigPath. Utilizando valores padrão." "ALERTA"
    $Config = @{
        skillSearchPaths = @(
            '$HOME\.hermes\skills',
            '$HOME\.claude\skills',
            '$HOME\.codex\skills',
            '$HOME\.agents\skills'
        )
    }
} else {
    try {
        $ConfigJson = Get-Content $ConfigPath -Raw -Encoding utf8
        $Config = ConvertFrom-Json $ConfigJson
        Write-SkillsLog "Configurações carregadas com sucesso de config.json." "INFO"
    } catch {
        Write-SkillsLog "Falha ao ler config.json. Erro: $_" "ERRO"
        exit 1
    }
}

# 2. Resolução dos caminhos de busca de Skills
$SearchPaths = @()
if ($Config.skillSearchPaths) {
    foreach ($path in $Config.skillSearchPaths) {
        $resolved = $path.Replace('$HOME', $env:USERPROFILE).Replace('~', $env:USERPROFILE)
        $SearchPaths += $resolved
    }
} else {
    $SearchPaths += Join-Path $env:USERPROFILE ".hermes\skills"
}

Write-SkillsLog "Diretórios de varredura configurados: $($SearchPaths -join ', ')" "INFO"

$SkillsCandidatas = @()

# 3. Varredura de pastas de Skills locais
foreach ($searchPath in $SearchPaths) {
    if (Test-Path $searchPath) {
        Write-SkillsLog "Buscando habilidades na pasta: $searchPath" "INFO"
        $SubFolders = Get-ChildItem -Path $searchPath -Directory -ErrorAction SilentlyContinue
        foreach ($folder in $SubFolders) {
            $SkillMdPath = Join-Path $folder.FullName "SKILL.md"
            if (Test-Path $SkillMdPath) {
                Write-SkillsLog "Candidato encontrado: $($folder.Name) com SKILL.md" "INFO"
                $SkillsCandidatas += @{
                    Folder = $folder
                    SkillMd = $SkillMdPath
                    Source = $searchPath
                }
            }
        }
    } else {
        Write-SkillsLog "Diretório de busca não existe: $searchPath (ignorado)" "INFO"
    }
}

Write-SkillsLog "Total de skills candidatas localizadas: $($SkillsCandidatas.Count)" "INFO"

$ResultadosSkills = @()
$SkillsValidasCount = 0
$SkillsComAvisosCount = 0
$SkillsRiscoAltoCount = 0
$SomaScores = 0

# 4. Processamento e Validação de cada Skill
foreach ($candidate in $SkillsCandidatas) {
    $folder = $candidate.Folder
    $skillMd = $candidate.SkillMd
    $source = $candidate.Source
    
    Write-SkillsLog "Processando e validando skill: $($folder.Name) ..." "INFO"
    
    $errors = @()
    $warnings = @()
    $riskLevel = "low"
    $score = 0
    $hasScripts = $false
    $hasReferences = $false
    $hasTemplates = $false
    $hasAssets = $false
    $hasTests = $false
    
    # Checa acessibilidade da pasta
    $folderAccessible = Test-Path $folder.FullName
    
    # SKILL.md existe e tamanho
    $skillMdExists = Test-Path $skillMd
    $skillMdLength = 0
    $yamlValid = $false
    $name = $folder.Name
    $description = ""
    
    if ($skillMdExists) {
        $fileInfo = Get-Item $skillMd
        $skillMdLength = $fileInfo.Length
        
        if ($skillMdLength -eq 0) {
            $errors += "O arquivo SKILL.md está vazio (0 bytes)."
        } else {
            $content = Get-Content $skillMd -Raw -Encoding utf8
            
            # Validação do YAML Frontmatter
            if ($content -match '^---\r?\n([\s\S]*?)\r?\n---') {
                $frontmatter = $Matches[1]
                $yamlValid = $true
                
                # Parsing simples de name e description no YAML
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
            # Procura links relativos locais como [link](relPath)
            # Regex ignora links absolutos http/https, âncoras locais # e referências de e-mail
            $LinkRegex = '\[.*?\]\((?!https?:\/\/)(?!#)(?!mailto:)(.*?)\)'
            $MatchesLinks = [regex]::Matches($content, $LinkRegex)
            foreach ($match in $MatchesLinks) {
                $linkTargetRaw = $match.Groups[1].Value
                $linkTargetClean = ($linkTargetRaw -split '#' | Select-Object -First 1).Split('?') | Select-Object -First 1
                if (-not [string]::IsNullOrWhiteSpace($linkTargetClean)) {
                    # Corrige barras para barra invertida do Windows
                    $cleanTargetOs = $linkTargetClean.Replace('/', '\')
                    $linkFullPath = Join-Path $folder.FullName $cleanTargetOs
                    if (-not (Test-Path $linkFullPath)) {
                        $warnings += "Link local quebrado: '$linkTargetRaw' (arquivo não existe na pasta da skill)."
                    }
                }
            }
        }
    } else {
        $errors += "Arquivo SKILL.md não localizado no diretório da skill."
    }
    
    # Checa componentes opcionais na pasta
    $hasScripts = Test-Path (Join-Path $folder.FullName "scripts")
    $hasReferences = Test-Path (Join-Path $folder.FullName "references")
    $hasTemplates = Test-Path (Join-Path $folder.FullName "templates")
    $hasAssets = Test-Path (Join-Path $folder.FullName "assets")
    $hasTests = Test-Path (Join-Path $folder.FullName "tests")
    
    # Análise Estática de Segurança (Heurística sem execução de scripts)
    $dangerAlerts = @()
    
    # Arquivos a escanear recursivamente na pasta da skill
    $allFiles = Get-ChildItem -Path $folder.FullName -File -Recurse -ErrorAction SilentlyContinue
    foreach ($f in $allFiles) {
        # Apenas arquivos de texto ou código comuns
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
                        # Apenas alerta se for acompanhado por execuções
                        if ($fContent -match 'iex' -or $fContent -match 'Invoke-Expression') {
                            $dangerAlerts += "Download e execução remota de scripts em $($f.Name)"
                        } else {
                            $warnings += "Acesso de rede identificado (download/rest) em $($f.Name)."
                        }
                    }
                }
            } catch {
                # Ignora erros de leitura de arquivos bloqueados
            }
        }
    }
    
    foreach ($alert in $dangerAlerts) {
        $warnings += "ALERTA CRÍTICO DE SEGURANÇA: $alert"
    }
    
    # 5. Cálculo do Score Estrutural (0 a 100)
    if ($skillMdExists) { $score += 20 }
    if ($yamlValid) { $score += 15 }
    if ($name -and $name -ne $folder.Name) { $score += 10 } elseif ($name) { $score += 5 }
    if ($description) { $score += 10 }
    
    # Se não houver warnings de links quebrados
    $brokenLinks = $warnings | Where-Object { $_ -match 'Link local quebrado' }
    if ($brokenLinks.Count -eq 0) { $score += 15 }
    
    # Documentação suficiente (corpo de SKILL.md > 150 caracteres)
    if ($skillMdExists -and $skillMdLength -gt 150) { $score += 10 }
    
    # Testes presentes
    if ($hasTests) { $score += 10 }
    
    # Ausência de alertas críticos
    if ($dangerAlerts.Count -eq 0) { $score += 10 }
    
    # 6. Atribuição do Nível de Risco
    if ($dangerAlerts.Count -gt 0) {
        $riskLevel = "high"
        $SkillsRiscoAltoCount++
    } elseif ($errors.Count -gt 0 -or $warnings.Count -gt 0) {
        $riskLevel = "medium"
    } else {
        $riskLevel = "low"
    }
    
    # Atualiza contadores
    if ($errors.Count -eq 0) {
        $SkillsValidasCount++
    }
    if ($warnings.Count -gt 0) {
        $SkillsComAvisosCount++
    }
    $SomaScores += $score
    
    # Adiciona ao inventário
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

# Estatísticas Gerais
$TotalSkills = $ResultadosSkills.Count
$MediaScore = if ($TotalSkills -gt 0) { [Math]::Round($SomaScores / $TotalSkills, 1) } else { 0 }

# 7. Gravação das Saídas do Sistema

# A. Gravação de data/skills.json
$JsonPath = Join-Path $DataDir "skills.json"
$JsonContent = ConvertTo-Json -InputObject $ResultadosSkills -Depth 5
$JsonContent | Set-Content -Path $JsonPath -Encoding utf8
Write-SkillsLog "Arquivo data/skills.json gravado com sucesso." "INFO"

# B. Gravação de dashboard/skills-data.js
$JsSkillsPath = Join-Path $DashboardDir "skills-data.js"
$PayloadJs = [PSCustomObject]@{
    scannedAt = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    skills = $ResultadosSkills
    summary = [PSCustomObject]@{
        totalCount = $TotalSkills
        validCount = $SkillsValidasCount
        warningCount = $SkillsComAvisosCount
        highRiskCount = $SkillsRiscoAltoCount
        averageScore = $MediaScore
    }
}
$JsContent = "window.HERMES_SKILLS_DATA = " + (ConvertTo-Json -InputObject $PayloadJs -Depth 5) + ";"
$JsContent | Set-Content -Path $JsSkillsPath -Encoding utf8
Write-SkillsLog "Arquivo dashboard/skills-data.js gravado com sucesso." "INFO"

# C. Geração de data/skills.md
$MdPath = Join-Path $DataDir "skills.md"
$Md = @()
$Md += "# Hermes Agent Skills Inventory"
$Md += ""
$Md += "Última verificação: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")"
$Md += ""
$Md += "## Estatísticas de Skills"
$Md += ""
$Md += "*   **Total de Skills Encontradas:** $TotalSkills"
$Md += "*   **Skills Válidas (Sem erros estruturais):** $SkillsValidasCount"
$Md += "*   **Skills com Avisos/Alertas:** $SkillsComAvisosCount"
$Md += "*   **Skills de Alto Risco:** $SkillsRiscoAltoCount"
$Md += "*   **Média do Score de Qualidade:** $MediaScore / 100"
$Md += ""
$Md += "## Detalhes das Skills"
$Md += ""
$Md += "| Nome | Validade | Score | Risco | Scripts | Testes | Origem |"
$Md += "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"

foreach ($skill in $ResultadosSkills) {
    $validStr = if ($skill.valid) { "🟢 Válida" } else { "🔴 Inválida" }
    $riskStr = switch ($skill.riskLevel) {
        "high"   { "🔴 Alto" }
        "medium" { "🟡 Médio" }
        default  { "🟢 Baixo" }
    }
    $scriptsStr = if ($skill.hasScripts) { "Sim" } else { "Não" }
    $testsStr = if ($skill.hasTests) { "Sim" } else { "Não" }
    
    $Md += "| $($skill.name) | $validStr | $($skill.score) | $riskStr | $scriptsStr | $testsStr | $($skill.source) |"
}

$Md | Set-Content -Path $MdPath -Encoding utf8
Write-SkillsLog "Arquivo data/skills.md gravado com sucesso." "INFO"

$Duration = [Math]::Round(([DateTime]::UtcNow - $StartTime).TotalSeconds, 2)
Write-SkillsLog "Varredura de Skills concluída em $Duration segundos. Status Final: Sucesso." "INFO"
