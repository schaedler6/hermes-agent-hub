# 📜 Registro de Alterações (Changelog) — Hermes Agent Hub

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.

---

## [0.3.0-rc.1] — 2026-07-17

Esta Release Candidate consolida o modelo de extensibilidade por plugins e traz endurecimento de segurança robusto.

### Adicionado
*   **Modelo de Confiança Efetivo:** Introdução de trust stores externas (`config/builtin-plugins.json` e `data/plugin-trust.json`) para revogar ou conceder privilégios de execução de scripts de plugins locais.
*   **Verificação de Integridade Física:** Verificação de integridade baseada em hashes SHA-256 executada no momento do carregamento (`config/builtin-integrity.json`).
*   **Utilitário Interativo de Assinatura:** Novo utilitário em `tools/Approve-HermesPlugin.ps1` para aprovação manual segura de plugins de terceiros.
*   **Proteção de Caminhos Canônicos:** Prevenção de Path Traversal no validador de manifesto através do bloqueio de junctions e symlinks que apontem para diretórios externos à pasta do plugin.
*   **Suíte de Testes Expandida:** Inclusão de testes da Fase 10 e 11, cobrindo cenários de integridade de hashes, permissões inválidas, caminhos pessoais, e funcionamento clean-room (totalizando 93 asserções válidas).

### Modificado
*   **Apresentação do Dashboard:** Painel do Dashboard atualizado com colunas detalhadas de integridade física, nível de confiança efetivo externa e motivos de bloqueio em conformidade com o novo modelo.

---

## [0.2.0] — 2026-06-15

### Adicionado
*   **Integração do Validador de Agent Skills:** Descoberta recursiva e análise estática de conformidade de arquivos `SKILL.md` (pontuações estruturais e alertas de risco).
*   **Suíte de Testes Integrada:** Introdução do script `tests/Test-HermesHub.ps1`.

---

## [0.1.0] — 2026-05-10

### Adicionado
*   **Lançamento do MVP:** Varredura local-first e dashboard visual premium de detecção de agentes de IA locais e servidores MCP.
