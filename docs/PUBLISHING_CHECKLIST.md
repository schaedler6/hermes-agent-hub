# Guia e Checklist de Publicação no GitHub — v0.1.0

Este checklist define quais arquivos devem ser comitados no repositório GitHub público e quais devem permanecer ignorados localmente para preservar a privacidade do usuário e do ambiente de desenvolvimento.

---

## 📂 Controle do `.gitignore`

O arquivo `.gitignore` na raiz do projeto deve conter e rastrear as seguintes exclusões de segurança:

```text
# Arquivos de dados locais gerados pelo scanner
data/agents.json
data/agents.md
dashboard/data.js

# Diretórios de logs e depuração local
logs/
*.log

# Pastas de ambiente locais do PowerShell / VS Code
.vscode/
.history/
```

---

## 🟢 Lista de Arquivos Seguros para Publicação (GitHub)

Estes arquivos contêm apenas lógica de código pura e documentações universais sem dados locais:

*   `Start-HermesHub.ps1` (Inicializador)
*   `config.json` (Modelo padrão de escopos e limites)
*   `LICENSE` (Licença MIT)
*   `README.md` & `README.pt-BR.md` (Documentação mestre)
*   `RELEASE_NOTES_v0.1.0.md` (Notas de versão)
*   `assets/logo.svg` (Logotipo vetorial)
*   `docs/VALIDATION_REPORT.md` (Relatório de testes)
*   `docs/PRIVACY_CHECKLIST.md` (Segurança e privacidade)
*   `docs/PUBLISHING_CHECKLIST.md` (Este documento)
*   `docs/screenshots/.gitkeep` (Placeholder de pasta de telas)
*   `docs/images/.gitkeep` (Placeholder de pasta de imagens)
*   `docs/assets/.gitkeep` (Placeholder de pasta de ativos)
*   `scanner/Scan-HermesAgents.ps1` (Lógica do orquestrador)
*   `scanner/Get-AgentVersion.ps1` (Mecanismo de timeout de subprocessos)
*   `scanner/detectors/*` (Os 14 scripts modulares de detecção)
*   `dashboard/index.html` (Estrutura do Dashboard)
*   `dashboard/styles.css` (Folhas de estilos e glassmorphism)
*   `dashboard/app.js` (Lógica Javascript pura da interface SPA)
*   `tests/Test-HermesHub.ps1` (Suíte de testes integrados)
*   `validator/validate-skills.ps1` (Mecanismo de validação de skills)

---

## 🔴 Arquivos que DEVEM Permanecer Fora do GitHub

Estes arquivos contêm informações de caminhos físicos locais do computador do desenvolvedor e histórico de execução:

1.  `dashboard/data.js` — Contém o objeto global `window.HERMES_DATA` com a data e hora do scanner e caminhos físicos das ferramentas encontradas na sua máquina.
2.  `data/agents.json` — Carga bruta de dados de inventário do sistema pessoal.
3.  `data/agents.md` — Relatório gerado em Markdown contendo os dados pessoais do sistema.
4.  `logs/` (e qualquer arquivo `.log` interno) — Histórico de execução real e caminhos da máquina local.
