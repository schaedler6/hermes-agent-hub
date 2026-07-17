# 🔧 Guia de Solução de Problemas (Troubleshooting)

Encontre respostas para erros e comportamentos inesperados do Hermes Hub.

---

## 1. Erro de Assinatura/Integridade (Integrity Alert)
*   **Sintoma:** O plugin builtin ou trusted é exibido no Dashboard como `Bloqueado` e `Integridade violada`.
*   **Causa:** O código ou o manifesto `plugin.json` do plugin foi modificado após a homologação original, gerando divergência com a baseline de hashes SHA-256 gravada.
*   **Solução:** Se a modificação for legítima e feita por você, recalcule a baseline executando a ferramenta de aprovação interativa com o sinalizador de refresh correspondente:
    ```powershell
    pwsh .\tools\Approve-HermesPlugin.ps1 -PluginId "skills-scanner" -RefreshBuiltinIntegrity
    ```

---

## 2. Erro de Confiança do Plugin (untrusted)
*   **Sintoma:** O plugin não executa e apresenta o erro `Nível de confiança efetivo é untrusted`.
*   **Causa:** O plugin de terceiros não foi homologado explicitamente pelo usuário na base externa local.
*   **Solução:** Aprove o plugin utilizando a ferramenta de assinatura:
    ```powershell
    pwsh .\tools\Approve-HermesPlugin.ps1 -PluginId "id-do-plugin"
    ```

---

## 3. O Dashboard Não Abre Automaticamente
*   **Sintoma:** O terminal PowerShell conclui a varredura com sucesso, mas o navegador padrão não abre a interface visual.
*   **Causa:** Bloqueios de política do console ou restrições de permissões do navegador.
*   **Solução:** Você pode abrir o Dashboard manualmente abrindo o arquivo `dashboard/index.html` na pasta do projeto usando qualquer navegador de internet moderno de sua preferência.
