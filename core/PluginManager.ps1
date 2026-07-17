# ==========================================
# PluginManager.ps1 — Gerenciador Mestre de Plugins
# ==========================================
# PowerShell 7+
# ==========================================

# Garante UTF-8 no console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$CoreDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($CoreDir) -and $null -ne $MyInvocation -and $null -ne $MyInvocation.MyCommand) {
    $CoreDir = Split-Path $MyInvocation.MyCommand.Path -Parent
}
if ([string]::IsNullOrWhiteSpace($CoreDir) -and $null -ne $MyInvocation -and -not [string]::IsNullOrWhiteSpace($MyInvocation.ScriptName)) {
    $CoreDir = Split-Path $MyInvocation.ScriptName -Parent
}
if ([string]::IsNullOrWhiteSpace($CoreDir)) {
    $CoreDir = Get-Location
}
$ProjectRoot = Split-Path $CoreDir -Parent

# Carrega módulos dependentes
. (Join-Path $CoreDir "PluginContracts.ps1")
. (Join-Path $CoreDir "PluginValidator.ps1")
. (Join-Path $CoreDir "PluginRunner.ps1")

function Invoke-HermesPluginManager {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath
    )
    
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "🔌 INICIALIZANDO GERENCIADOR DE PLUGINS HERMES" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuração 'config.json' não localizada no caminho especificado: $ConfigPath"
        return
    }
    
    # Carrega config.json
    $ConfigContent = Get-Content $ConfigPath -Raw -Encoding utf8
    $Config = ConvertFrom-Json $ConfigContent
    
    $PathsToSearch = $Config.pluginPaths
    if ($null -eq $PathsToSearch) {
        $PathsToSearch = @(".\plugins")
    }
    
    $EnabledPlugins = $Config.enabledPlugins
    if ($null -eq $EnabledPlugins) {
        $EnabledPlugins = @("agent-scanner")
    }
    
    $AllowThirdParty = $Config.allowThirdPartyPlugins
    if ($null -eq $AllowThirdParty) {
        $AllowThirdParty = $false
    }
    
    $PluginsList = @()
    $RegisteredIds = @{}
    
    $Summary = @{
        totalCount     = 0
        enabledCount   = 0
        disabledCount  = 0
        invalidCount   = 0
        lastRun        = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    }
    
    # 1. Varre pastas de pesquisa de plugins
    foreach ($searchPath in $PathsToSearch) {
        # Resolve caminhos relativos para absoluto
        $ResolvedSearchPath = Join-Path $ProjectRoot $searchPath
        if (-not (Test-Path $ResolvedSearchPath)) {
            Write-Host "⚠ Caminho de plugins não existe, ignorando: $ResolvedSearchPath" -ForegroundColor Yellow
            continue
        }
        
        $SubDirs = Get-ChildItem $ResolvedSearchPath -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $SubDirs) {
            # Se for pasta de exemplo e não estiver listada como permitida (hello-plugin, etc)
            if ($dir.Name -eq "examples" -or $dir.Parent.Name -eq "examples") {
                # O hello-plugin está dentro de examples/hello-plugin
                # Deixamos ser descoberto normalmente para validar o manifest
            }
            
            # Se for subdiretório de exemplo, varre as pastas dentro dele
            if ($dir.Name -eq "examples") {
                $ExamplesDirs = Get-ChildItem $dir.FullName -Directory -ErrorAction SilentlyContinue
                foreach ($exDir in $ExamplesDirs) {
                    $PluginsList += Process-PluginDirectory -PluginDir $exDir.FullName -EnabledList $EnabledPlugins -RegisteredIds $RegisteredIds -Summary $Summary
                }
            } else {
                $PluginsList += Process-PluginDirectory -PluginDir $dir.FullName -EnabledList $EnabledPlugins -RegisteredIds $RegisteredIds -Summary $Summary
            }
        }
    }
    
    # 2. Executa plugins habilitados e válidos
    $OutputsByCategory = @{}
    
    foreach ($plugin in $PluginsList) {
        if ($plugin.status -eq "enabled") {
            # Executa
            $PluginDir = $plugin.path
            $Entrypoint = $plugin.entrypoint
            
            $Output = Invoke-PluginEntrypoint -PluginDir $PluginDir -Entrypoint $Entrypoint -Config $Config
            
            # Atualiza status e coleta saídas
            $plugin.lastExecutionStatus = $Output.status
            $plugin.errors = $Output.errors
            $plugin.warnings = $Output.warnings
            
            if ($null -ne $Output) {
                $Category = $Output.category
                if (-not $OutputsByCategory.ContainsKey($Category)) {
                    $OutputsByCategory[$Category] = @()
                }
                $OutputsByCategory[$Category] += $Output
            }
        } else {
            $plugin.lastExecutionStatus = "not_run"
        }
    }
    
    # 3. Agrega resultados e gera arquivos de inventários
    Write-Host "`n📊 Agregando resultados dos plugins..." -ForegroundColor Yellow
    
    # --- PROCESSA CATEGORIA: AGENTS ---
    $AgentesAgregados = @()
    $AlertsAgregados = @()
    $ErrorsAgregados = @()
    
    if ($OutputsByCategory.ContainsKey("agents")) {
        foreach ($out in $OutputsByCategory["agents"]) {
            $AgentesAgregados += $out.items
            $AlertsAgregados += $out.warnings
            $ErrorsAgregados += $out.errors
        }
    }
    
    # Escreve data/agents.json se houver agentes agregados ou se o agent-scanner foi executado
    if ($OutputsByCategory.ContainsKey("agents") -or $EnabledPlugins -contains "agent-scanner") {
        $SummaryAgents = @{
            detectedCount = ($AgentesAgregados | Where-Object { $_.detected -eq $true }).Count
            runningCount  = ($AgentesAgregados | Where-Object { $_.running -eq $true }).Count
            notFoundCount = ($AgentesAgregados | Where-Object { $_.detected -eq $false }).Count
            alertsCount   = $AlertsAgregados.Count
            alerts        = $AlertsAgregados
        }
        
        $PayloadAgents = [PSCustomObject]@{
            scannedAt = $Summary.lastRun
            summary   = $SummaryAgents
            agents    = $AgentesAgregados
            latestLog = "Inventário gerado via plugins."
        }
        
        # Garante que o diretório data/ existe
        $DataDir = Join-Path $ProjectRoot "data"
        if (-not (Test-Path $DataDir)) {
            New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
        }
        
        # Salva data/agents.json
        $JsonFile = Join-Path $ProjectRoot "data\agents.json"
        $PayloadAgents | ConvertTo-Json -Depth 5 | Set-Content $JsonFile -Encoding utf8
        Write-Host "✔ Inventário de agentes salvo em data/agents.json (Total: $($AgentesAgregados.Count))" -ForegroundColor Green
        
        # Salva dashboard/data.js para o frontend anterior
        $JsFile = Join-Path $ProjectRoot "dashboard\data.js"
        $JsContent = "window.HERMES_DATA = " + ($PayloadAgents | ConvertTo-Json -Depth 5) + ";"
        $JsContent | Set-Content $JsFile -Encoding utf8
        
        # Salva data/agents.md
        $MdFile = Join-Path $ProjectRoot "data\agents.md"
        Generate-AgentsMarkdown -Agents $AgentesAgregados -Summary $SummaryAgents -ScannedAt $Summary.lastRun -OutPath $MdFile
    }
    
    # --- PROCESSA CATEGORIA: SKILLS ---
    $SkillsAgregados = @()
    $AlertsSkills = @()
    
    if ($OutputsByCategory.ContainsKey("skills")) {
        foreach ($out in $OutputsByCategory["skills"]) {
            $SkillsAgregados += $out.items
            $AlertsSkills += $out.warnings
        }
    }
    
    if ($OutputsByCategory.ContainsKey("skills") -or $EnabledPlugins -contains "skills-scanner") {
        $SummarySkills = @{
            totalCount    = $SkillsAgregados.Count
            validCount    = ($SkillsAgregados | Where-Object { $_.valid -eq $true }).Count
            warningCount  = ($SkillsAgregados | Where-Object { $_.warnings.Count -gt 0 }).Count
            highRiskCount = ($SkillsAgregados | Where-Object { $_.riskLevel -eq "high" }).Count
        }
        
        $PayloadSkills = [PSCustomObject]@{
            scannedAt = $Summary.lastRun
            summary   = $SummarySkills
            skills    = $SkillsAgregados
        }
        
        # Salva data/skills.json
        $SkillsJsonFile = Join-Path $ProjectRoot "data\skills.json"
        $PayloadSkills | ConvertTo-Json -Depth 5 | Set-Content $SkillsJsonFile -Encoding utf8
        Write-Host "✔ Inventário de skills salvo em data/skills.json (Total: $($SkillsAgregados.Count))" -ForegroundColor Green
        
        # Salva dashboard/skills-data.js
        $SkillsJsFile = Join-Path $ProjectRoot "dashboard\skills-data.js"
        $SkillsJsContent = "window.HERMES_SKILLS_DATA = " + ($PayloadSkills | ConvertTo-Json -Depth 5) + ";"
        $SkillsJsContent | Set-Content $SkillsJsFile -Encoding utf8
        
        # Salva data/skills.md
        $SkillsMdFile = Join-Path $ProjectRoot "data\skills.md"
        Generate-SkillsMarkdown -Skills $SkillsAgregados -Summary $SummarySkills -ScannedAt $Summary.lastRun -OutPath $SkillsMdFile
    }
    
    # 4. Gera dashboard/plugins-data.js contendo as informações de auditoria dos plugins
    $PayloadPlugins = [PSCustomObject]@{
        scannedAt = $Summary.lastRun
        summary   = $Summary
        plugins   = $PluginsList
    }
    
    $PluginsJsFile = Join-Path $ProjectRoot "dashboard\plugins-data.js"
    $PluginsJsContent = "window.HERMES_PLUGINS_DATA = " + ($PayloadPlugins | ConvertTo-Json -Depth 5) + ";"
    $PluginsJsContent | Set-Content $PluginsJsFile -Encoding utf8
    Write-Host "✔ Dados de metadados dos plugins salvos em dashboard/plugins-data.js" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    
    return $PayloadPlugins
}

# Processa pasta individual de plugin
function Process-PluginDirectory {
    param(
        [string]$PluginDir,
        [array]$EnabledList,
        [Hashtable]$RegisteredIds,
        [Hashtable]$Summary
    )
    
    if (-not (Test-Path (Join-Path $PluginDir "plugin.json"))) {
        return $null
    }
    
    $Summary.totalCount++
    
    # Valida
    $ValResult = Test-PluginManifest -PluginDir $PluginDir
    $Manifest = $ValResult.Manifest
    
    $PluginStatus = "disabled"
    $ValidationErrors = [System.Collections.Generic.List[string]]::new()
    if ($ValResult.Errors) {
        foreach ($err in $ValResult.Errors) {
            $ValidationErrors.Add($err)
        }
    }
    
    $PluginId = if ($Manifest) { $Manifest.id } else { Split-Path $PluginDir -Leaf }
    $DeclaredTrust = if ($Manifest -and $Manifest.trustLevel) { $Manifest.trustLevel } else { "untrusted" }
    
    # Determina nível de confiança efetivo externamente ao manifesto
    $EffectiveTrust = Get-EffectiveTrustLevel -PluginId $PluginId -ProjectRoot $ProjectRoot
    $TrustSource = switch ($EffectiveTrust) {
        "builtin" { "builtin" }
        "trusted" { "manual approval" }
        default   { "none" }
    }
    
    $IntegrityStatus = "unverified"
    $ApprovedAt = "---"
    $ApprovedVersion = "---"
    
    if ($ValResult.Valid) {
        # 1. Verifica ID duplicado
        if ($RegisteredIds.ContainsKey($PluginId)) {
            $ValidationErrors.Add("ID do plugin duplicado: '$PluginId' já foi registrado por outro diretório.")
            $PluginStatus = "invalid"
        } else {
            $RegisteredIds[$PluginId] = $PluginDir
            
            # 2. Verifica se está na lista de habilitados e ativo no manifesto
            if ($EnabledList -contains $PluginId -and $Manifest.enabled) {
                $PluginStatus = "enabled"
            } else {
                $PluginStatus = "disabled"
            }
        }
    } else {
        $PluginStatus = "invalid"
    }
    
    # 3. Verifica integridade e segurança de builtin e trusted
    if ($EffectiveTrust -eq "builtin" -or $EffectiveTrust -eq "trusted") {
        $IntegrityResult = Test-PluginIntegrity -PluginId $PluginId -PluginDir $PluginDir -EffectiveTrustLevel $EffectiveTrust -ProjectRoot $ProjectRoot
        $IntegrityStatus = $IntegrityResult.Status
        if ($IntegrityResult.Status -ne "valid") {
            foreach ($err in $IntegrityResult.Errors) {
                $ValidationErrors.Add($err)
            }
        }
        
        # Tenta carregar metadados da baseline de integridade correspondente
        $IntegrityStorePath = if ($EffectiveTrust -eq "builtin") {
            Join-Path $ProjectRoot "config\builtin-integrity.json"
        } else {
            Join-Path $ProjectRoot "data\trusted-integrity.json"
        }
        
        if (Test-Path $IntegrityStorePath) {
            try {
                $StoreJson = Get-Content $IntegrityStorePath -Raw -Encoding utf8
                $Store = ConvertFrom-Json $StoreJson
                $Record = $Store.$PluginId
                if ($Record) {
                    $ApprovedAt = $Record.approvedAt
                    $ApprovedVersion = $Record.version
                }
            } catch {}
        }
    } else {
        # Se for untrusted, bloqueia terminantemente e gera erro
        $ValidationErrors.Add("Plugin bloqueado: Nível de confiança efetivo é untrusted (requer aprovação manual via Approve-HermesPlugin.ps1).")
    }
    
    # Se houver erros acumulados de integridade ou trustLevel, reclassifica para invalid
    if ($ValidationErrors.Count -gt 0) {
        $PluginStatus = "invalid"
    }
    
    # Atualiza contadores globais do Manager de forma coerente
    switch ($PluginStatus) {
        "enabled"  { $Summary.enabledCount++ }
        "disabled" { $Summary.disabledCount++ }
        "invalid"  { $Summary.invalidCount++ }
    }
    
    return [PSCustomObject]@{
        id                   = $PluginId
        name                 = if ($Manifest) { $Manifest.name } else { Split-Path $PluginDir -Leaf }
        version              = if ($Manifest) { $Manifest.version } else { "---" }
        author               = if ($Manifest) { $Manifest.author } else { "---" }
        description          = if ($Manifest) { $Manifest.description } else { "---" }
        category             = if ($Manifest) { $Manifest.category } else { "---" }
        entrypoint           = if ($Manifest) { $Manifest.entrypoint } else { "" }
        path                 = $PluginDir
        status               = $PluginStatus
        permissions          = if ($Manifest) { $Manifest.permissions } else { @() }
        declaredTrust        = $DeclaredTrust
        effectiveTrust       = $EffectiveTrust
        trustSource          = $TrustSource
        integrityStatus      = $IntegrityStatus
        approvedAt           = $ApprovedAt
        approvedVersion      = $ApprovedVersion
        validationErrors     = @($ValidationErrors)
        warnings             = @()
        errors               = @()
        lastExecutionStatus  = "not_run"
    }
}

# Funções auxiliares de geração de Markdown para agentes e skills
function Generate-AgentsMarkdown {
    param($Agents, $Summary, $ScannedAt, $OutPath)
    
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Inventário de Agentes e Ferramentas IA")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Última varredura: $ScannedAt")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Resumo")
    [void]$sb.AppendLine("*   **Instalados:** $($Summary.detectedCount)")
    [void]$sb.AppendLine("*   **Em Execução:** $($Summary.runningCount)")
    [void]$sb.AppendLine("*   **Ausentes:** $($Summary.notFoundCount)")
    [void]$sb.AppendLine("*   **Avisos:** $($Summary.alertsCount)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Tabela de Detecção")
    [void]$sb.AppendLine("| Agente/Ferramenta | Status | Versão | Categoria | Caminho de Instalação |")
    [void]$sb.AppendLine("| :--- | :--- | :--- | :--- | :--- |")
    
    foreach ($a in $Agents) {
        $statusStr = if ($a.detected) { if ($a.running) { "Executando" } else { "Instalado" } } else { "Ausente" }
        [void]$sb.AppendLine("| **$($a.name)** | $statusStr | $($a.version) | $($a.category) | ``$($a.installPath)`` |")
    }
    
    $sb.ToString() | Set-Content $OutPath -Encoding utf8
}

function Generate-SkillsMarkdown {
    param($Skills, $Summary, $ScannedAt, $OutPath)
    
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Inventário de Agent Skills")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Última varredura: $ScannedAt")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Resumo de Conformidade")
    [void]$sb.AppendLine("*   **Total de Skills:** $($Summary.totalCount)")
    [void]$sb.AppendLine("*   **Válidas:** $($Summary.validCount)")
    [void]$sb.AppendLine("*   **Com Avisos:** $($Summary.warningCount)")
    [void]$sb.AppendLine("*   **Risco Alto:** $($Summary.highRiskCount)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Tabela de Skills")
    [void]$sb.AppendLine("| Nome da Skill | Validade | Score | Risco | Caminho de Origem |")
    [void]$sb.AppendLine("| :--- | :--- | :--- | :--- | :--- |")
    
    foreach ($s in $Skills) {
        $validStr = if ($s.valid) { "Válida" } else { "Inválida" }
        [void]$sb.AppendLine("| **$($s.name)** | $validStr | $($s.score)/100 | $($s.riskLevel) | ``$($s.path)`` |")
    }
    
    $sb.ToString() | Set-Content $OutPath -Encoding utf8
}
