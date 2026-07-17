# 🤝 Contribuições (Contributing Guidelines)

Agradecemos o seu interesse em contribuir para o **Hermes Agent Hub**! 

---

## 1. Diretrizes Gerais

*   **Offline First:** Todas as implementações e novos plugins devem rodar de forma local e off-line. Chamadas externas à internet ou coletas de telemetria não são aceitas.
*   **Compatibilidade PowerShell 7:** O orquestrador e os plugins devem ser escritos para PowerShell 7+ nativo. Evite comandos ou aliases específicos do Windows PowerShell 5.1 se eles quebrarem a compatibilidade com macOS ou Linux futuramente.
*   **Qualidade e Testes:** Qualquer alteração no Core ou nos plugins integrados deve vir acompanhada da respectiva atualização ou criação de asserções em `tests/Test-HermesHub.ps1`.

---

## 2. Processo de Envio de Mudanças

1.  Faça um Fork do projeto.
2.  Crie uma branch local para a sua feature (`git checkout -b feature/minha-feature`).
3.  Implemente o código garantindo o alinhamento de line endings para LF (`.gitattributes`).
4.  Execute a suíte integrada de testes e certifique-se de que não há falhas:
    ```powershell
    pwsh .\tests\Test-HermesHub.ps1
    ```
5.  Faça o commit local e abra uma solicitação de Pull Request direcionada à branch principal do repositório.
