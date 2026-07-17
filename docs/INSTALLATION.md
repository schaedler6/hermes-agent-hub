# ⚙️ Guia de Instalação — Hermes Agent Hub

Este guia descreve como instalar e configurar o **Hermes Agent Hub** em sua máquina Windows.

---

## 🚀 Requisitos de Sistema
*   **Sistema Operacional:** Windows 10 ou Windows 11.
*   **PowerShell:** Versão **7.0 ou superior** (`pwsh`).
*   **Dependências externas:** Nenhuma. A aplicação roda de forma 100% autônoma e offline.

---

## 📦 Passos para Instalação

### 1. Baixar a Distribuição
Baixe o arquivo comprimido `hermes-agent-hub-v0.3.0-rc.1.zip` da seção de Releases do projeto.

### 2. Extrair os Arquivos
Extraia o conteúdo do arquivo ZIP para um diretório permanente de sua preferência (ex: `C:\Users\SeuUsuario\hermes-agent-hub`).

### 3. Verificar Dependências do PowerShell 7
Abra o console e digite `pwsh --version`. Caso não possua o PowerShell 7 instalado, instale-o via winget:
```powershell
winget install Microsoft.PowerShell
```

### 4. Executar e Inicializar
Navegue até a pasta extraída no terminal e execute:
```powershell
pwsh .\Start-HermesHub.ps1
```
Isso iniciará o scanner de segurança e abrirá o painel do Dashboard local de forma automatizada no navegador web padrão da máquina.
