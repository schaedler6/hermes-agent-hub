# ==========================================
# Get-AgentVersion.ps1
# Obtém a versão de um executável com timeout
# ==========================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ExecutablePath,
    
    [Parameter(Mandatory=$false)]
    [string]$ArgsList = "--version",
    
    [Parameter(Mandatory=$false)]
    [int]$TimeoutMs = 3000
)

function Get-CommandPathLocal {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

# Resolve caminho se não for absoluto
$resolvedPath = $ExecutablePath
if (-not (Test-Path $ExecutablePath -ErrorAction SilentlyContinue)) {
    $resolvedPath = Get-CommandPathLocal -Name $ExecutablePath
    if (-not $resolvedPath) {
        return "desconhecida"
    }
}

try {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $resolvedPath
    $psi.Arguments = $ArgsList
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = [System.Diagnostics.Process]::Start($psi)
    
    # Timeout máximo de 5 segundos, respeitando o parâmetro
    $actualTimeout = [Math]::Min($TimeoutMs, 5000)
    
    if ($p.WaitForExit($actualTimeout)) {
        $stdout = $p.StandardOutput.ReadToEnd()
        $stderr = $p.StandardError.ReadToEnd()
        $output = "$stdout $stderr".Trim()
        
        if ($p.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($output)) {
            # Tenta "-v" como fallback
            $psi.Arguments = "-v"
            $p2 = [System.Diagnostics.Process]::Start($psi)
            if ($p2.WaitForExit($actualTimeout)) {
                $output = ($p2.StandardOutput.ReadToEnd() + " " + $p2.StandardError.ReadToEnd()).Trim()
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($output)) {
            return "desconhecida"
        }
        
        # Regex para capturar padrão clássico de versão x.y.z
        if ($output -match '(\d+\.\d+\.\d+\S*)') {
            return $Matches[1]
        }
        
        # Retorna a primeira linha limpa se não achar padrão regex
        $linhas = $output -split '\r?\n'
        foreach ($linha in $linhas) {
            if (-not [string]::IsNullOrWhiteSpace($linha)) {
                return $linha.Trim()
            }
        }
    } else {
        try { $p.Kill() } catch {}
        return "desconhecida"
    }
} catch {
    return "desconhecida"
}

return "desconhecida"
