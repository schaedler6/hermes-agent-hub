# ==========================================
# Helper-Functions.ps1 — Funções Utilitárias
# ==========================================

function Get-CommandPath {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

function Invoke-WithTimeout {
    param(
        [string]$FilePath,
        [string]$ArgumentList,
        [int]$TimeoutMs = 2000
    )
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $FilePath
        $psi.Arguments = $ArgumentList
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $p = [System.Diagnostics.Process]::Start($psi)
        if ($p.WaitForExit($TimeoutMs)) {
            $stdout = $p.StandardOutput.ReadToEnd()
            $stderr = $p.StandardError.ReadToEnd()
            return [PSCustomObject]@{
                ExitCode = $p.ExitCode
                Output   = "$stdout $stderr".Trim()
                TimedOut = $false
            }
        } else {
            try {
                $p.Kill()
            } catch {}
            return [PSCustomObject]@{
                ExitCode = -1
                Output   = ""
                TimedOut = $true
            }
        }
    } catch {
        return [PSCustomObject]@{
            ExitCode = -2
            Output   = $_.Exception.Message
            TimedOut = $false
        }
    }
}

function Get-VersionSafe {
    param(
        [string]$Executable,
        [string]$ArgsList = "--version",
        [int]$TimeoutMs = 2000
    )
    
    $resolvedPath = $Executable
    if (-not (Test-Path $Executable -ErrorAction SilentlyContinue)) {
        $resolvedPath = Get-CommandPath $Executable
        if (-not $resolvedPath) {
            return "Desconhecida (Executável não encontrado)"
        }
    }
    
    $res = Invoke-WithTimeout -FilePath $resolvedPath -ArgumentList $ArgsList -TimeoutMs $TimeoutMs
    if ($res.TimedOut) {
        return "Desconhecida (Timeout)"
    }
    
    if ($res.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($res.Output)) {
        $res = Invoke-WithTimeout -FilePath $resolvedPath -ArgumentList "-v" -TimeoutMs $TimeoutMs
        if ($res.TimedOut -or $res.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($res.Output)) {
            $res = Invoke-WithTimeout -FilePath $resolvedPath -ArgumentList "version" -TimeoutMs $TimeoutMs
        }
    }
    
    if ($res.TimedOut) { return "Desconhecida (Timeout)" }
    if ([string]::IsNullOrWhiteSpace($res.Output)) { return "Desconhecida" }
    
    if ($res.Output -match '(\d+\.\d+\.\d+\S*)') {
        return $Matches[1]
    }
    
    $linhas = $res.Output -split '\r?\n'
    foreach ($linha in $linhas) {
        if (-not [string]::IsNullOrWhiteSpace($linha)) {
            return $linha.Trim()
        }
    }
    
    return "Desconhecida"
}

# As funções acima estarão disponíveis via dot-sourcing no escopo chamador.
