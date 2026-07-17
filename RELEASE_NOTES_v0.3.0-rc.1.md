# 📢 Notas de Lançamento — Hermes Hub v0.3.0-rc.1 (Release Candidate)

Esta versão oficializa o endurecimento de segurança e o fechamento do ecossistema de plugins extensíveis no **Hermes Agent Hub**.

---

## 🚀 O que há de novo na v0.3.0-rc.1

### 1. Modelo de Confiança Efetiva e Dissociação de Metadados
A autorização de plugins é gerenciada pelo Core por meio de trust stores externos:
*   `config/builtin-plugins.json` (versionado no repositório) define os plugins builtin oficiais (`agent-scanner`, `skills-scanner` e `hello-plugin`).
*   `data/plugin-trust.json` (local e ignorado) gerencia aprovações locais.
*   Novos plugins não autorizados são marcados como `untrusted` e bloqueados.

### 2. Verificação de Integridade Física (Hashes SHA-256)
*   Baseline de hashes SHA-256 de todos os scripts executáveis salvos em `config/builtin-integrity.json` e `data/trusted-integrity.json`.
*   Verificação pré-execução bloqueia qualquer plugin cujas baselines divirjam do disco.

### 3. Ferramenta Interativa de Aprovação
*   Disponibilizado o script `tools/Approve-HermesPlugin.ps1` que valida, apresenta permissões e hashes, solicita confirmação do usuário e adiciona o plugin na trust store de integridade correspondente.

### 4. Proteção de Caminhos Canônicos
*   Checagem case-insensitive para Windows e bloqueio de junctions, reparse points e symlinks que apontem para locais fora da pasta do plugin.
*   Bloqueio de entrypoints UNC (`\\`).

### 5. Permissões Oficiais Reconhecidas
*   `filesystem.read`, `filesystem.write.project`, `process.read`, `process.version`, `config.read`, `output.write.project`.
*   Permissões não reconhecidas invalidam o manifesto.
