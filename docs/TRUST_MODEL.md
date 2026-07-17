# 🔑 Modelo de Confiança Efetiva (Trust Model)

Este documento descreve como a confiança efetiva e a autorização de execução de plugins são gerenciadas de forma externa e imutável pelo core do **Hermes Agent Hub v0.3.0-rc.1**.

---

## 1. Níveis de Confiança Efetivos

A confiança de um plugin **nunca** é determinada pelo campo `"trustLevel"` declarado dentro do seu manifesto `plugin.json` (que tem caráter meramente informativo). O core utiliza duas bases de dados externas e imutáveis para julgar a autorização de execução:

| Nível de Confiança | Repositório | Descrição | Execução |
| :--- | :--- | :--- | :--- |
| **`builtin`** | `config/builtin-plugins.json` (Versionado) | Plugins oficiais distribuídos junto com a ferramenta. | Permitido se habilitado |
| **`trusted`** | `data/plugin-trust.json` (Local / Ignorado) | Plugins de terceiros aprovados manualmente pelo usuário. | Permitido se habilitado |
| **`untrusted`** | Nenhuma das listas anteriores | Qualquer nova pasta de plugin descoberta no disco. | **Bloqueado** |

---

## 2. Baselines de Integridade (Hashes SHA-256)

Para prevenir alterações não autorizadas ou substituição maliciosa de scripts de plugins após a sua aprovação, o core exige correspondência de hash SHA-256 de todos os arquivos executáveis.

1.  **Integridade Builtin (`config/builtin-integrity.json`):**
    *   Mantém os hashes de referência dos plugins oficiais distribuídos.
    *   Qualquer divergência gera bloqueio de execução.
2.  **Integridade Trusted (`data/trusted-integrity.json`):**
    *   Mantém os hashes de referência dos plugins aprovados pelo usuário no console local.
    *   Qualquer divergência gera bloqueio imediato e alerta no Dashboard.

---

## 3. Fluxo de Execução e Bloqueios

```text
[Descoberta do Plugin]
         │
         ▼
[Verifica ID no config/builtin-plugins.json] ──► Sim ──► [Confiança: BUILTIN]
         │ Não
         ▼
[Verifica ID no data/plugin-trust.json] ──────► Sim ──► [Confiança: TRUSTED]
         │ Não
         ▼
[Confiança: UNTRUSTED] ──► [BLOQUEIO IMEDIATO]

         │ (Para BUILTIN / TRUSTED)
         ▼
[Valida Hashes contra a Baseline correspondente]
         │
         ├──► Hashes Batem ────────► [EXECUTA PLUGIN]
         └──► Divergência de Hash ──► [BLOQUEIO E ALERTA NO DASHBOARD]
```
