# ==========================================
# PluginValidator.ps1 — Validador de Manifesto e Segurança
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
$ContractsScript = Join-Path $CoreDir "PluginContracts.ps1"
if (Test-Path $ContractsScript) {
    . $ContractsScript
}

function Test-PluginManifest {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PluginDir
    )
    
    $Result = [PSCustomObject]@{
        Valid = $false
        Errors = @()
        Manifest = $null
    }
    
    if (-not (Test-Path $PluginDir)) {
        $Result.Errors += "Diretório do plugin não existe: $PluginDir"
        return $Result
    }
    
    $ManifestPath = Join-Path $PluginDir "plugin.json"
    if (-not (Test-Path $ManifestPath)) {
        $Result.Errors += "Manifesto 'plugin.json' não localizado na pasta do plugin."
        return $Result
    }
    
    # 1. Valida JSON
    try {
        $JsonContent = Get-Content $ManifestPath -Raw -Encoding utf8
        $Manifest = ConvertFrom-Json $JsonContent
        $Result.Manifest = $Manifest
    } catch {
        $Result.Errors += "O arquivo 'plugin.json' não é um JSON válido. Erro: $_"
        return $Result
    }
    
    # 2. Valida campos obrigatórios
    $MandatoryFields = Get-MandatoryFields
    foreach ($field in $MandatoryFields) {
        $Val = $Manifest.$field
        if (-not (Get-Member -InputObject $Manifest -Name $field -ErrorAction SilentlyContinue)) {
            $Result.Errors += "Campo obrigatório ausente no manifesto: '$field'"
        } elseif ($null -eq $Val) {
            $Result.Errors += "Campo obrigatório '$field' está ausente ou nulo no manifesto."
        } elseif ($Val -is [array]) {
            # Arrays vazios declarados são válidos
        } elseif ([string]::IsNullOrWhiteSpace($Val)) {
            $Result.Errors += "Campo obrigatório '$field' está vazio no manifesto."
        }
    }
    
    if ($Result.Errors.Count -gt 0) {
        return $Result
    }
    
    # 3. Valida ID
    if ($Manifest.id -match '[^a-zA-Z0-9\-_]') {
        $Result.Errors += "ID do plugin '$($Manifest.id)' contém caracteres especiais inválidos. Use apenas letras, números, hifens e underlines."
    }
    
    # 4. Valida versão semântica
    if ($Manifest.version -notmatch '^\d+\.\d+\.\d+$') {
        $Result.Errors += "Versão '$($Manifest.version)' inválida. Deve seguir o padrão semântico clássico x.y.z."
    }
    
    # 5. Valida categoria
    $SupportedCategories = Get-SupportedCategories
    if ($SupportedCategories -notcontains $Manifest.category) {
        $Result.Errors += "Categoria '$($Manifest.category)' não suportada. Escolha uma de: $($SupportedCategories -join ', ')."
    }
    
    # 6. Valida plataforma suportada
    if ($Manifest.supportedPlatforms -notcontains "windows") {
        $Result.Errors += "Plataforma do plugin não suporta 'windows'."
    }
    
    # 7. Valida caminhos e segurança do Entrypoint (Prevenção de Path Traversal, Symlinks e UNC)
    $Entrypoint = $Manifest.entrypoint
    
    # Rejeita entrypoints UNC ou caminhos de rede absolutos
    if ($Entrypoint -match '^\\\\') {
        $Result.Errors += "Entrypoints UNC ou caminhos de rede não são permitidos no manifesto."
    } elseif ($Entrypoint -match '^[a-zA-Z]:\\') {
        $Result.Errors += "Caminho absoluto do entrypoint não é permitido no manifesto."
    } else {
        # Resolve caminhos físicos reais em formato Windows (Case-Insensitive)
        $PluginDirFullPath = [System.IO.Path]::GetFullPath($PluginDir).TrimEnd('\') + '\'
        
        try {
            $CombinedPath = Join-Path $PluginDir $Entrypoint
            $EntrypointFullPath = [System.IO.Path]::GetFullPath($CombinedPath)
            
            # Checa se o entrypoint está contido dentro da pasta física do plugin (Case-Insensitive)
            if (-not $EntrypointFullPath.ToLower().StartsWith($PluginDirFullPath.ToLower())) {
                $Result.Errors += "Tentativa de Path Traversal detectada: O entrypoint '$Entrypoint' escapa da pasta física do plugin."
            } else {
                # Verifica a existência do arquivo físico do entrypoint
                if (-not (Test-Path $EntrypointFullPath)) {
                    $Result.Errors += "Arquivo do entrypoint '$Entrypoint' não foi localizado na pasta do plugin."
                } else {
                    # Verifica contra Links Simbólicos, Junctions ou Reparse Points maliciosos
                    $FileInfo = Get-Item $EntrypointFullPath -ErrorAction SilentlyContinue
                    if ($null -ne $FileInfo) {
                        if ($FileInfo.LinkType -or ($FileInfo.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                            # Tenta resolver o link target real (canônico)
                            $RealPath = $FileInfo.Target
                            if ([string]::IsNullOrWhiteSpace($RealPath) -and (Get-Member -InputObject $FileInfo -Name "ResolveLinkTarget" -ErrorAction SilentlyContinue)) {
                                $ResolvedTarget = $FileInfo.ResolveLinkTarget($true)
                                if ($null -ne $ResolvedTarget) {
                                    $RealPath = $ResolvedTarget.FullName
                                }
                            }
                            
                            if (-not [string]::IsNullOrWhiteSpace($RealPath)) {
                                $RealPathClean = [System.IO.Path]::GetFullPath($RealPath)
                                if (-not $RealPathClean.ToLower().StartsWith($PluginDirFullPath.ToLower())) {
                                    $Result.Errors += "Link Simbólico ou Junction detectado apontando para fora da pasta do plugin."
                                }
                            } else {
                                $Result.Errors += "Junction ou Reparse Point inválido detectado no entrypoint."
                            }
                        }
                    }
                }
            }
        } catch {
            $Result.Errors += "Falha ao resolver caminho de segurança do entrypoint: $_"
        }
    }
    
    # 8. Validação de permissões declaradas
    $AllowedPermissions = Get-AllowedPermissions
    if ($Manifest.permissions) {
        foreach ($perm in $Manifest.permissions) {
            if ($AllowedPermissions -notcontains $perm) {
                $Result.Errors += "Permissão '$perm' declarada não é suportada pelo core."
            }
        }
    }
    
    if ($Result.Errors.Count -eq 0) {
        $Result.Valid = $true
    }
    
    return $Result
}

# Determina o nível de confiança efetivo externamente ao manifesto
function Get-EffectiveTrustLevel {
    param(
        [string]$PluginId,
        [string]$ProjectRoot
    )
    
    # 1. Carrega Builtin Store versionada
    $BuiltinStorePath = Join-Path $ProjectRoot "config\builtin-plugins.json"
    if (Test-Path $BuiltinStorePath) {
        try {
            $BuiltinJson = Get-Content $BuiltinStorePath -Raw -Encoding utf8
            $BuiltinList = ConvertFrom-Json $BuiltinJson
            if ($BuiltinList -contains $PluginId) {
                return "builtin"
            }
        } catch {
            # Silencia erros de parse para segurança
        }
    }
    
    # 2. Carrega Trusted Store local do usuário
    $TrustedStorePath = Join-Path $ProjectRoot "data\plugin-trust.json"
    if (Test-Path $TrustedStorePath) {
        try {
            $TrustedJson = Get-Content $TrustedStorePath -Raw -Encoding utf8
            $TrustedList = ConvertFrom-Json $TrustedJson
            if ($TrustedList -contains $PluginId) {
                return "trusted"
            }
        } catch {
            # Silencia erros de parse
        }
    }
    
    return "untrusted"
}

# Calcula hashes SHA-256 dos arquivos executáveis e manifestos do plugin
function Get-PluginHashes {
    param(
        [string]$PluginDir
    )
    
    $FilesHashes = [ordered]@{}
    if (-not (Test-Path $PluginDir)) { return $FilesHashes }
    
    # Resolve caminho absoluto normalizado
    $PluginDirClean = [System.IO.Path]::GetFullPath($PluginDir).TrimEnd('\')
    
    # Lista recursivamente todos os arquivos
    $AllFiles = Get-ChildItem -Path $PluginDirClean -File -Recurse | Sort-Object { $_.FullName }
    
    foreach ($file in $AllFiles) {
        # Filtra apenas arquivos executáveis relevantes e manifesto
        if ($file.Name -eq "plugin.json" -or $file.Extension -match '^\.(ps1|psm1|psd1|bat|cmd|sh|js|json)$') {
            # Caminho relativo normalizado ordenado com barras "/"
            $RelativePath = $file.FullName.Substring($PluginDirClean.Length).TrimStart('\').TrimStart('/')
            $RelativePathNormal = $RelativePath.Replace('\', '/')
            
            # Ignora subdiretórios ocultos/temporários que começam com ponto
            if ($RelativePathNormal -match '(^|/)\.') { continue }
            
            try {
                $Stream = [System.IO.File]::OpenRead($file.FullName)
                $Sha = [System.Security.Cryptography.SHA256]::Create()
                $HashBytes = $Sha.ComputeHash($Stream)
                $Stream.Close()
                $Stream.Dispose()
                
                $HashHex = [System.BitConverter]::ToString($HashBytes).Replace("-", "").ToLower()
                
                $FilesHashes[$RelativePathNormal] = $HashHex
            } catch {
                # Ignora falhas de leitura
            }
        }
    }
    
    return $FilesHashes
}

# Valida a integridade física de arquivos builtin ou trusted contra o registro externo
function Test-PluginIntegrity {
    param(
        [string]$PluginId,
        [string]$PluginDir,
        [string]$EffectiveTrustLevel,
        [string]$ProjectRoot
    )
    
    $Result = [PSCustomObject]@{
        Status = "valid"  # "valid", "corrupted", "unverified", "missing"
        Errors = @()
    }
    
    $IntegrityStorePath = $null
    if ($EffectiveTrustLevel -eq "builtin") {
        $IntegrityStorePath = Join-Path $ProjectRoot "config\builtin-integrity.json"
    } elseif ($EffectiveTrustLevel -eq "trusted") {
        $IntegrityStorePath = Join-Path $ProjectRoot "data\trusted-integrity.json"
    } else {
        $Result.Status = "unverified"
        $Result.Errors += "Plugin não verificado (untrusted)."
        return $Result
    }
    
    if (-not (Test-Path $IntegrityStorePath)) {
        $Result.Status = "missing"
        $Result.Errors += "Registro de integridade ausente para o nível '$EffectiveTrustLevel'."
        return $Result
    }
    
    try {
        $StoreJson = Get-Content $IntegrityStorePath -Raw -Encoding utf8
        $Store = ConvertFrom-Json $StoreJson
        
        $PluginRecord = $Store.$PluginId
        if ($null -eq $PluginRecord) {
            $Result.Status = "missing"
            $Result.Errors += "Registro de hash do plugin não localizado no banco de integridade."
            return $Result
        }
        
        $RegisteredFiles = $PluginRecord.files
        if ($null -eq $RegisteredFiles) {
            $Result.Status = "corrupted"
            $Result.Errors += "Registro de integridade corrompido (campo files ausente)."
            return $Result
        }
        
        $CurrentHashes = Get-PluginHashes -PluginDir $PluginDir
        
        # Obtém chaves registradas no JSON
        $RegisteredFileNames = Get-Member -InputObject $RegisteredFiles -MemberType NoteProperty | Select-Object -ExpandProperty Name
        
        foreach ($file in $RegisteredFileNames) {
            $RegisteredHash = $RegisteredFiles.$file
            $CurrentHash = $CurrentHashes.$file
            
            if ([string]::IsNullOrWhiteSpace($CurrentHash)) {
                $Result.Status = "corrupted"
                $Result.Errors += "Arquivo registrado '$file' está ausente no disco do plugin."
            } elseif ($CurrentHash -ne $RegisteredHash) {
                $Result.Status = "corrupted"
                $Result.Errors += "Arquivo modificado após aprovação: '$file' (Integridade violada)."
            }
        }
        
        # Verifica se há novos arquivos não cadastrados
        foreach ($key in $CurrentHashes.Keys) {
            if (-not (Get-Member -InputObject $RegisteredFiles -Name $key -ErrorAction SilentlyContinue)) {
                $Result.Status = "corrupted"
                $Result.Errors += "Arquivo novo não autorizado adicionado na pasta: '$key'."
            }
        }
    } catch {
        $Result.Status = "corrupted"
        $Result.Errors += "Falha ao processar verificação de integridade: $_"
    }
    
    if ($Result.Errors.Count -gt 0 -and $Result.Status -eq "valid") {
        $Result.Status = "corrupted"
    }
    
    return $Result
}
