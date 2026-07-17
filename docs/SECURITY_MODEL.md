# 🛡️ Modelo de Segurança e Limitações do Hermes Hub

Este documento descreve honestamente o escopo de segurança, as políticas aplicadas e as limitações técnicas do ecossistema de plugins do **Hermes Agent Hub v0.3.0-rc.1**.

---

## 1. Ausência de Sandbox de Sistema Operacional (Sandbox Real)

> [!WARNING]
> O Hermes Agent Hub **não executa scripts em um sandbox real de sistema operacional**. Ele não isola processos por meio de containers, virtualização ou restrições nativas de nível de Kernel do Windows.

*   **Plugins Locais são Confiáveis:** Todo plugin habilitado e executado pelo core roda no mesmo espaço de usuário e com os mesmos privilégios do console PowerShell que disparou o `Start-HermesHub.ps1`.
*   **Permissões como Metadados de Auditoria:** O campo `"permissions"` declarado no manifesto `plugin.json` serve exclusivamente como metadados informativos para validação e documentação. O core rejeita permissões desconhecidas no manifesto para evitar configurações inválidas, mas **não bloqueia chamadas diretas de APIs do sistema** dentro dos scripts.
*   **Revisão Manual Obrigatória:** Antes de habilitar qualquer plugin de terceiros, o usuário deve auditar manualmente o código-fonte dos scripts (`.ps1`, `.psm1`, `.psd1`) para assegurar que não há comandos destrutivos ou de roubo de credenciais.

---

## 2. Contenção de Caminhos e Links Simbólicos

O sistema aplica uma política estrita de contenção física de arquivos locais:
*   **Caminho Canônico:** O core resolve o caminho real final dos arquivos executáveis e entrypoints.
*   **Bloqueio de Path Traversal:** Entrypoints que tentam usar links relativos (`..`) para escapar do diretório físico do plugin são invalidados.
*   **Reparse Points, Symlinks e Junctions:** Links simbólicos que apontam para diretórios ou arquivos externos à pasta do plugin são detectados e bloqueados sumariamente.
*   **Normalização UNC:** Entrypoints que comecem com caminhos de rede (`\\server\share`) são bloqueados.

---

## 3. Validação Estática Não Garante Segurança Absoluta

A verificação automatizada de conformidade e integridade realizada pelo `PluginValidator`:
*   Garante que o manifesto e a estrutura de arquivos estão corretos;
*   Impede a execução caso arquivos tenham sido alterados após a aprovação;
*   **Não realiza análise de comportamento em tempo de execução** para bloquear vírus ou malwares complexos.
