# 🔌 Especificação Técnica de Plugins

Esta documentação descreve o formato de manifesto, esquemas JSON de metadados e os contratos de saída obrigatórios para desenvolvimento de extensões para o **Hermes Agent Hub**.

---

## 1. Schema do Manifesto (`plugin.json`)

Cada plugin deve possuir um arquivo `plugin.json` localizado na raiz de sua pasta com os seguintes campos obrigatórios:

| Campo | Tipo | Descrição | Exemplo |
| :--- | :--- | :--- | :--- |
| `id` | String | Identificador único contendo letras, números, hifens e underlines. | `"agent-scanner"` |
| `name` | String | Nome visível do plugin para apresentação. | `"Agent Scanner"` |
| `version` | String | Versão semântica clássica (x.y.z). | `"0.1.0"` |
| `author` | String | Autor do plugin. | `"Sid Schaedler"` |
| `description` | String | Resumo sucinto do propósito do plugin. | `"Identifica agentes instalados"` |
| `category` | String | Categoria do plugin (`agents`, `skills`, `models`, `workflows`, etc.). | `"agents"` |
| `entrypoint` | String | Script PowerShell relativo executável do plugin. | `"scan.ps1"` |
| `enabled` | Boolean | Define se o plugin deve ser executado. | `true` |
| `supportedPlatforms` | Array | Lista de SOs suportados. Deve conter `"windows"`. | `["windows"]` |
| `permissions` | Array | Permissões solicitadas (`filesystem.read`, `process.read`). | `["filesystem.read"]` |
| `outputs` | Array | Tipos de dados de inventário retornados. | `["agents"]` |

---

## 2. Contrato de Saída do Entrypoint

O entrypoint PowerShell (`scan.ps1`) deve obrigatoriamente retornar na console ou em memória um objeto no seguinte formato de contrato padrão do Hermes Hub:

```json
{
  "pluginId": "agent-scanner",
  "category": "agents",
  "scannedAt": "dd/MM/yyyy HH:mm:ss",
  "status": "success",
  "items": [],
  "warnings": [],
  "errors": []
}
```

### Detalhe das Propriedades
*   `status`: Pode ser `"success"`, `"warning"` ou `"error"`.
*   `items`: Array contendo os itens inventariados (por exemplo, objetos detalhados de agentes ou regras de skills).
*   `warnings`: Lista de avisos ou inconformidades leves registradas na varredura.
*   `errors`: Lista de erros fatais que impediram o plugin de processar algum detector ou item.

---

## 3. Tratamento de Erros de Validação

Caso o plugin desobedeça as regras de segurança (como entrypoint inacessível ou fora da pasta física do plugin), o `PluginValidator` o marcará com status `invalid` e registrará os erros na tabela de plugins do Dashboard. O plugin nunca será executado nessas condições.
