param([int]$WaitMinutes = 720, [int]$ObserveSeconds = 180, [int[]]$TestProcessIds = @(), [switch]$Continuous)
$ErrorActionPreference = 'Stop'
$enginePath = 'C:\Dev\LuminaClient\godot-engine\bin\godot.windows.editor.x86_64.exe'
$diagnosticDir = 'C:\Dev\LuminaClient\mirror-godot-app\.lumina-bridge\diagnostics'
New-Item -ItemType Directory -Path $diagnosticDir -Force | Out-Null
$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $diagnosticDir "watch-$runStamp.log"
function Write-Diagnostic([string]$message) {
    $line = (Get-Date -Format o) + ' ' + $message
    Add-Content -LiteralPath $logPath -Value $line
    Write-Output $line
}
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class LuminaHangDump {
    [DllImport("Dbghelp.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MiniDumpWriteDump(IntPtr process, uint processId,
        IntPtr file, uint dumpType, IntPtr exception, IntPtr stream, IntPtr callback);
}
'@
$baselineIds = @(Get-Process godot* -ErrorAction SilentlyContinue | Where-Object { $_.Id -notin $TestProcessIds } | ForEach-Object { $_.Id })
$tracked = @{}
$gameLog = Join-Path $env:APPDATA 'Godot\app_userdata\The Mirror\logs\godot.log'
$lastLogLength = if (Test-Path -LiteralPath $gameLog) { (Get-Item -LiteralPath $gameLog).Length } else { 0 }
$waitUntil = (Get-Date).AddMinutes($WaitMinutes)
$observeUntil = $null
Write-Diagnostic 'Waiting for user-started Play. This watcher never launches the game.'
while ((Get-Date) -lt $waitUntil) {
    foreach ($trackedId in @($tracked.Keys)) {
        $existing = Get-Process -Id $trackedId -ErrorAction SilentlyContinue
        if (-not $existing -or $existing.StartTime -ne $tracked[$trackedId].StartTime) {
            Write-Diagnostic "Process $trackedId exited. Waiting for the next user-started run."
            $tracked.Remove($trackedId)
        }
    }
    $candidates = @(Get-Process godot* -ErrorAction SilentlyContinue | Where-Object { $_.Id -notin $baselineIds })
    foreach ($candidate in $candidates) {
        try {
            if ($candidate.Path -ne $enginePath) { continue }
            if (-not $tracked.ContainsKey($candidate.Id)) {
                # Only the actual game window or a native --server child qualifies.
                # Reopened editors and the project manager must never be throttled.
                $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($candidate.Id)").CommandLine
                $isHost = $commandLine -match '(?:^|\s)--server(?:\s|$)'
                if ($candidate.MainWindowTitle -ne 'The Mirror' -and -not $isHost) { continue }
            }
            $candidate.ProcessorAffinity = [IntPtr]3
            $candidate.PriorityClass = 'BelowNormal'
            if (-not $tracked.ContainsKey($candidate.Id)) {
                $tracked[$candidate.Id] = @{ HangSince = $null; LastCPU = $candidate.CPU; LastTime = Get-Date; StartTime = $candidate.StartTime }
                Write-Diagnostic "Protected process $($candidate.Id): two logical CPUs, below-normal priority."
                if ($null -eq $observeUntil) { $observeUntil = (Get-Date).AddSeconds($ObserveSeconds) }
            }
            $entry = $tracked[$candidate.Id]
            $now = Get-Date
            $logFlood = $false
            if (($now - $entry.LastTime).TotalSeconds -ge 5) {
                $percent = [math]::Round(($candidate.CPU - $entry.LastCPU) / ($now - $entry.LastTime).TotalSeconds / [Environment]::ProcessorCount * 100, 2)
                Write-Diagnostic "PID=$($candidate.Id) CPU=$percent% Responding=$($candidate.Responding) RAM_MB=$([math]::Round($candidate.WorkingSet64/1MB))"
                $entry.LastCPU = $candidate.CPU
                $entry.LastTime = $now
                if (Test-Path -LiteralPath $gameLog) {
                    $logLength = (Get-Item -LiteralPath $gameLog).Length
                    if ($logLength - $lastLogLength -gt 131072) {
                        $tail = @(Get-Content -LiteralPath $gameLog -Tail 160)
                        $invalidTransforms = @($tail | Where-Object { $_ -match '!v\.is_finite|\(nan, nan, nan\)' }).Count
                        $logFlood = $invalidTransforms -ge 20
                        if ($logFlood) { Write-Diagnostic 'Invalid-transform log flood detected; capturing and stopping this run.' }
                    }
                    $lastLogLength = $logLength
                }
            }
            if ($candidate.Responding) { $entry.HangSince = $null }
            elseif ($null -eq $entry.HangSince) { $entry.HangSince = Get-Date }
            if ($logFlood -or ($null -ne $entry.HangSince -and ((Get-Date) - $entry.HangSince).TotalSeconds -ge 15)) {
                $dumpPath = Join-Path $diagnosticDir "hang-$runStamp-$($candidate.Id).dmp"
                $stream = [IO.File]::Open($dumpPath, [IO.FileMode]::Create)
                try {
                    $written = [LuminaHangDump]::MiniDumpWriteDump($candidate.Handle, [uint32]$candidate.Id, $stream.SafeFileHandle.DangerousGetHandle(), 0, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
                    Write-Diagnostic "Hang captured=$written; Win32Error=$([Runtime.InteropServices.Marshal]::GetLastWin32Error()); file=$dumpPath"
                } finally { $stream.Dispose() }
                # Stop only newly observed test instances, never the existing editor.
                foreach ($testId in @($tracked.Keys)) {
                    $testProcess = Get-Process -Id $testId -ErrorAction SilentlyContinue
                    if ($testProcess -and $testProcess.Path -eq $enginePath -and $testProcess.StartTime -eq $tracked[$testId].StartTime) {
                        Stop-Process -Id $testId -ErrorAction SilentlyContinue
                    }
                }
                Write-Diagnostic 'Stopped hung diagnostic run. Editor left open.'
                if (-not $Continuous) { exit 2 }
                $tracked.Clear()
                break
            }
        } catch {
            Write-Diagnostic "Process $($candidate.Id): $($_.Exception.Message)"
        }
    }
    if (-not $Continuous -and $null -ne $observeUntil -and (Get-Date) -ge $observeUntil) {
        Write-Diagnostic 'Observation finished. No sustained window hang detected.'
        exit 0
    }
    Start-Sleep -Milliseconds 500
}
Write-Diagnostic 'Watch period ended.'
