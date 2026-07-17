# 🔒 Arquivos Exclusivamente Locais (Ignorados pelo Git)

Este documento relaciona os arquivos locais que contêm dados da máquina e não devem ser publicados.

---

## Estrutura de Arquivos Exclusivamente Locais

*   **`config.local.json`** (Configurações customizadas do usuário local)
*   **`data/plugin-trust.json`** (Lista local de plugins aprovados manualmente)
*   **`data/trusted-integrity.json`** (Assinatura de hashes de plugins locais do usuário)
*   **`data/agents.json`** (Inventário gerado contendo caminhos físicos de agentes instalados)
*   **`data/agents.md`** (Relatório legível contendo caminhos da máquina local)
*   **`data/skills.json`** (Inventário gerado de skills encontradas na máquina)
*   **`data/skills.md`** (Relatório legível de skills encontradas)
*   **`dashboard/data.js`** (Payload injetado de agentes locais para o Dashboard)
*   **`dashboard/skills-data.js`** (Payload de skills locais para o Dashboard)
*   **`dashboard/plugins-data.js`** (Metadados locais de plugins descobertos e rodados)
*   **`logs/`** (Logs de execuções históricas do sistema local)
*   **`dist/`** (Compilados de empacotamento ZIP de versões geradas locais)
*   **`dist_clean/`** (Diretórios de staging e validação limpa)
*   **Arquivos temporários e backups** (`*.bak`, `*backup*`, `*staging*`)
