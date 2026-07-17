/* ==========================================================================
   APP LOGIC — HERMES AGENT HUB (Fase 2 - Product Polish)
   JavaScript Puro / Vanilla JS
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
    // 1. Inicializa o Efeito de Partículas no Background
    initParticles();
    
    // 2. Carrega e renderiza os dados do scanner
    loadHermesData();

    // 3. Configura a navegação SPA do menu lateral
    setupNavigation();
});

// Geração de partículas flutuantes dinâmicas
function initParticles() {
    const container = document.getElementById('particles-container');
    if (!container) return;
    
    const particleCount = 20;
    for (let i = 0; i < particleCount; i++) {
        const p = document.createElement('div');
        p.className = 'particle';
        
        const size = Math.random() * 3 + 2; // tamanho entre 2px e 5px
        const left = Math.random() * 100; // posição horizontal aleatória
        const delay = Math.random() * 15; // atraso na animação
        const duration = Math.random() * 12 + 10; // duração
        
        p.style.width = `${size}px`;
        p.style.height = `${size}px`;
        p.style.left = `${left}%`;
        p.style.animationDelay = `${delay}s`;
        p.style.animationDuration = `${duration}s`;
        
        if (Math.random() > 0.5) {
            p.style.backgroundColor = '#06b6d4'; // ciano
        } else {
            p.style.backgroundColor = '#2563eb'; // azul elétrico
        }
        
        container.appendChild(p);
    }
}

// Navegação entre views locais (SPA)
function setupNavigation() {
    const menuItems = document.querySelectorAll('.menu-item');
    const sections = document.querySelectorAll('.view-section');
    
    menuItems.forEach(item => {
        item.addEventListener('click', (e) => {
            const target = item.getAttribute('data-target');
            if (!target) return; // Link externo como github
            
            e.preventDefault();
            
            // Remove ativação de menus e seções
            menuItems.forEach(mi => mi.classList.remove('active'));
            sections.forEach(sec => sec.classList.remove('active'));
            
            // Ativa o clicado
            item.classList.add('active');
            const targetSection = document.getElementById(`view-${target}`);
            if (targetSection) {
                targetSection.classList.add('active');
            }
        });
    });
}

// Armazena todas as ferramentas carregadas para fins de filtro e busca
let agentsList = [];

function loadHermesData() {
    const data = window.HERMES_DATA;
    
    // Elementos da Interface
    const valScannedAt = document.getElementById('val-scanned-at');
    const dashScannedAt = document.getElementById('dash-scanned-at');
    
    // Contadores do Dashboard
    const cntAgents = document.getElementById('cnt-agents');
    const cntMcp = document.getElementById('cnt-mcp');
    const cntSkills = document.getElementById('cnt-skills');
    const cntPlugins = document.getElementById('cnt-plugins');
    
    // Cards superiores do Dashboard
    const valDetected = document.getElementById('val-detected');
    const valRunning = document.getElementById('val-running');
    const valNotfound = document.getElementById('val-notfound');
    const valAlerts = document.getElementById('val-alerts');
    const descAlerts = document.getElementById('desc-alerts');
    const alertsBanner = document.getElementById('alerts-banner');
    const alertsList = document.getElementById('alerts-list');
    
    if (!data) {
        console.warn("Nenhum dado do Hermes Scanner localizado em window.HERMES_DATA.");
        document.getElementById('agents-grid').innerHTML = `
            <div class="card" style="grid-column: 1/-1; padding: 40px; text-align: center; border-color: var(--red-alert);">
                <h3 style="color: var(--red-alert); margin-bottom: 10px;">Nenhum inventário de agentes localizado</h3>
                <p style="color: var(--color-text-secondary); font-size: 0.95rem;">
                    Por favor, execute o scanner local no terminal utilizando o comando:<br>
                    <code style="display: inline-block; background: rgba(255,255,255,0.05); padding: 6px 12px; border-radius: 6px; margin-top: 10px; color: var(--cyan-neon);">pwsh .\\Start-HermesHub.ps1</code>
                </p>
            </div>
        `;
        return;
    }
    
    // Atualiza estatísticas do cabeçalho e cards
    const scannedDateStr = data.scannedAt || 'Não disponível';
    valScannedAt.innerText = scannedDateStr;
    if (dashScannedAt) dashScannedAt.innerText = scannedDateStr;
    
    const detectedVal = data.summary?.detectedCount || 0;
    valDetected.innerText = detectedVal;
    if (cntAgents) cntAgents.innerText = detectedVal;
    
    valRunning.innerText = data.summary?.runningCount || 0;
    valNotfound.innerText = data.summary?.notFoundCount || 0;
    
    // Extrai quantidade real de MCP configurados
    agentsList = data.agents || [];
    const mcpAgent = agentsList.find(a => a.name.toLowerCase() === 'mcp servers');
    let mcpCountReal = 0;
    if (mcpAgent && mcpAgent.detected && mcpAgent.version) {
        if (mcpAgent.version.match(/Configured:\s*(\d+)/)) {
            mcpCountReal = parseInt(RegExp.$1, 10);
        }
    }
    if (cntMcp) cntMcp.innerText = mcpCountReal;
    
    // Inicializa e carrega dados das skills reais do validador
    loadHermesSkillsData(cntSkills);
    
    // Inicializa e carrega dados de plugins do manager
    loadHermesPluginsData(cntPlugins);
    
    const alertsCount = data.summary?.alertsCount || 0;
    valAlerts.innerText = alertsCount;
    
    if (alertsCount > 0) {
        valAlerts.style.color = '#f59e0b';
        descAlerts.innerText = 'Verifique os avisos';
        descAlerts.style.color = '#f59e0b';
        
        alertsBanner.classList.remove('hidden');
        alertsList.innerHTML = '';
        if (data.summary.alerts) {
            data.summary.alerts.forEach(al => {
                const li = document.createElement('li');
                li.innerText = al;
                alertsList.appendChild(li);
            });
        }
    } else {
        valAlerts.style.color = 'var(--color-text-primary)';
        descAlerts.innerText = 'Sem anomalias';
        descAlerts.style.color = 'var(--color-text-muted)';
        alertsBanner.classList.add('hidden');
    }
    
    // Carrega o log de execução se presente no payload
    const logContentArea = document.getElementById('log-content-area');
    if (logContentArea && data.latestLog) {
        logContentArea.innerText = data.latestLog;
    }
    
    // Preenche as categorias dinamicamente no Select
    populateCategoryFilter(agentsList);
    
    // Renderiza a grade de agentes
    renderAgents(agentsList);
    
    // Renderiza os MCP Servers na aba MCP
    renderMcpServers(mcpAgent);
    
    // Configura Listeners de Busca e Filtros
    setupFilters();
}

function populateCategoryFilter(agents) {
    const categorySelect = document.getElementById('filter-category');
    if (!categorySelect) return;
    
    const categories = new Set();
    agents.forEach(a => {
        if (a.category) categories.add(a.category);
    });
    
    categorySelect.innerHTML = '<option value="all">Todas as Categorias</option>';
    
    categories.forEach(cat => {
        const opt = document.createElement('option');
        opt.value = cat.toLowerCase();
        opt.innerText = cat;
        categorySelect.appendChild(opt);
    });
}

function renderAgents(agents) {
    const grid = document.getElementById('agents-grid');
    if (!grid) return;
    
    if (agents.length === 0) {
        grid.innerHTML = `
            <div style="grid-column: 1/-1; padding: 40px; text-align: center; color: var(--color-text-muted);">
                Nenhuma ferramenta localizada com os filtros selecionados.
            </div>
        `;
        return;
    }
    
    grid.innerHTML = '';
    agents.forEach((agent, index) => {
        const card = document.createElement('div');
        card.className = 'card agent-card';
        card.id = `agent-card-${index}`;
        
        let avatarIcon = "🤖";
        if (agent.name.toLowerCase().includes('ollama')) avatarIcon = "🦙";
        else if (agent.name.toLowerCase().includes('docker')) avatarIcon = "🐳";
        else if (agent.name.toLowerCase().includes('claude')) avatarIcon = "🧠";
        else if (agent.name.toLowerCase().includes('mcp')) avatarIcon = "🔌";
        else if (agent.name.toLowerCase().includes('studio')) avatarIcon = "🏢";
        else if (agent.name.toLowerCase().includes('roo')) avatarIcon = "🦘";
        else if (agent.name.toLowerCase().includes('openmanus')) avatarIcon = "👐";
        
        const badgeClass = agent.detected ? 'success' : 'danger';
        const badgeText = agent.detected ? 'Instalado' : 'Ausente';
        
        const runningClass = agent.running ? 'active' : '';
        const runningText = agent.running ? 'Em Execução' : 'Inativo';
        
        card.innerHTML = `
            <div class="agent-card-header">
                <div class="agent-avatar">${avatarIcon}</div>
                <span class="badge ${badgeClass}">${badgeText}</span>
            </div>
            <div class="agent-card-body">
                <h4>${agent.name}</h4>
                <span class="agent-category">${agent.category}</span>
                <p class="agent-version-row">Versão: <strong>${agent.version || 'desconhecida'}</strong></p>
                <p class="agent-notes">${agent.notes || 'Sem observações adicionais.'}</p>
            </div>
            <div class="agent-card-footer">
                <div class="agent-running-status">
                    <span class="running-dot ${runningClass}"></span>
                    <span class="running-text ${runningClass}">${runningText}</span>
                </div>
                <button class="btn-details" id="btn-det-${index}" onclick="showAgentDetails(${index})">
                    Detalhes
                </button>
            </div>
        `;
        
        grid.appendChild(card);
    });
}

function renderMcpServers(mcpAgent) {
    const grid = document.getElementById('mcp-grid');
    if (!grid) return;
    
    if (!mcpAgent || !mcpAgent.detected) {
        grid.innerHTML = `
            <div class="card" style="grid-column: 1/-1; padding: 40px; text-align: center; color: var(--color-text-secondary);">
                Nenhum servidor MCP configurado no Claude Desktop foi detectado.
            </div>
        `;
        return;
    }
    
    grid.innerHTML = `
        <div class="card mcp-card">
            <div class="mcp-card-header">
                <h3>Claude Desktop Config</h3>
                <span class="badge success">Instalado</span>
            </div>
            <div class="mcp-meta-row">
                <strong>Arquivo:</strong> <code>claude_desktop_config.json</code>
            </div>
            <div class="mcp-meta-row">
                <strong>Caminho:</strong> <code>${mcpAgent.installPath}</code>
            </div>
            <div class="mcp-meta-row">
                <strong>Servidores Configuráveis:</strong> ${mcpAgent.version}
            </div>
            <div class="mcp-meta-row" style="margin-top: 12px; color: var(--color-text-secondary); font-size: 0.8rem; line-height: 1.4;">
                🔒 <em>Por políticas de privacidade, os argumentos e credenciais dos servidores MCP locais não são listados na interface.</em>
            </div>
        </div>
    `;
}

function setupFilters() {
    const searchInput = document.getElementById('search-input');
    const categorySelect = document.getElementById('filter-category');
    const statusSelect = document.getElementById('filter-status');
    
    if (!searchInput) return;
    
    const filterFn = () => {
        const query = searchInput.value.toLowerCase();
        const categoryVal = categorySelect.value;
        const statusVal = statusSelect.value;
        
        const filtered = agentsList.filter(agent => {
            const matchesSearch = agent.name.toLowerCase().includes(query) || 
                                  agent.category.toLowerCase().includes(query) ||
                                  (agent.notes && agent.notes.toLowerCase().includes(query));
                                  
            const matchesCategory = categoryVal === 'all' || 
                                    agent.category.toLowerCase() === categoryVal;
                                    
            let matchesStatus = true;
            if (statusVal === 'installed') {
                matchesStatus = agent.detected === true;
            } else if (statusVal === 'running') {
                matchesStatus = agent.running === true;
            } else if (statusVal === 'notfound') {
                matchesStatus = agent.detected === false;
            }
            
            return matchesSearch && matchesCategory && matchesStatus;
        });
        
        renderAgents(filtered);
    };
    
    searchInput.addEventListener('input', filterFn);
    categorySelect.addEventListener('change', filterFn);
    statusSelect.addEventListener('change', filterFn);
}

// Modal de Detalhes
function showAgentDetails(index) {
    const agent = agentsList[index];
    if (!agent) return;
    
    document.getElementById('modal-agent-name').innerText = agent.name;
    document.getElementById('modal-agent-category').innerText = agent.category;
    document.getElementById('modal-agent-version').innerText = agent.version || 'desconhecida';
    document.getElementById('modal-agent-executable').innerText = agent.executable || 'N/A';
    document.getElementById('modal-agent-path').innerText = agent.installPath || '---';
    document.getElementById('modal-agent-method').innerText = agent.detectionMethod || '---';
    document.getElementById('modal-agent-scanned').innerText = agent.scannedAt || '---';
    document.getElementById('modal-agent-notes').innerText = agent.notes || 'Sem observações adicionais gravadas.';
    
    const badge = document.getElementById('modal-agent-badge');
    badge.className = 'agent-badge';
    
    if (agent.running) {
        badge.classList.add('success');
        badge.innerText = 'Em Execução';
        badge.style.backgroundColor = 'rgba(6, 182, 212, 0.15)';
        badge.style.color = '#06b6d4';
        badge.style.border = '1px solid rgba(6, 182, 212, 0.3)';
    } else if (agent.detected) {
        badge.classList.add('success');
        badge.innerText = 'Instalado';
        badge.style.backgroundColor = 'rgba(16, 185, 129, 0.1)';
        badge.style.color = 'var(--green-success)';
        badge.style.border = '1px solid rgba(16, 185, 129, 0.2)';
    } else {
        badge.classList.add('danger');
        badge.innerText = 'Não Encontrado';
        badge.style.backgroundColor = 'rgba(239, 68, 68, 0.1)';
        badge.style.color = 'var(--red-alert)';
        badge.style.border = '1px solid rgba(239, 68, 68, 0.2)';
    }
    
    const modal = document.getElementById('details-modal');
    modal.classList.add('active');
    
    const closeBtn = document.getElementById('close-modal-btn');
    const closeFn = () => {
        modal.classList.remove('active');
        closeBtn.removeEventListener('click', closeFn);
        modal.removeEventListener('click', outsideClickFn);
    };
    
    const outsideClickFn = (e) => {
        if (e.target === modal) {
            closeFn();
        }
    };
    
    closeBtn.addEventListener('click', closeFn);
    modal.addEventListener('click', outsideClickFn);
}
window.showAgentDetails = showAgentDetails;

function triggerScanAdvice() {
    alert("Para rodar o scanner local do Hermes Agent Hub de forma síncrona e atualizar os dados, feche este dashboard e execute no console:\n\npwsh .\\Start-HermesHub.ps1");
}
window.triggerScanAdvice = triggerScanAdvice;

// ==========================================================================
// SEÇÃO DE GERENCIAMENTO DE AGENT SKILLS (FASE 2 - PARTE 2)
// ==========================================================================

// Função auxiliar de escape HTML contra XSS
function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return str.toString()
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

let skillsList = [];

// Carrega os dados reais do scanner de skills
function loadHermesSkillsData(cntSkillsDashboardElement) {
    const sData = window.HERMES_SKILLS_DATA;
    
    // Elementos da Interface
    const statTotal = document.getElementById('skill-stat-total');
    const statValid = document.getElementById('skill-stat-valid');
    const statWarnings = document.getElementById('skill-stat-warnings');
    const statRisk = document.getElementById('skill-stat-risk');
    
    if (!sData) {
        console.warn("Nenhum dado do validador de Skills localizado em window.HERMES_SKILLS_DATA. Modo de estado vazio.");
        if (cntSkillsDashboardElement) cntSkillsDashboardElement.innerText = "0";
        renderSkills([]);
        return;
    }
    
    // Atualiza contadores
    const totalCount = sData.summary?.totalCount || 0;
    if (statTotal) statTotal.innerText = totalCount;
    if (cntSkillsDashboardElement) cntSkillsDashboardElement.innerText = totalCount;
    
    if (statValid) statValid.innerText = sData.summary?.validCount || 0;
    if (statWarnings) statWarnings.innerText = sData.summary?.warningCount || 0;
    
    const riskCount = sData.summary?.highRiskCount || 0;
    if (statRisk) {
        statRisk.innerText = riskCount;
        if (riskCount > 0) {
            statRisk.style.color = 'var(--red-alert)';
        } else {
            statRisk.style.color = 'var(--color-text-primary)';
        }
    }
    
    skillsList = sData.skills || [];
    
    // Renderiza a grade de skills
    renderSkills(skillsList);
    
    // Configura filtros de skills
    setupSkillsFilters();
}

function renderSkills(skills) {
    const grid = document.getElementById('skills-grid');
    if (!grid) return;
    
    if (skills.length === 0) {
        grid.innerHTML = `
            <div style="grid-column: 1/-1; padding: 40px; text-align: center; color: var(--color-text-muted);">
                Nenhuma habilidade (Agent Skill) localizada com os filtros selecionados.
            </div>
        `;
        return;
    }
    
    grid.innerHTML = '';
    skills.forEach((skill, index) => {
        const card = document.createElement('div');
        card.className = 'card agent-card';
        card.id = `skill-card-${index}`;
        
        const badgeClass = skill.valid ? 'success' : 'danger';
        const badgeText = skill.valid ? 'Estrutura OK' : 'Inválida';
        
        const riskClass = skill.riskLevel === 'high' ? 'active' : '';
        const riskText = skill.riskLevel === 'high' ? 'Risco Alto 🚨' : 
                         skill.riskLevel === 'medium' ? 'Risco Médio' : 'Risco Baixo';
        
        // Ícones de componentes localizados
        let componentsHtml = '';
        if (skill.hasScripts) componentsHtml += '<span title="Scripts inclusos" style="margin-right: 6px;">📜 Scripts</span>';
        if (skill.hasTests) componentsHtml += '<span title="Testes inclusos" style="margin-right: 6px;">🧪 Testes</span>';
        if (skill.hasTemplates) componentsHtml += '<span title="Templates inclusos" style="margin-right: 6px;">📁 Templates</span>';
        if (componentsHtml === '') componentsHtml = '<span style="color: var(--color-text-muted);">Apenas Documentação</span>';
        
        card.innerHTML = `
            <div class="agent-card-header">
                <div class="agent-avatar" style="color: var(--violet-subtle); background-color: rgba(124, 58, 237, 0.05);">⚡</div>
                <span class="badge ${badgeClass}">${badgeText}</span>
            </div>
            <div class="agent-card-body">
                <h4>${escapeHtml(skill.name)}</h4>
                <span class="agent-category" style="color: var(--violet-subtle);">SCORE: ${skill.score}/100</span>
                <p class="agent-version-row">Componentes: <br><strong style="font-size: 0.75rem; font-weight: normal; color: var(--color-text-secondary);">${componentsHtml}</strong></p>
                <p class="agent-notes">${escapeHtml(skill.description) || 'Sem descrição.'}</p>
            </div>
            <div class="agent-card-footer">
                <div class="agent-running-status">
                    <span class="running-dot ${riskClass}" style="background-color: ${skill.riskLevel === 'high' ? 'var(--red-alert)' : skill.riskLevel === 'medium' ? 'var(--gold-warning)' : 'var(--green-success)'}"></span>
                    <span class="running-text ${riskClass}" style="color: ${skill.riskLevel === 'high' ? 'var(--red-alert)' : skill.riskLevel === 'medium' ? 'var(--gold-warning)' : 'var(--color-text-secondary)'}">${riskText}</span>
                </div>
                <button class="btn-details" id="btn-skill-det-${index}" onclick="showSkillDetails(${index})">
                    Detalhes
                </button>
            </div>
        `;
        
        grid.appendChild(card);
    });
}

function setupSkillsFilters() {
    const searchInput = document.getElementById('skill-search-input');
    const validSelect = document.getElementById('skill-filter-valid');
    const riskSelect = document.getElementById('skill-filter-risk');
    const scoreSelect = document.getElementById('skill-filter-score');
    
    if (!searchInput) return;
    
    const filterFn = () => {
        const query = searchInput.value.toLowerCase();
        const validVal = validSelect.value;
        const riskVal = riskSelect.value;
        const scoreVal = scoreSelect.value;
        
        const filtered = skillsList.filter(skill => {
            const matchesSearch = skill.name.toLowerCase().includes(query) || 
                                  (skill.description && skill.description.toLowerCase().includes(query));
                                  
            let matchesValidity = true;
            if (validVal === 'valid') {
                matchesValidity = skill.valid === true;
            } else if (validVal === 'invalid') {
                matchesValidity = skill.valid === false;
            }
            
            const matchesRisk = riskVal === 'all' || skill.riskLevel === riskVal;
            
            let matchesScore = true;
            if (scoreVal === 'high') {
                matchesScore = skill.score >= 80;
            } else if (scoreVal === 'medium') {
                matchesScore = skill.score >= 50 && skill.score < 80;
            } else if (scoreVal === 'low') {
                matchesScore = skill.score < 50;
            }
            
            return matchesSearch && matchesValidity && matchesRisk && matchesScore;
        });
        
        renderSkills(filtered);
    };
    
    searchInput.addEventListener('input', filterFn);
    validSelect.addEventListener('change', filterFn);
    riskSelect.addEventListener('change', filterFn);
    scoreSelect.addEventListener('change', filterFn);
}

function showSkillDetails(index) {
    const skill = skillsList[index];
    if (!skill) return;
    
    // Injeta textos escapados
    document.getElementById('modal-skill-name').innerText = skill.name;
    document.getElementById('modal-skill-source').innerText = skill.source;
    document.getElementById('modal-skill-score').innerText = `${skill.score} / 100`;
    document.getElementById('modal-skill-path').innerText = skill.path;
    document.getElementById('modal-skill-scanned').innerText = skill.scannedAt || '---';
    document.getElementById('modal-skill-notes').innerText = skill.description || 'Sem descrição cadastrada.';
    
    const riskBadge = document.getElementById('modal-skill-risk');
    riskBadge.innerText = skill.riskLevel.toUpperCase();
    riskBadge.style.color = skill.riskLevel === 'high' ? 'var(--red-alert)' : 
                            skill.riskLevel === 'medium' ? 'var(--gold-warning)' : 'var(--green-success)';
                            
    const validBadge = document.getElementById('modal-skill-badge');
    validBadge.className = 'agent-badge';
    if (skill.valid) {
        validBadge.classList.add('success');
        validBadge.innerText = 'Válida';
        validBadge.style.backgroundColor = 'rgba(16, 185, 129, 0.1)';
        validBadge.style.color = 'var(--green-success)';
        validBadge.style.border = '1px solid rgba(16, 185, 129, 0.2)';
    } else {
        validBadge.classList.add('danger');
        validBadge.innerText = 'Inválida';
        validBadge.style.backgroundColor = 'rgba(239, 68, 68, 0.1)';
        validBadge.style.color = 'var(--red-alert)';
        validBadge.style.border = '1px solid rgba(239, 68, 68, 0.2)';
    }
    
    // Injeta componentes encontrados
    let compList = [];
    if (skill.hasScripts) compList.push('scripts/');
    if (skill.hasReferences) compList.push('references/');
    if (skill.hasTemplates) compList.push('templates/');
    if (skill.hasAssets) compList.push('assets/');
    if (skill.hasTests) compList.push('tests/');
    document.getElementById('modal-skill-components').innerText = compList.length > 0 ? compList.join(', ') : 'Apenas SKILL.md';
    
    // Preenche Erros
    const errBox = document.getElementById('modal-skill-errors-box');
    const errList = document.getElementById('modal-skill-errors-list');
    errList.innerHTML = '';
    if (skill.errors && skill.errors.length > 0) {
        errBox.classList.remove('hidden');
        skill.errors.forEach(err => {
            const li = document.createElement('li');
            li.innerText = err;
            errList.appendChild(li);
        });
    } else {
        errBox.classList.add('hidden');
    }
    
    // Preenche Avisos
    const warnBox = document.getElementById('modal-skill-warnings-box');
    const warnList = document.getElementById('modal-skill-warnings-list');
    warnList.innerHTML = '';
    if (skill.warnings && skill.warnings.length > 0) {
        warnBox.classList.remove('hidden');
        skill.warnings.forEach(warn => {
            const li = document.createElement('li');
            li.innerText = warn;
            warnList.appendChild(li);
        });
    } else {
        warnBox.classList.add('hidden');
    }
    
    const modal = document.getElementById('skill-details-modal');
    modal.classList.add('active');
    
    const closeBtn = document.getElementById('close-skill-modal-btn');
    const closeFn = () => {
        modal.classList.remove('active');
        closeBtn.removeEventListener('click', closeFn);
        modal.removeEventListener('click', outsideClickFn);
    };
    
    const outsideClickFn = (e) => {
        if (e.target === modal) {
            closeFn();
        }
    };
    
    closeBtn.addEventListener('click', closeFn);
    modal.addEventListener('click', outsideClickFn);
}
window.showSkillDetails = showSkillDetails;
window.loadHermesSkillsData = loadHermesSkillsData;

// ==========================================================================
// SEÇÃO DE GERENCIAMENTO DE PLUGINS (FASE 3)
// ==========================================================================

let pluginsList = [];

function loadHermesPluginsData(cntPluginsDashboardElement) {
    const pData = window.HERMES_PLUGINS_DATA;
    
    const statTotal = document.getElementById('plugin-stat-total');
    const statEnabled = document.getElementById('plugin-stat-enabled');
    const statDisabled = document.getElementById('plugin-stat-disabled');
    const statInvalid = document.getElementById('plugin-stat-invalid');
    
    if (!pData) {
        console.warn("Nenhum dado de plugins localizado em window.HERMES_PLUGINS_DATA. Modo de estado vazio.");
        if (cntPluginsDashboardElement) cntPluginsDashboardElement.innerText = "0";
        renderPlugins([]);
        return;
    }
    
    // Atualiza estatísticas do dashboard principal e da view de plugins
    const enabledCount = pData.summary?.enabledCount || 0;
    const totalCount = pData.summary?.totalCount || 0;
    
    if (cntPluginsDashboardElement) {
        cntPluginsDashboardElement.innerText = `${enabledCount} / ${totalCount}`;
    }
    
    if (statTotal) statTotal.innerText = totalCount;
    if (statEnabled) statEnabled.innerText = enabledCount;
    if (statDisabled) statDisabled.innerText = pData.summary?.disabledCount || 0;
    if (statInvalid) statInvalid.innerText = pData.summary?.invalidCount || 0;
    
    pluginsList = pData.plugins || [];
    renderPlugins(pluginsList);
}

function renderPlugins(plugins) {
    const tbody = document.getElementById('plugins-table-body');
    if (!tbody) return;
    
    if (plugins.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="7" style="padding: 24px; text-align: center; color: var(--color-text-muted);">
                    Nenhum plugin localizado ou configurado no sistema.
                </td>
            </tr>
        `;
        return;
    }
    
    tbody.innerHTML = '';
    plugins.forEach(p => {
        const tr = document.createElement('tr');
        tr.style.borderBottom = '1px solid rgba(255, 255, 255, 0.03)';
        
        // Status Badge
        let statusBadge = '';
        if (p.status === 'enabled') {
            statusBadge = '<span class="badge success" style="background-color: rgba(16, 185, 129, 0.15); color: var(--green-success); border: 1px solid rgba(16, 185, 129, 0.3);">Habilitado</span>';
        } else if (p.status === 'disabled') {
            statusBadge = '<span class="badge" style="background-color: rgba(245, 158, 11, 0.1); color: #f59e0b; border: 1px solid rgba(245, 158, 11, 0.2);">Desabilitado</span>';
        } else {
            statusBadge = '<span class="badge danger" style="background-color: rgba(239, 68, 68, 0.1); color: var(--red-alert); border: 1px solid rgba(239, 68, 68, 0.2);">Bloqueado</span>';
        }
        
        // Confiança Declarada / Efetiva
        const decTrust = p.declaredTrust || 'untrusted';
        const effTrust = p.effectiveTrust || 'untrusted';
        let trustSourceBadge = '';
        if (p.trustSource === 'builtin') {
            trustSourceBadge = '<span style="font-size: 0.75rem; color: var(--green-success); background: rgba(16, 185, 129, 0.1); padding: 1px 5px; border-radius: 3px; border: 1px solid rgba(16, 185, 129, 0.2);">Builtin</span>';
        } else if (p.trustSource === 'manual approval') {
            trustSourceBadge = '<span style="font-size: 0.75rem; color: #f59e0b; background: rgba(245, 158, 11, 0.1); padding: 1px 5px; border-radius: 3px; border: 1px solid rgba(245, 158, 11, 0.2);">Aprovação Local</span>';
        } else {
            trustSourceBadge = '<span style="font-size: 0.75rem; color: var(--red-alert); background: rgba(239, 68, 68, 0.1); padding: 1px 5px; border-radius: 3px; border: 1px solid rgba(239, 68, 68, 0.2);">Nenhuma</span>';
        }
        const trustHtml = `<div style="font-size: 0.85rem;">Declarada: <span style="font-family: monospace;">${escapeHtml(decTrust)}</span></div>
                           <div style="font-size: 0.85rem; font-weight: 600;">Efetiva: <span style="font-family: monospace;">${escapeHtml(effTrust)}</span> ${trustSourceBadge}</div>`;
        
        // Integridade Status
        let integrityBadge = '';
        if (p.integrityStatus === 'valid') {
            integrityBadge = '<span style="color: var(--green-success); font-weight: 600;">🟢 Válida</span>';
        } else if (p.integrityStatus === 'corrupted') {
            integrityBadge = '<span style="color: var(--red-alert); font-weight: 600;">🔴 Violada</span>';
        } else if (p.integrityStatus === 'missing') {
            integrityBadge = '<span style="color: #f59e0b; font-weight: 600;">🟡 Ausente</span>';
        } else {
            integrityBadge = '<span style="color: var(--color-text-muted);">⚪ Não verificada</span>';
        }
        
        // Aprovação
        const appVersion = p.approvedVersion || '---';
        const appDate = p.approvedAt || '---';
        const appHtml = `<div style="font-size: 0.8rem;">Versão: ${escapeHtml(appVersion)}</div>
                         <div style="font-size: 0.75rem; color: var(--color-text-muted);">${escapeHtml(appDate)}</div>`;
        
        // Permissões como tags
        let permsHtml = '';
        if (p.permissions && p.permissions.length > 0) {
            p.permissions.forEach(perm => {
                permsHtml += `<span style="display: inline-block; background: rgba(255,255,255,0.04); font-size: 0.7rem; padding: 2px 6px; border-radius: 4px; margin-right: 4px; margin-bottom: 4px; border: 1px solid rgba(255,255,255,0.06);">${escapeHtml(perm)}</span>`;
            });
        } else {
            permsHtml = '<span style="color: var(--color-text-muted); font-size: 0.75rem;">Nenhuma</span>';
        }
        
        // Erros / Motivo do Bloqueio
        let errsHtml = '';
        if (p.validationErrors && p.validationErrors.length > 0) {
            errsHtml = `<ul style="color: var(--red-alert); font-size: 0.75rem; list-style-type: disc; margin-left: 12px; padding: 0;">`;
            p.validationErrors.forEach(err => {
                errsHtml += `<li style="margin-bottom: 2px;">${escapeHtml(err)}</li>`;
            });
            errsHtml += `</ul>`;
        } else {
            errsHtml = '<span style="color: var(--green-success); font-size: 0.75rem;">✔ Conformidade OK</span>';
        }
        
        // Plugin Info
        const nameHtml = `<div><strong>${escapeHtml(p.name)}</strong></div>
                          <div style="font-size: 0.75rem; color: var(--color-text-muted); font-family: monospace;">ID: ${escapeHtml(p.id)}</div>
                          <div style="font-size: 0.75rem; color: var(--violet-subtle);">Cat: ${escapeHtml(p.category)}</div>`;
        
        tr.innerHTML = `
            <td style="padding: 14px 12px;">${nameHtml}</td>
            <td style="padding: 14px 12px;">${trustHtml}</td>
            <td style="padding: 14px 12px;">${integrityBadge}</td>
            <td style="padding: 14px 12px;">${appHtml}</td>
            <td style="padding: 14px 12px;">${statusBadge}</td>
            <td style="padding: 14px 12px;">${permsHtml}</td>
            <td style="padding: 14px 12px;">${errsHtml}</td>
        `;
        tbody.appendChild(tr);
    });
}

window.loadHermesPluginsData = loadHermesPluginsData;

