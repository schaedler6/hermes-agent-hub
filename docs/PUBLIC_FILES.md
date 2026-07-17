# 📂 Arquivos Públicos (Seguros para Versão Git)

Este documento relaciona os arquivos que compõem o repositório público do **Hermes Agent Hub**.

---

## Estrutura de Arquivos Públicos

*   `.gitattributes` (Normalização de line endings)
*   `.gitignore` (Regras de exclusão)
*   `LICENSE` (Licença MIT)
*   `README.md` (Documentação em inglês)
*   `README.pt-BR.md` (Documentação em português brasileiro)
*   `RELEASE_NOTES_v0.3.0-rc.1.md` (Notas de lançamento)
*   `Start-HermesHub.ps1` (Script inicializador de bootstrap)
*   `config.json` (Configuração padrão da distribuição)
*   `config.example.json` (Modelo de configuração local)
*   **`assets/`**
    *   `logo.svg`
*   **`config/`**
    *   `builtin-plugins.json`
    *   `builtin-integrity.json`
*   **`core/`**
    *   `PluginContracts.ps1`
    *   `PluginValidator.ps1`
    *   `PluginRunner.ps1`
    *   `PluginManager.ps1`
*   **`dashboard/`**
    *   `index.html`
    *   `app.js`
    *   `index.css`
*   **`docs/`**
    *   `ARCHITECTURE.md`
    *   `CREATING_PLUGINS.md`
    *   `PUBLISHING_CHECKLIST.md`
    *   `SECURITY_MODEL.md`
    *   `TRUST_MODEL.md`
    *   `PHASE_3_VALIDATION.md`
    *   `PRIVACY_AUDIT.md`
    *   `SECRET_SCAN_REPORT.md`
    *   `CLEAN_ROOM_VALIDATION.md`
    *   `RELEASE_CHECKLIST.md`
    *   `PUBLIC_FILES.md`
    *   `LOCAL_ONLY_FILES.md`
*   **`plugins/`**
    *   `agent-scanner/` (Manifesto e script local)
    *   `skills-scanner/` (Manifesto e script local)
    *   `examples/hello-plugin/` (Exemplo de extensão)
*   **`tests/`**
    *   `Test-HermesHub.ps1` (Suíte completa de testes)
    *   `fixtures/` (Dados isolados para testes automatizados)
*   **`tools/`**
    *   `Approve-HermesPlugin.ps1` (Utilitário interativo de aprovação)
