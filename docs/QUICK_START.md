# 🏁 Guia de Início Rápido (Quick Start)

Aprenda a utilizar o **Hermes Agent Hub** em menos de 2 minutos.

---

## 1. Primeira Execução e Varredura
Para disparar a varredura mestre de detecção de agentes locais de IA e servidores MCP ativos, execute na raiz do projeto:
```powershell
pwsh .\Start-HermesHub.ps1
```
Ao final da execução, o Dashboard web é aberto e o inventário dos agentes localizados é salvo fisicamente em `data/agents.json` e `data/agents.md`.

---

## 2. Varrendo Skills de Agentes
Por padrão, o Hermes procura arquivos `SKILL.md` (instruções de comportamento) em caminhos comuns de mercado (como `$HOME\.hermes\skills`). 
Para adicionar diretórios customizados da sua máquina, edite ou crie o arquivo local `config.local.json` adicionando seus caminhos no array `skillSearchPaths`:
```json
{
  "skillSearchPaths": [
    "C:\\MeusProjetos\\skills",
    "C:\\Users\\Usuario\\AppData\\Roaming\\Claude\\skills"
  ]
}
```
Execute o `Start-HermesHub.ps1` novamente para carregar os novos escopos locais.

---

## 3. Autorizar e Executar Plugins de Terceiros
Plugins de terceiros são bloqueados por padrão sob a classificação de confiança `untrusted`. Para autorizar a execução de um novo plugin:
1.  Execute o script de aprovação interativo no console:
    ```powershell
    pwsh .\tools\Approve-HermesPlugin.ps1 -PluginId "id-do-plugin"
    ```
2.  Confirme as permissões exibidas no console. A assinatura de hashes de integridade será salva em `data/trusted-integrity.json`.
3.  Edite seu `config.local.json` para adicionar o ID do plugin no array de plugins habilitados (`enabledPlugins`).
