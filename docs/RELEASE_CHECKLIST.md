# 📋 Checklist de Publicação da Release Candidate

Este documento detalha o checklist final para liberação da versão do **Hermes Agent Hub**.

---

## 1. Verificações de Qualidade e Testes
- [x] **66 testes anteriores preservados** (Todos com 100% de sucesso).
- [ ] **Novos testes de empacotamento aprovados** (Testes da Fase 11).
- [ ] **Clean-room test aprovado** (Execução isolada de primeiro download bem sucedida).

---

## 2. Auditoria e Segurança
- [x] **Nenhum segredo encontrado** (Relatório de varredura estática de segredos OK).
- [x] **Nenhum caminho pessoal publicado** (Busca estática de SCHAE e caminhos absolutos removidos).
- [x] **Hashes builtin estáveis** (Normalização LF concluída com sucesso).

---

## 3. Empacotamento de Distribuição
- [ ] **ZIP criado** (Compilação da versão de staging em dist/).
- [ ] **Checksum validado** (Geração e verificação do arquivo sha256).
- [x] **README conferido** (Instruções em inglês e português consistentes com a Fase 3.2).
- [x] **Licença conferida** (MIT incluída).
- [x] **Dashboard conferido** (Apresentando dados reais estruturados de segurança).

---

## 4. Status de Publicação Remota
- [x] **Publicação ainda não realizada** (Nenhuma chamada externa ou commit de remoto efetuado).
