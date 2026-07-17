# 🛠️ Tutorial: Como Criar Novos Plugins

Este guia descreve passo a passo como desenvolver e habilitar uma nova extensão para obter novos tipos de inventário no **Hermes Agent Hub**.

---

## Passo 1: Criar a pasta do seu Plugin

Adicione uma subpasta para o seu plugin dentro do diretório `plugins/`.
O nome da pasta deve corresponder preferencialmente ao ID do seu plugin:

```text
plugins/
└── custom-scanner/
```

---

## Passo 2: Criar o manifesto `plugin.json`

Crie o manifesto de configuração na raiz da pasta do seu plugin:

```json
{
  "id": "custom-scanner",
  "name": "Meu Scanner Customizado",
  "version": "0.1.0",
  "author": "Seu Nome",
  "description": "Busca projetos e extensões instaladas localmente.",
  "category": "agents",
  "entrypoint": "scan.ps1",
  "enabled": true,
  "supportedPlatforms": ["windows"],
  "minimumHermesVersion": "0.1.0",
  "permissions": [
    "filesystem.read"
  ],
  "outputs": [
    "agents"
  ]
}
```

---

## Passo 3: Implementar o entrypoint `scan.ps1`

Crie o arquivo de script PowerShell `scan.ps1` que executará a lógica de leitura. O script deve retornar o objeto contendo o contrato padrão do Hermes Hub:

```powershell
# plugins/custom-scanner/scan.ps1

# Parâmetro opcional de configuração passado pelo Core
param($Config = $null)

# Lógica de varredura
$Projetos = @()
$Projetos += [PSCustomObject]@{
    name            = "Projeto Customizado Exemplo"
    category        = "Developer"
    detected        = $true
    running         = $false
    version         = "1.0.0"
    executable      = "code.exe"
    installPath     = "C:\Projetos"
    detectionMethod = "Custom Scan Path"
    notes           = "Localizado na pasta de projetos local."
    scannedAt       = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
}

# Retorna o contrato oficial
return [PSCustomObject]@{
    pluginId   = "custom-scanner"
    category   = "agents"
    scannedAt  = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
    status     = "success"
    items      = $Projetos
    warnings   = @()
    errors     = @()
}
```

---

## Passo 4: Habilitar o Plugin em `config.json`

Abra o arquivo `config.json` localizado na raiz do projeto e adicione o ID do seu plugin na lista `enabledPlugins`:

```json
  "enabledPlugins": [
    "agent-scanner",
    "skills-scanner",
    "custom-scanner"
  ]
```

Rode o script inicializador no PowerShell:
```powershell
pwsh .\Start-HermesHub.ps1
```

O seu plugin será validado, carregado e os resultados agregados serão injetados de forma automática no Dashboard!
