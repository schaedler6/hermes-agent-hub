# 🛡️ Política de Segurança (Security Policy)

Este documento define as diretrizes de reporte de vulnerabilidades e a postura de segurança do **Hermes Agent Hub**.

---

## 1. Postura de Segurança e Limites de Isolamento

> [!IMPORTANT]
> **O Hermes Agent Hub não possui ou gerencia um sandbox nativo de sistema operacional.**
> Todos os scripts de plugins e detectores são executados dentro da mesma sessão e com os mesmos privilégios do console PowerShell do usuário ativo na máquina.

A validação de integridade de hashes SHA-256 e o modelo de aprovação externa servem como uma barreira de conformidade contra alterações acidentais de código e execução não autorizada de scripts locais de terceiros. **O usuário sempre deve revisar o código de scripts externos antes de aprová-los.**

---

## 2. Versões Suportadas

Atualmente, apenas as seguintes versões recebem atualizações de segurança:

| Versão | Suportada | Notas |
| :--- | :---: | :--- |
| `0.3.x` | Yes | Release Candidate v0.3.0-rc.1 |
| `< 0.3` | No | Atualize para obter as correções de trust stores locais. |

---

## 3. Reportando uma Vulnerabilidade

Para reportar uma vulnerabilidade ou comportamento de segurança inesperado:
1.  Não abra uma Issue pública no GitHub.
2.  Envie um e-mail detalhado contendo a descrição da falha e o passo a passo de reprodução para `security@sid-dev-br` (Endereço demonstrativo padrão).
3.  Responderemos dentro de 48 horas com uma avaliação do problema e um plano de mitigação.
