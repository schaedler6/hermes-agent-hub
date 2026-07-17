# 🧪 Validação em Ambiente Clean-Room (Staging)

Este relatório detalha a metodologia e resultados do teste clean-room efetuado sobre a distribuição.

---

## 1. Metodologia do Teste Clean-Room

Para simular o download inicial de um novo usuário em outra máquina, executamos o seguinte protocolo:
1.  Criamos um diretório temporário e isolado: `C:\Users\SCHAE\.gemini\antigravity\scratch\hermes-staging\`.
2.  Copiamos somente a lista estruturada de arquivos públicos aprovados em `PUBLIC_FILES.md`.
3.  **Não incluímos:** logs locais, configurações de máquina (`config.local.json`), inventários gerados (`data/agents.json`), ou trust stores locais (`data/plugin-trust.json`).
4.  Executamos a suíte de testes unitários inteira a partir do diretório isolado:
    ```powershell
    pwsh .\tests\Test-HermesHub.ps1
    ```
5.  Inicializamos o sistema em estado limpo:
    ```powershell
    pwsh .\Start-HermesHub.ps1
    ```

---

## 2. Resultados da Validação

*   **Inicialização sem erro:** O sistema detecta a ausência de arquivos e cria os dados de controle padrão com sucesso.
*   **Criação dos dados locais necessários:** As pastas `data/` e `logs/` são instanciadas sob demanda.
*   **Abertura do Dashboard:** O Dashboard visual é carregado sem falhas ou erros no console.
*   **Identificação de Plugins Builtin:** Os 3 plugins de distribuição (`agent-scanner`, `skills-scanner` e `hello-plugin`) são reconhecidos e suas baselines de integridade validadas com sucesso.
*   **Execução de Scanners:** O scanner builtin é executado perfeitamente no novo diretório isolado.
