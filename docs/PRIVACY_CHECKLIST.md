# Checklist de Privacidade e Segurança — v0.1.0

Este documento atesta a conformidade de privacidade e as salvaguardas implementadas no motor de varredura e no dashboard local.

---

## 🔒 Auditoria de Segurança Interna

*   **Vazamento de Credenciais:** 🟢 **Nenhum**. Nenhuma chave de API, token ou credencial é requerida, armazenada ou gerada nos scripts do projeto.
*   **Detector de Servidores MCP:** 🟢 **Sanitizado**. O script `Detect-MCPServers.ps1` foi projetado para apenas contar o número de servidores registrados no JSON do Claude Desktop e capturar o caminho de origem. Argumentos, caminhos de scripts internos e variáveis de ambiente privadas são explicitamente descartados durante o parsing para evitar exposição acidental.
*   **Comandos Destrutivos:** 🟢 **Nenhum**. O scanner opera em modo estritamente read-only (apenas leitura). Não altera registros de sistema, não cria arquivos em diretórios do Windows e não exclui dados.
*   **Privilégios de Execução:** 🟢 **Padrão (Non-Elevated)**. O script orquestrador e os testes rodam no contexto de usuário padrão. Não há requisição de privilégios de Administrador (UAC).
*   **Chamadas de Rede e Telemetria:** 🟢 **Nenhuma**. A aplicação roda de forma 100% isolada e offline. Não faz requisições HTTP para servidores remotos e não envia dados analíticos.
*   **Downloads Automáticos:** 🟢 **Nenhum**. Nenhum script realiza downloads de binários externos ou bibliotecas em tempo de execução.

---

## 🛠️ Mitigação de Riscos de Timeout

*   O script `scanner/Get-AgentVersion.ps1` implementa chamadas .NET síncronas de execução de sub-processo utilizando a classe `System.Diagnostics.Process`.
*   Todas as consultas de versão do PATH possuem um limite estrito de timeout de **3 segundos** (com teto máximo absoluto de **5 segundos**) para evitar o travamento indefinido do terminal PowerShell por comandos bloqueantes ou interativos.
