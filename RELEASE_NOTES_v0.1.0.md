# Release Notes — Hermes Agent Hub v0.1.0

Esta é a primeira liberação oficial do **Hermes Agent Hub (MVP v0.1.0)**, um utilitário local de auditoria de agentes construído sob demanda para Windows.

---

## 🎯 Escopo da Versão

O foco deste MVP é duplo:
1.  **Fase 1 (Discovery Scanner):** Varredura local e não intrusiva de runtime de LLMs locais, agentes de IA e configurações de MCP do usuário.
2.  **Fase 2 (Product Polish):** Interface visual premium baseada no tema de `sid.dev.br`, organização SPA em 10 módulos locais, console de visualização de logs nativos e contadores.

---

## 🚀 Módulos da Aplicação

### Módulos Ativos (Dados Reais do Scanner)
*   **Dashboard (Home):** Sumário geral da verificação da máquina, data/hora da última execução e contadores.
*   **Agents:** Grade de cartões contendo os 13 detectores de ferramentas ativas. Conta com busca dinâmica, filtro por categoria e por status de instalação, além de um modal interativo de detalhes de cada agente.
*   **MCP Servers:** Exibição da configuração física mapeada a partir do arquivo de origem do Claude Desktop.
*   **Logs:** Painel do terminal em tempo real que lê e apresenta o log acumulado da varredura real efetuada pelo PowerShell.
*   **About:** Informações autorais do projeto.

### Módulos Futuros (Marcados como "COMING SOON")
*   **Models:** Comparador e gerenciador de velocidade de modelos locais (Ollama/LM Studio).
*   **Skills:** Painel interativo de validação de regras de arquivos `SKILL.md`.
*   **Knowledge Base:** RAG local e indexação semântica de cofres Obsidian e Markdown.
*   **Workflows:** Pipelines de automação multi-agente.
*   **Settings:** Edição visual direta das configurações em `config.json`.

---

## 🛠️ Como Executar e Testar

### Executar a Aplicação
No terminal (PowerShell 7+):
```powershell
pwsh .\Start-HermesHub.ps1
```

### Rodar a Suíte de Testes
```powershell
pwsh .\tests\Test-HermesHub.ps1
```
*(Todos os 17 casos de teste devem retornar verde/sucesso).*
