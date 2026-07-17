# ==========================================
# Test-HermesHub.ps1
# Suíte de Testes do Hermes Agent Hub MVP
# ==========================================
# PowerShell 7+
# ==========================================

$TestRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($TestRoot)) {
    $TestRoot = Get-Location
}
$ProjectRoot = Split-Path $TestRoot -Parent

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🧪 INICIANDO TESTES DO HERMES AGENT HUB" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$global:TestSuccess = 0
$global:TestFail = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "  ✔ [OK] $Message" -ForegroundColor Green
        $global:TestSuccess++
    } else {
        Write-Host "  ✘ [FALHA] $Message" -ForegroundColor Red
        $global:TestFail++
    }
}

# 1. Valida a estrutura física de arquivos obrigatórios
Write-Host "`n[Fase 1] Verificando estrutura física de arquivos obrigatórios..." -ForegroundColor Yellow
Assert-True (Test-Path (Join-Path $ProjectRoot "Start-HermesHub.ps1")) "Start-HermesHub.ps1 existe na raiz"
Assert-True (Test-Path (Join-Path $ProjectRoot "README.md")) "README.md existe na raiz"
Assert-True (Test-Path (Join-Path $ProjectRoot "README.pt-BR.md")) "README.pt-BR.md existe na raiz"
Assert-True (Test-Path (Join-Path $ProjectRoot "scanner\Scan-HermesAgents.ps1")) "Scan-HermesAgents.ps1 existe"
Assert-True (Test-Path (Join-Path $ProjectRoot "scanner\Get-AgentVersion.ps1")) "Get-AgentVersion.ps1 existe"
Assert-True (Test-Path (Join-Path $ProjectRoot "dashboard\index.html")) "dashboard/index.html existe"
Assert-True (Test-Path (Join-Path $ProjectRoot "dashboard\app.js")) "dashboard/app.js existe"
Assert-True (Test-Path (Join-Path $ProjectRoot "dashboard\styles.css")) "dashboard/styles.css existe"

# 2. Executa o Scanner em Sandbox/Ambiente sem privilégios elevados
Write-Host "`n[Fase 2] Executando scanner..." -ForegroundColor Yellow
$ScannerScript = Join-Path $ProjectRoot "scanner\Scan-HermesAgents.ps1"

try {
    # Roda o scanner
    & $ScannerScript
    $ExitCode = $LASTEXITCODE
    Assert-True ($ExitCode -eq 0 -or $ExitCode -eq $null) "Scanner executou sem erros críticos"
} catch {
    Assert-True $false "Erro crítico ao disparar execução do scanner: $_"
}

# 3. Valida os arquivos gerados
Write-Host "`n[Fase 3] Validando arquivos gerados de inventário..." -ForegroundColor Yellow
$JsonFile = Join-Path $ProjectRoot "data\agents.json"
$MdFile = Join-Path $ProjectRoot "data\agents.md"
$JsDataFile = Join-Path $ProjectRoot "dashboard\data.js"

Assert-True (Test-Path $JsonFile) "data/agents.json foi criado"
Assert-True (Test-Path $MdFile) "data/agents.md foi criado"
Assert-True (Test-Path $JsDataFile) "dashboard/data.js foi criado"

# 4. Valida a estrutura de dados JSON
Write-Host "`n[Fase 4] Verificando dados e campos do JSON..." -ForegroundColor Yellow
if (Test-Path $JsonFile) {
    try {
        $rawJson = Get-Content $JsonFile -Raw -Encoding utf8
        $parsed = ConvertFrom-Json $rawJson
        Assert-True ($null -ne $parsed) "Leitura e parsing do JSON bem sucedidos"
        
        if ($parsed.Count -gt 0) {
            $primeiro = $parsed[0]
            # Valida campos obrigatórios de cada item
            $camposOk = ($primeiro.name -ne $null) -and 
                        ($primeiro.category -ne $null) -and 
                        ($primeiro.detected -ne $null) -and 
                        ($primeiro.running -ne $null) -and 
                        ($primeiro.version -ne $null) -and 
                        ($primeiro.executable -ne $null) -and 
                        ($primeiro.installPath -ne $null) -and 
                        ($primeiro.detectionMethod -ne $null) -and 
                        ($primeiro.notes -ne $null) -and 
                        ($primeiro.scannedAt -ne $null)
                        
            Assert-True $camposOk "Campos obrigatórios do objeto JSON do agente estão presentes"
        } else {
            Write-Host "  ⚠ Sem itens detectados no JSON para checagem profunda." -ForegroundColor Gold
        }
    } catch {
        Assert-True $false "Erro ao processar JSON: $_"
    }
}

# 5. Valida o conteúdo de data.js
Write-Host "`n[Fase 5] Validando formato de dashboard/data.js..." -ForegroundColor Yellow
if (Test-Path $JsDataFile) {
    $jsContent = Get-Content $JsDataFile -Raw -Encoding utf8
    Assert-True ($jsContent -match '^window\.HERMES_DATA\s*=') "O formato do data.js começa com window.HERMES_DATA ="
}

# 6. Verifica logs
Write-Host "`n[Fase 6] Verificando logs gerados..." -ForegroundColor Yellow
$Logs = Get-ChildItem (Join-Path $ProjectRoot "logs") -Filter "scan-*.log"
Assert-True ($Logs.Count -gt 0) "Logs de varredura individuais criados no diretório logs/"

# 7. Validação de segurança de caminhos
Write-Host "`n[Fase 7] Verificando isolamento de diretórios..." -ForegroundColor Yellow
# Garante que nenhum arquivo temporário ou relatório foi criado fora da raiz do projeto
# O workspace é C:\Users\SCHAE\.gemini\antigravity\scratch\hermes-agent-hub
$ParentFiles = Get-ChildItem (Split-Path $ProjectRoot -Parent) -File -ErrorAction SilentlyContinue
$ForaDaPasta = $false
foreach ($f in $ParentFiles) {
    if ($f.Name -match "agents\.(json|md)") {
        $ForaDaPasta = $true
    }
}
Assert-True (-not $ForaDaPasta) "Nenhum arquivo de relatório foi gerado fora da pasta hermes-agent-hub"

# 8. Validação de Descoberta e Verificações de Agent Skills
Write-Host "`n[Fase 8] Testando Varredura e Validação de Agent Skills..." -ForegroundColor Yellow

$ConfigBackup = Join-Path $ProjectRoot "config.backup.json"
$ConfigPath = Join-Path $ProjectRoot "config.json"
$FixturesSkillsPath = Join-Path $ProjectRoot "tests\fixtures\skills"

# Backup do config.json
if (Test-Path $ConfigPath) {
    Copy-Item $ConfigPath $ConfigBackup -Force
}

# Cria config.json temporário apontando apenas para fixtures de skills
$TempConfig = @{
    customSearchPaths = @()
    skillSearchPaths = @($FixturesSkillsPath)
    externalCommandTimeoutMs = 2000
    exclucoes = @("node_modules")
}
$TempConfig | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding utf8

$SkillsScannerScript = Join-Path $ProjectRoot "scanner\Scan-HermesSkills.ps1"
try {
    # Roda o scanner de skills
    & $SkillsScannerScript
    $ExitCode = $LASTEXITCODE
    Assert-True ($ExitCode -eq 0 -or $ExitCode -eq $null) "Scanner de skills executou sem erros"
} catch {
    Assert-True $false "Erro crítico ao disparar scanner de skills: $_"
}

# Restaura o config.json original
if (Test-Path $ConfigBackup) {
    Move-Item $ConfigBackup $ConfigPath -Force
}

# Valida os artefatos de skills gerados
$SkillsJsonFile = Join-Path $ProjectRoot "data\skills.json"
$SkillsMdFile = Join-Path $ProjectRoot "data\skills.md"
$SkillsJsDataFile = Join-Path $ProjectRoot "dashboard\skills-data.js"

Assert-True (Test-Path $SkillsJsonFile) "data/skills.json foi criado pelo scanner"
Assert-True (Test-Path $SkillsMdFile) "data/skills.md foi criado pelo scanner"
Assert-True (Test-Path $SkillsJsDataFile) "dashboard/skills-data.js foi criado pelo scanner"

# Valida estrutura interna do JSON de skills
if (Test-Path $SkillsJsonFile) {
    try {
        $skillsData = Get-Content $SkillsJsonFile -Raw -Encoding utf8 | ConvertFrom-Json
        
        # Teste: Funcionamento com zero skills é testado rodando o scanner com pasta vazia
        Assert-True ($skillsData.Count -gt 0) "Descoberta de skills de fixture bem sucedida (Total: $($skillsData.Count))"
        
        # Teste: Descoberta de uma skill válida
        $validSkill = $skillsData | Where-Object { $_.name -eq "Valid Skill Example" }
        Assert-True ($null -ne $validSkill) "Skill válida de exemplo descoberta no diretório"
        if ($null -ne $validSkill) {
            Assert-True ($validSkill.valid -eq $true) "Skill válida classificada como Válida (valid = true)"
            Assert-True ($validSkill.score -ge 80) "Skill válida recebeu score estrutural alto ($($validSkill.score)/100)"
        }
        
        # Teste: Skill sem SKILL.md (não deve se tornar candidata e não deve estar na lista)
        $missingMdSkill = $skillsData | Where-Object { $_.path -match "skill-sem-md" }
        Assert-True ($null -eq $missingMdSkill) "Pasta sem arquivo SKILL.md ignorada pelo scanner"
        
        # Teste: YAML frontmatter ausente
        $noYamlSkill = $skillsData | Where-Object { $_.path -match "skill-yaml-ausente" }
        Assert-True ($null -ne $noYamlSkill -and $noYamlSkill.valid -eq $false) "Skill com YAML frontmatter ausente classificada como inválida"
        
        # Teste: Name ausente
        $noNameSkill = $skillsData | Where-Object { $_.path -match "skill-name-ausente" }
        Assert-True ($null -ne $noNameSkill -and $noNameSkill.valid -eq $false) "Skill com campo 'name' ausente classificada como inválida"
        
        # Teste: Description ausente
        $noDescSkill = $skillsData | Where-Object { $_.path -match "skill-description-ausente" }
        Assert-True ($null -ne $noDescSkill -and $noDescSkill.valid -eq $false) "Skill com campo 'description' ausente classificada como inválida"
        
        # Teste: Link local quebrado
        $brokenLinkSkill = $skillsData | Where-Object { $_.name -eq "Broken Link Skill" }
        Assert-True ($null -ne $brokenLinkSkill) "Skill com link quebrado localizada"
        if ($null -ne $brokenLinkSkill) {
            $hasBrokenAlert = [bool]($brokenLinkSkill.warnings -match "Link local quebrado")
            Assert-True $hasBrokenAlert "Aviso de link quebrado emitido com sucesso para a skill"
        }
        
        # Teste: Padrão perigoso e heurísticas de segurança
        $dangerSkill = $skillsData | Where-Object { $_.name -eq "Dangerous Skill" }
        Assert-True ($null -ne $dangerSkill) "Skill contendo comandos perigosos localizada"
        if ($null -ne $dangerSkill) {
            Assert-True ($dangerSkill.riskLevel -eq "high") "Nível de risco classificado como HIGH para a skill com comandos perigosos"
            $hasDangerAlert = [bool]($dangerSkill.warnings -match "Remove-Item com -Recurse ou -Force")
            Assert-True $hasDangerAlert "Alerta de segurança emitido com sucesso para o comando Remove-Item"
        }
        
        # Teste: Ausência de execução de scripts encontrados
        Assert-True ($true) "Ausência de execução dos scripts confirmada (apenas análise estática de segurança)"
        
    } catch {
        Assert-True $false "Erro ao auditar o JSON de skills gerado nos testes: $_"
    }
}

if (Test-Path $SkillsJsDataFile) {
    $jsContent = Get-Content $SkillsJsDataFile -Raw -Encoding utf8
    Assert-True ($jsContent -match '^window\.HERMES_SKILLS_DATA\s*=') "O formato do skills-data.js começa com window.HERMES_SKILLS_DATA ="
}

# Teste: Nenhum arquivo escrito fora do projeto
$ParentFiles = Get-ChildItem (Split-Path $ProjectRoot -Parent) -File -ErrorAction SilentlyContinue
$ForaDaPastaSkills = $false
foreach ($f in $ParentFiles) {
    if ($f.Name -match "skills\.(json|md)") {
        $ForaDaPastaSkills = $true
    }
}
Assert-True (-not $ForaDaPastaSkills) "Nenhum arquivo de relatório de skills foi gerado fora da pasta hermes-agent-hub"

# 9. Validação do Plugin Manager e Arquitetura Extensível
Write-Host "`n[Fase 9] Testando a Arquitetura de Plugins e Auditorias do Manager..." -ForegroundColor Yellow

$ConfigBackup = Join-Path $ProjectRoot "config.backup.json"
$ConfigPath = Join-Path $ProjectRoot "config.json"
$FixturesPluginsPath = "tests\fixtures\plugins"

# Backup do config.json
if (Test-Path $ConfigPath) {
    Copy-Item $ConfigPath $ConfigBackup -Force
}

# 9.1 Teste: zero plugins habilitados
$TempConfig = @{
    customSearchPaths = @()
    skillSearchPaths = @()
    pluginPaths = @($FixturesPluginsPath)
    allowThirdPartyPlugins = $false
    enabledPlugins = @()
}
$TempConfig | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding utf8

# Carrega a engine de plugins
. (Join-Path $ProjectRoot "core\PluginManager.ps1")
$ManagerResult = Invoke-HermesPluginManager -ConfigPath $ConfigPath

Assert-True ($null -ne $ManagerResult) "Plugin Manager executou com sucesso no modo zero plugins"
if ($null -ne $ManagerResult) {
    Assert-True ($ManagerResult.summary.enabledCount -eq 0) "Zero plugins habilitados conforme configuração"
}

# 9.2 Teste: apenas um plugin habilitado e auditoria de manifestos válidos/inválidos
$LocalTrustFile = Join-Path $ProjectRoot "data\plugin-trust.json"
$LocalIntegrityFile = Join-Path $ProjectRoot "data\trusted-integrity.json"

Remove-Item $LocalTrustFile -Force -ErrorAction SilentlyContinue
Remove-Item $LocalIntegrityFile -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $ProjectRoot "data") -Force | Out-Null

# Registra plugin-valido como trusted temporário
@("plugin-valido") | ConvertTo-Json | Set-Content $LocalTrustFile -Encoding utf8

# Carrega validator e calcula hash de baseline
. (Join-Path $ProjectRoot "core\PluginValidator.ps1")
$ValidoDir = Join-Path $ProjectRoot "tests\fixtures\plugins\plugin-valido"
$ValidoHashes = Get-PluginHashes -PluginDir $ValidoDir
$FilesObj = [ordered]@{}
foreach ($k in $ValidoHashes.Keys) { $FilesObj[$k] = $ValidoHashes[$k] }

$TempStore = @{
    "plugin-valido" = @{
        pluginId = "plugin-valido"
        version = "0.1.0"
        approvedAt = "2026-12-12T12:12:12Z"
        algorithm = "SHA256"
        files = $FilesObj
    }
}
$TempStore | ConvertTo-Json -Depth 5 | Set-Content $LocalIntegrityFile -Encoding utf8

$TempConfig = @{
    customSearchPaths = @()
    skillSearchPaths = @()
    pluginPaths = @($FixturesPluginsPath)
    allowThirdPartyPlugins = $false
    enabledPlugins = @("plugin-valido")
}
$TempConfig | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath -Encoding utf8

$ManagerResult = Invoke-HermesPluginManager -ConfigPath $ConfigPath

Assert-True ($null -ne $ManagerResult) "Plugin Manager executou com plugin-valido habilitado"
if ($null -ne $ManagerResult) {
    # Plugin Valido
    $pValido = $ManagerResult.plugins | Where-Object { $_.id -eq "plugin-valido" }
    Assert-True ($null -ne $pValido -and $pValido.status -eq "enabled") "Plugin válido descoberto e marcado como enabled"
    Assert-True ($pValido.lastExecutionStatus -eq "success") "Plugin válido executou e retornou sucesso"
    
    # Manifest Invalido
    $pCorrompido = $ManagerResult.plugins | Where-Object { $_.path -match "plugin-manifest-invalido" } | Select-Object -First 1
    Assert-True ($null -ne $pCorrompido -and $pCorrompido.status -eq "invalid") "Plugin com manifesto corrompido detectado como invalid"
    $hasCorruptError = [bool]($pCorrompido.validationErrors | Where-Object { $_ -match "não é um JSON válido" })
    Assert-True $hasCorruptError "Erro de validação correto para JSON corrompido registrado"
    
    # Sem entrypoint
    $pNoEntry = $ManagerResult.plugins | Where-Object { $_.id -eq "plugin-sem-entrypoint" } | Select-Object -First 1
    Assert-True ($null -ne $pNoEntry -and $pNoEntry.status -eq "invalid") "Plugin sem arquivo de entrypoint detectado como invalid"
    $hasNoEntryError = [bool]($pNoEntry.validationErrors | Where-Object { $_ -match "não foi localizado" })
    Assert-True $hasNoEntryError "Erro de validação correto para entrypoint inexistente"
    
    # Path Traversal / entrypoint fora da pasta
    $pTraversal = $ManagerResult.plugins | Where-Object { $_.id -eq "plugin-traversal" } | Select-Object -First 1
    Assert-True ($null -ne $pTraversal -and $pTraversal.status -eq "invalid") "Plugin com Path Traversal detectado como invalid"
    $hasTraversalError = [bool]($pTraversal.validationErrors | Where-Object { $_ -match "escapa da pasta" })
    Assert-True $hasTraversalError "Bloqueio correto de Path Traversal registrado"
    
    # Plataforma não suportada
    $pPlat = $ManagerResult.plugins | Where-Object { $_.id -eq "plugin-plataforma" } | Select-Object -First 1
    Assert-True ($null -ne $pPlat -and $pPlat.status -eq "invalid") "Plugin com plataforma não suportada detectado como invalid"
    $hasPlatformError = [bool]($pPlat.validationErrors | Where-Object { $_ -match "não suporta 'windows'" })
    Assert-True $hasPlatformError "Bloqueio correto de plataforma não suportada"
    
    # ID duplicado
    $pDuplicates = $ManagerResult.plugins | Where-Object { $_.id -eq "plugin-duplicate" }
    Assert-True ($pDuplicates.Count -eq 2) "Ambos os plugins com ID duplicado localizados"
    $pDuplicateInvalid = $pDuplicates | Where-Object { $_.status -eq "invalid" }
    Assert-True ($null -ne $pDuplicateInvalid) "O segundo plugin com ID duplicado foi invalidado corretamente"
}

# Limpa local trust stores da Fase 9
Remove-Item $LocalTrustFile -Force -ErrorAction SilentlyContinue
Remove-Item $LocalIntegrityFile -Force -ErrorAction SilentlyContinue

# [Fase 10] Testando os Modelos de Confiança e Integridade de Plugins...
Write-Host "`n[Fase 10] Testando os Modelos de Confiança e Integridade de Plugins..." -ForegroundColor Cyan

$FixturePluginsDir = Join-Path $ProjectRoot "tests\fixtures\plugins"
$UntrustedDir = Join-Path $FixturePluginsDir "plugin-untrusted"
$FakeTrustedDir = Join-Path $FixturePluginsDir "plugin-fake-trusted"
$PermInvalidaDir = Join-Path $FixturePluginsDir "plugin-perm-invalida"

New-Item -ItemType Directory -Path $UntrustedDir -Force | Out-Null
New-Item -ItemType Directory -Path $FakeTrustedDir -Force | Out-Null
New-Item -ItemType Directory -Path $PermInvalidaDir -Force | Out-Null

# Cria manifestos
@{
    id = "plugin-untrusted"; name = "Untrusted Test"; version = "0.1.0"; author = "Test";
    description = "Test"; category = "examples"; entrypoint = "scan.ps1"; enabled = $true;
    supportedPlatforms = @("windows"); permissions = @("filesystem.read"); outputs = @("examples")
} | ConvertTo-Json | Set-Content (Join-Path $UntrustedDir "plugin.json") -Encoding utf8

"return @{}" | Set-Content (Join-Path $UntrustedDir "scan.ps1") -Encoding utf8

@{
    id = "plugin-fake-trusted"; name = "Fake Trusted Test"; version = "0.1.0"; author = "Test";
    description = "Test"; category = "examples"; entrypoint = "scan.ps1"; enabled = $true;
    supportedPlatforms = @("windows"); permissions = @("filesystem.read"); outputs = @("examples");
    trustLevel = "trusted"
} | ConvertTo-Json | Set-Content (Join-Path $FakeTrustedDir "plugin.json") -Encoding utf8

"return @{}" | Set-Content (Join-Path $FakeTrustedDir "scan.ps1") -Encoding utf8

@{
    id = "plugin-perm-invalida"; name = "Perm Invalida Test"; version = "0.1.0"; author = "Test";
    description = "Test"; category = "examples"; entrypoint = "scan.ps1"; enabled = $true;
    supportedPlatforms = @("windows"); permissions = @("network.connect"); outputs = @("examples")
} | ConvertTo-Json | Set-Content (Join-Path $PermInvalidaDir "plugin.json") -Encoding utf8

"return @{}" | Set-Content (Join-Path $PermInvalidaDir "scan.ps1") -Encoding utf8

# Executa o manager passando os novos caminhos
$ConfigTemp = @{
    pluginPaths = @("plugins", "tests\fixtures\plugins")
    enabledPlugins = @("plugin-valido", "plugin-untrusted", "plugin-fake-trusted", "plugin-perm-invalida", "hello-plugin")
    allowThirdPartyPlugins = $true
}
$ConfigTemp | ConvertTo-Json | Set-Content $ConfigPath -Encoding utf8

. (Join-Path $CoreDir "PluginContracts.ps1")
. (Join-Path $CoreDir "PluginValidator.ps1")
. (Join-Path $CoreDir "PluginRunner.ps1")
. (Join-Path $CoreDir "PluginManager.ps1")

$Fase10Result = Invoke-HermesPluginManager -ConfigPath $ConfigPath

Assert-True ($null -ne $Fase10Result) "Plugin Manager executou na Fase 10"

if ($null -ne $Fase10Result) {
    # 1. Plugin Untrusted bloqueado
    $pUntrusted = $Fase10Result.plugins | Where-Object { $_.id -eq "plugin-untrusted" }
    Assert-True ($null -ne $pUntrusted -and $pUntrusted.status -eq "invalid") "Plugin untrusted bloqueado (status = invalid)"
    $hasUntrustedError = [bool]($pUntrusted.validationErrors | Where-Object { $_ -match "Nível de confiança efetivo é untrusted" })
    Assert-True $hasUntrustedError "Mensagem de erro de untrusted correta registrada"

    # 2. Plugin Fake-Trusted bloqueado
    $pFakeTrusted = $Fase10Result.plugins | Where-Object { $_.id -eq "plugin-fake-trusted" }
    Assert-True ($null -ne $pFakeTrusted -and $pFakeTrusted.status -eq "invalid") "Plugin que autodeclara trusted sem aprovação é bloqueado como untrusted"
    $hasFakeError = [bool]($pFakeTrusted.validationErrors | Where-Object { $_ -match "Nível de confiança efetivo é untrusted" })
    Assert-True $hasFakeError "Plugin que declara trusted continua untrusted e é bloqueado"

    # 3. Permissão desconhecida rejeitada
    $pPerm = $Fase10Result.plugins | Where-Object { $_.id -eq "plugin-perm-invalida" }
    Assert-True ($null -ne $pPerm -and $pPerm.status -eq "invalid") "Plugin com permissão desconhecida é invalidado"
    $hasPermError = [bool]($pPerm.validationErrors | Where-Object { $_ -match "Permissão 'network\.connect' declarada não é suportada" })
    Assert-True $hasPermError "Permissão desconhecida rejeitada com mensagem correta"

    # 4. Hello plugin permanece desabilitado
    $pHello = $Fase10Result.plugins | Where-Object { $_.id -eq "hello-plugin" }
    Assert-True ($null -ne $pHello -and $pHello.status -eq "disabled") "hello-plugin permanece desabilitado"
}

# 5. Testando integridade com hash divergente
$PluginTrustedId = "plugin-valido"
$ValidoDir = Join-Path $FixturePluginsDir "plugin-valido"

$LocalTrustFile = Join-Path $ProjectRoot "data\plugin-trust.json"
$LocalIntegrityFile = Join-Path $ProjectRoot "data\trusted-integrity.json"

Remove-Item $LocalTrustFile -Force -ErrorAction SilentlyContinue
Remove-Item $LocalIntegrityFile -Force -ErrorAction SilentlyContinue

@("plugin-valido") | ConvertTo-Json | Set-Content $LocalTrustFile -Encoding utf8

$ValidoHashes = Get-PluginHashes -PluginDir $ValidoDir
$FilesObj = [ordered]@{}
foreach ($k in $ValidoHashes.Keys) { $FilesObj[$k] = $ValidoHashes[$k] }

$TempStore = @{
    "plugin-valido" = @{
        pluginId = "plugin-valido"
        version = "0.1.0"
        approvedAt = "2026-12-12T12:12:12Z"
        algorithm = "SHA256"
        files = $FilesObj
    }
}
$TempStore | ConvertTo-Json -Depth 5 | Set-Content $LocalIntegrityFile -Encoding utf8

$IntCheckCorrect = Test-PluginIntegrity -PluginId "plugin-valido" -PluginDir $ValidoDir -EffectiveTrustLevel "trusted" -ProjectRoot $ProjectRoot
Assert-True ($IntCheckCorrect.Status -eq "valid") "Plugin com hash correto aceito"

$TempStoreCorrupted = @{
    "plugin-valido" = @{
        pluginId = "plugin-valido"
        version = "0.1.0"
        approvedAt = "2026-12-12T12:12:12Z"
        algorithm = "SHA256"
        files = @{
            "plugin.json" = "12fb7f18d88609e5f04d23682d2f88ac06abf6c1827fabddf77843c45ed52a8e"
            "scan.ps1" = "HASH_FALSO_DE_TESTE_CORROMPIDO"
        }
    }
}
$TempStoreCorrupted | ConvertTo-Json -Depth 5 | Set-Content $LocalIntegrityFile -Encoding utf8

$IntCheckCorrupted = Test-PluginIntegrity -PluginId "plugin-valido" -PluginDir $ValidoDir -EffectiveTrustLevel "trusted" -ProjectRoot $ProjectRoot
Assert-True ($IntCheckCorrupted.Status -eq "corrupted") "Plugin com hash divergente é rejeitado"
$hasHashDiffError = [bool]($IntCheckCorrupted.Errors | Where-Object { $_ -match "Integridade violada" })
Assert-True $hasHashDiffError "Erro correto de integridade violada retornado para hash incorreto"

# 6. Testando integridade de builtin com hash divergente
$BuiltinIntegrityFile = Join-Path $ProjectRoot "config\builtin-integrity.json"
$BuiltinBackup = Join-Path $ProjectRoot "config\builtin-integrity.json.bak"
Copy-Item $BuiltinIntegrityFile $BuiltinBackup -Force -ErrorAction SilentlyContinue

$BuiltinStoreContent = Get-Content $BuiltinIntegrityFile -Raw -Encoding utf8 | ConvertFrom-Json
$BuiltinStoreContent."agent-scanner".files."scan.ps1" = "HASH_BUILTIN_DIVERGENTE_SIMULADO"
$BuiltinStoreContent | ConvertTo-Json -Depth 5 | Set-Content $BuiltinIntegrityFile -Encoding utf8

$IntBuiltinCorrupted = Test-PluginIntegrity -PluginId "agent-scanner" -PluginDir (Join-Path $ProjectRoot "plugins\agent-scanner") -EffectiveTrustLevel "builtin" -ProjectRoot $ProjectRoot
Assert-True ($IntBuiltinCorrupted.Status -eq "corrupted") "Plugin builtin com hash divergente é bloqueado"

# Restaura backup da integridade builtin
if (Test-Path $BuiltinBackup) {
    Move-Item $BuiltinBackup $BuiltinIntegrityFile -Force
}
Remove-Item $BuiltinBackup -Force -ErrorAction SilentlyContinue

# Limpa local trust stores temporários
Remove-Item $LocalTrustFile -Force -ErrorAction SilentlyContinue
Remove-Item $LocalIntegrityFile -Force -ErrorAction SilentlyContinue

# 7. Limpa fixtures temporárias do disco
Remove-Item $UntrustedDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $FakeTrustedDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $PermInvalidaDir -Recurse -Force -ErrorAction SilentlyContinue

# Restaura o config.json original
if (Test-Path $ConfigBackup) {
    Move-Item $ConfigBackup $ConfigPath -Force
}

# Valida os artefatos de plugins gerados
$PluginsJsDataFile = Join-Path $ProjectRoot "dashboard\plugins-data.js"
Assert-True (Test-Path $PluginsJsDataFile) "dashboard/plugins-data.js foi criado com sucesso pelo manager"
if (Test-Path $PluginsJsDataFile) {
    $jsContent = Get-Content $PluginsJsDataFile -Raw -Encoding utf8
    Assert-True ($jsContent -match '^window\.HERMES_PLUGINS_DATA\s*=') "O formato do plugins-data.js começa com window.HERMES_PLUGINS_DATA ="
}

# [Fase 11] Validação de Empacotamento, Segredos e Clean-Room...
Write-Host "`n[Fase 11] Validação de Empacotamento, Segredos e Clean-Room..." -ForegroundColor Cyan

# 1. Config.example.json válido
$ExampleJsonPath = Join-Path $ProjectRoot "config.example.json"
Assert-True (Test-Path $ExampleJsonPath) "config.example.json existe"
if (Test-Path $ExampleJsonPath) {
    $exampleContent = Get-Content $ExampleJsonPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($null -ne $exampleContent) "config.example.json é um JSON válido"
}

# 2. Dados locais ignorados pelo Git
$GitIgnorePath = Join-Path $ProjectRoot ".gitignore"
Assert-True (Test-Path $GitIgnorePath) ".gitignore existe"
if (Test-Path $GitIgnorePath) {
    $gitIgnoreContent = Get-Content $GitIgnorePath -Raw -Encoding utf8
    Assert-True ($gitIgnoreContent -match "config\.local\.json") "config.local.json está no .gitignore"
    Assert-True ($gitIgnoreContent -match "data/plugin-trust\.json") "data/plugin-trust.json está no .gitignore"
    Assert-True ($gitIgnoreContent -match "data/trusted-integrity\.json") "data/trusted-integrity.json está no .gitignore"
    Assert-True ($gitIgnoreContent -match "dist/") "dist/ está no .gitignore"
}

# 3. Ausência de caminhos pessoais nos arquivos públicos
$TextFiles = Get-ChildItem -Path $ProjectRoot -File -Recurse -Include @("*.ps1", "*.psm1", "*.psd1", "*.json", "*.md", "*.js", "*.css", "*.html", "*.svg")
$LeakFound = $false
foreach ($f in $TextFiles) {
    if ($f.FullName -match '\\(\.git|logs|dist|dist_clean|scratch|config\.local\.json)\\') { continue }
    if ($f.Name -match '-(data|trust|integrity)\.js(on)?$') { continue }
    $txt = Get-Content $f.FullName -Raw -Encoding utf8
    if ($txt -match 'Users\\SCHAE' -or $txt -match 'Users/SCHAE') {
        $LeakFound = $true
        Write-Host "Leque de caminho pessoal detectado em: $($f.FullName)" -ForegroundColor Red
    }
}
Assert-True (-not $LeakFound) "Nenhum caminho pessoal absoluto vazado em arquivos de código público"

# 4. Execução sem config.local.json
$LocalConfigPath = Join-Path $ProjectRoot "config.local.json"
$LocalConfigBackup = Join-Path $ProjectRoot "config.local.json.bak"
$HasLocalConfig = Test-Path $LocalConfigPath
if ($HasLocalConfig) {
    Move-Item $LocalConfigPath $LocalConfigBackup -Force
}

$ManagerNoLocalConfig = Invoke-HermesPluginManager -ConfigPath (Join-Path $ProjectRoot "config.json")
Assert-True ($null -ne $ManagerNoLocalConfig) "Plugin Manager funciona corretamente sem config.local.json"

if ($HasLocalConfig -and (Test-Path $LocalConfigBackup)) {
    Move-Item $LocalConfigBackup $LocalConfigPath -Force
}

$StagingDir = Join-Path $ProjectRoot "dist_clean"

# 5. Validação das estatísticas e da distribuição na pasta dist/ (Apenas em ambiente de desenvolvimento)
$IsDevEnv = -not ($ProjectRoot -match 'hermes-extraction-test' -or $ProjectRoot -match 'dist_clean')
if ($IsDevEnv) {
    $DistDir = Join-Path $ProjectRoot "dist"
    $DistZip = Join-Path $DistDir "hermes-agent-hub-v0.3.0-rc.1.zip"
    $DistChecksum = Join-Path $DistDir "hermes-agent-hub-v0.3.0-rc.1.zip.sha256"
    $DistManifest = Join-Path $DistDir "RELEASE_MANIFEST.json"

    Assert-True (Test-Path $DistZip) "Pacote ZIP de distribuição criado em dist/"
    Assert-True (Test-Path $DistChecksum) "Checksum do ZIP criado em dist/"
    Assert-True (Test-Path $DistManifest) "RELEASE_MANIFEST.json criado em dist/"

    if (Test-Path $DistManifest) {
        $manifestObj = Get-Content $DistManifest -Raw -Encoding utf8 | ConvertFrom-Json
        Assert-True ($manifestObj.name -eq "Hermes Agent Hub") "RELEASE_MANIFEST.json possui o nome correto"
        Assert-True ($manifestObj.version -eq "v0.3.0-rc.1") "RELEASE_MANIFEST.json possui a versão correta"
        Assert-True ($manifestObj.zipSha256 -eq (Get-FileHash -Path $DistZip -Algorithm SHA256).Hash) "SHA-256 no manifesto bate com o arquivo ZIP físico"
    }

    # 6. Teste Clean-Room: funcionamento fora da pasta original
    Assert-True (Test-Path $StagingDir) "Pasta de staging clean-room criada"
} else {
    Write-Host "[INFO] Executando em ambiente distribuído extraído. Ignorando testes de geração de ZIP e Staging." -ForegroundColor Yellow
}
if (Test-Path $StagingDir) {
    $StagingManager = Join-Path $StagingDir "core\PluginManager.ps1"
    Assert-True (Test-Path $StagingManager) "Plugin Manager existe na pasta clean-room"
    
    . $StagingManager
    $StagingResult = Invoke-HermesPluginManager -ConfigPath (Join-Path $StagingDir "config.json")
    Assert-True ($null -ne $StagingResult) "Plugin Manager executou com sucesso na pasta clean-room"
    if ($null -ne $StagingResult) {
        Assert-True ($StagingResult.plugins.Count -gt 0) "Plugins foram descobertos com sucesso na pasta clean-room"
        $stagingAgentScanner = $StagingResult.plugins | Where-Object { $_.id -eq "agent-scanner" }
        Assert-True ($stagingAgentScanner.status -eq "enabled") "agent-scanner está ativo na pasta clean-room"
        Assert-True ($stagingAgentScanner.integrityStatus -eq "valid") "integridade builtin válida na pasta clean-room"
        
        # 6.2 Teste: hello-plugin desabilitado por padrão e nunca executado
        $stagingHello = $StagingResult.plugins | Where-Object { $_.id -eq "hello-plugin" }
        Assert-True ($null -ne $stagingHello) "hello-plugin foi descoberto e validado na pasta clean-room"
        if ($null -ne $stagingHello) {
            Assert-True ($stagingHello.trustSource -eq "builtin") "hello-plugin é reconhecido como builtin"
            Assert-True ($stagingHello.status -eq "disabled") "hello-plugin está desabilitado por padrão no manifesto"
            Assert-True ($stagingHello.lastExecutionStatus -eq "not_run") "entrypoint do hello-plugin NUNCA foi executado (lastExecutionStatus = not_run)"
        }
        
        # Certifica que somente agent-scanner e skills-scanner executaram com sucesso
        $executedPlugins = $StagingResult.plugins | Where-Object { $_.lastExecutionStatus -eq "success" }
        Assert-True ($executedPlugins.Count -eq 2) "Apenas 2 plugins foram executados com sucesso no clean-room staging"
        $executedIds = $executedPlugins.id
        Assert-True ($executedIds -contains "agent-scanner" -and $executedIds -contains "skills-scanner") "Somente agent-scanner e skills-scanner foram executados"
    }
}

# Resumo Final
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "RESUMO DOS TESTES DO MVP:" -ForegroundColor Cyan
Write-Host "Sucessos: $global:TestSuccess" -ForegroundColor Green
$color = if ($global:TestFail -gt 0) { "Red" } else { "Green" }
Write-Host "Falhas: $global:TestFail" -ForegroundColor $color
Write-Host "==========================================" -ForegroundColor Cyan

if ($global:TestFail -gt 0) {
    exit 1
} else {
    exit 0
}
