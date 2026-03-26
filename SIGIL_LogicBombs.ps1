#Requires -Version 5.1
<#
.SYNOPSIS
    SIGIL Logic Bombs Module - Trigger-Based Adversary Simulation

.DESCRIPTION
    Simulates "logic bomb" style adversary behaviors: techniques that activate
    based on conditions (time, process, event, file presence, user context) rather
    than running immediately. Each simulation generates realistic telemetry for
    detection engineering without causing persistent harm.

    Maps to MITRE ATT&CK techniques and includes full cleanup for every module.

    !! FOR ISOLATED LAB / CONTROLLED TEST ENVIRONMENTS ONLY !!
    !! DO NOT RUN ON PRODUCTION OR DOMAIN-JOINED SYSTEMS !!

.PARAMETER All
    Run all logic bomb simulations.

.PARAMETER TimeBomb
    T1053.005 + T1124 - Creates a scheduled task that fires 5 minutes from now.
    Simulates time-triggered malware activation.

.PARAMETER ProcessWatchBomb
    T1546.003 - WMI ActiveScript event subscription that fires when notepad.exe starts.
    Simulates process-triggered execution logic.

.PARAMETER FileDropBomb
    T1105 + T1547 - FileSystemWatcher that reacts to a sentinel file being created.
    Simulates a staged payload waiting for a dropper to signal it.

.PARAMETER LoginBomb
    T1547.001 - Registry HKCU Run key that also writes a marker to simulate
    logic that activates on user logon.

.PARAMETER DNSBeacon
    T1071.004 - Simulates C2 DNS beaconing by making repeated DNS queries
    to a canary/test subdomain at a fixed interval.

.PARAMETER ShadowCopyWipe
    T1490 - Simulates shadow copy deletion commands (vssadmin) via WhatIf/echo
    only. No shadow copies are actually deleted.

.PARAMETER CredHarvest
    T1555 + T1003 - Simulates credential harvesting by reading DPAPI master key
    paths and writing their locations to a temp staging file.

.PARAMETER EnvTrigger
    T1082 + T1033 - System discovery logic bomb: collects hostname, username,
    domain, and installed AV product names. Simulates malware that only activates
    if it detects it is NOT in a sandbox.

.PARAMETER LOLBinChain
    T1218 + T1059 - Chains three LOLBins: certutil → rundll32 → regsvr32
    to simulate a staged LOLBin execution chain used for payload delivery evasion.

.PARAMETER WMIPersistence
    T1546.003 - Creates a WMI event filter + consumer + binding that executes
    notepad.exe when the system has been running for 60 seconds.
    Full cleanup removes all three WMI objects.

.PARAMETER Cleanup
    Remove all artifacts created by this module.

.PARAMETER DryRun
    Preview what each simulation would do without executing anything.

.PARAMETER LogPath
    Optional path to write a timestamped log file.

.EXAMPLE
    .\SIGIL_LogicBombs.ps1 -All -DryRun
    .\SIGIL_LogicBombs.ps1 -DNSBeacon -TimeBomb
    .\SIGIL_LogicBombs.ps1 -All -Cleanup
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$All,
    [switch]$TimeBomb,
    [switch]$ProcessWatchBomb,
    [switch]$FileDropBomb,
    [switch]$LoginBomb,
    [switch]$DNSBeacon,
    [switch]$ShadowCopyWipe,
    [switch]$CredHarvest,
    [switch]$EnvTrigger,
    [switch]$LOLBinChain,
    [switch]$WMIPersistence,
    [switch]$Cleanup,
    [switch]$DryRun,
    [string]$LogPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# ─────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────
$SIGIL_TAG           = "SIGIL_LB"
$TEMP_DIR            = Join-Path $env:TEMP $SIGIL_TAG
$TIMEBOMB_TASK       = "${SIGIL_TAG}_TimeBomb"
$LOGINBOMB_KEY       = "${SIGIL_TAG}_LoginBomb"
$FILEDROP_SENTINEL   = Join-Path $TEMP_DIR "SIGIL_SENTINEL.txt"
$FILEDROP_WATCHER    = $null  # populated at runtime
$WMI_FILTER_NAME     = "${SIGIL_TAG}_Filter"
$WMI_CONSUMER_NAME   = "${SIGIL_TAG}_Consumer"
$CRED_STAGING_FILE   = Join-Path $TEMP_DIR "cred_paths.txt"
$LOLBIN_TEMP_DLL     = Join-Path $TEMP_DIR "sigil_test.dll"
$LOLBIN_TEMP_B64     = Join-Path $TEMP_DIR "sigil_b64.txt"
$DNS_BEACON_DOMAIN   = "sigil-canary.example.com"   # Replace with your own canary domain
$DNS_BEACON_ROUNDS   = 5
$DNS_BEACON_INTERVAL = 3  # seconds between queries

# ─────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","PASS","FAIL","DRY","CLEAN","BOMB")]
        [string]$Level = "INFO"
    )
    $ts     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        "PASS"  { "[+]" }
        "FAIL"  { "[X]" }
        "WARN"  { "[!]" }
        "DRY"   { "[~]" }
        "CLEAN" { "[C]" }
        "BOMB"  { "[B]" }
        default { "[*]" }
    }
    $line = "[$ts] $prefix $Message"
    Write-Host $line
    if ($LogPath) { $line | Out-File -FilePath $LogPath -Append -Encoding UTF8 }
}

function Ensure-TempDir {
    if (-not (Test-Path $TEMP_DIR)) {
        New-Item -Path $TEMP_DIR -ItemType Directory -Force | Out-Null
        Write-Log "Working directory: $TEMP_DIR" INFO
    }
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 1: TIME BOMB
# T1053.005 + T1124
# Creates a scheduled task that fires exactly 5 minutes from now.
# Simulates malware that waits for a time condition before executing.
# ─────────────────────────────────────────────────────────────
function Invoke-TimeBomb {
    Write-Log "LOGIC BOMB: Time Bomb (T1053.005 + T1124)" BOMB
    Write-Log "  Creates a scheduled task that fires 5 minutes from now." INFO
    Write-Log "  Simulates time-triggered payload activation." INFO

    if ($DryRun) {
        $fireAt = (Get-Date).AddMinutes(5).ToString("HH:mm")
        Write-Log "DRY RUN - Would create task '$TIMEBOMB_TASK' to run notepad.exe at $fireAt" DRY
        return
    }
    try {
        $fireTime = (Get-Date).AddMinutes(5)
        $action   = New-ScheduledTaskAction -Execute "notepad.exe"
        $trigger  = New-ScheduledTaskTrigger -Once -At $fireTime
        Register-ScheduledTask -TaskName $TIMEBOMB_TASK `
            -Action $action -Trigger $trigger -Force | Out-Null
        Write-Log "T1053.005 [Time Bomb] Written to: Task Scheduler -> \$TIMEBOMB_TASK" PASS
        Write-Log "  Action: notepad.exe | Trigger: Once at $($fireTime.ToString('yyyy-MM-dd HH:mm:ss'))" INFO
        Write-Log "  Detection: Scheduled task creation with a near-future one-shot trigger. Look for EventID 4698." INFO
    } catch {
        Write-Log "T1053.005 [Time Bomb] Failed: $_" FAIL
    }
}

function Remove-TimeBomb {
    try {
        Unregister-ScheduledTask -TaskName $TIMEBOMB_TASK -Confirm:$false -ErrorAction Stop
        Write-Log "T1053.005 [Time Bomb] Task removed." CLEAN
    } catch {
        Write-Log "T1053.005 [Time Bomb] Nothing to clean." INFO
    }
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 2: PROCESS WATCH BOMB
# T1546.003
# Registers a WMI __EventFilter watching for notepad.exe creation.
# Simulates malware that activates when a target process appears.
# ─────────────────────────────────────────────────────────────
function Invoke-ProcessWatchBomb {
    Write-Log "LOGIC BOMB: Process Watch Bomb (T1546.003)" BOMB
    Write-Log "  WMI subscription fires when notepad.exe starts." INFO
    Write-Log "  Simulates process-triggered execution logic bombs." INFO

    if ($DryRun) {
        Write-Log "DRY RUN - Would create WMI __EventFilter watching for notepad.exe process creation." DRY
        return
    }
    try {
        $filterQuery = "SELECT * FROM __InstanceCreationEvent WITHIN 5 " +
                       "WHERE TargetInstance ISA 'Win32_Process' " +
                       "AND TargetInstance.Name = 'notepad.exe'"
        $filter = Set-WmiInstance -Namespace root\subscription `
            -Class __EventFilter `
            -Arguments @{
                Name           = "${SIGIL_TAG}_ProcFilter"
                EventNamespace = "root\cimv2"
                QueryLanguage  = "WQL"
                Query          = $filterQuery
            }

        # CommandLineEventConsumer writes a marker file instead of executing a payload
        $consumer = Set-WmiInstance -Namespace root\subscription `
            -Class CommandLineEventConsumer `
            -Arguments @{
                Name             = "${SIGIL_TAG}_ProcConsumer"
                CommandLineTemplate = "cmd.exe /c echo SIGIL_PWBOMB_FIRED > $TEMP_DIR\pwbomb_hit.txt"
            }

        Set-WmiInstance -Namespace root\subscription `
            -Class __FilterToConsumerBinding `
            -Arguments @{
                Filter   = $filter
                Consumer = $consumer
            } | Out-Null

        Write-Log "T1546.003 [Process Watch Bomb] Written to: root\subscription\__EventFilter -> ${SIGIL_TAG}_ProcFilter" PASS
        Write-Log "  Consumer: root\subscription\CommandLineEventConsumer -> ${SIGIL_TAG}_ProcConsumer" INFO
        Write-Log "  Hit log will write to: $TEMP_DIR\pwbomb_hit.txt -- Start notepad.exe to trigger." INFO
        Write-Log "  Detection: WMI consumer creation. Look for EventID 5857-5861 (WMI activity log)." INFO
    } catch {
        Write-Log "T1546.003 [Process Watch Bomb] Failed (requires elevation): $_" FAIL
    }
}

function Remove-ProcessWatchBomb {
    try {
        Get-WmiObject -Namespace root\subscription -Class __EventFilter |
            Where-Object Name -eq "${SIGIL_TAG}_ProcFilter" | Remove-WmiObject
        Get-WmiObject -Namespace root\subscription -Class CommandLineEventConsumer |
            Where-Object Name -eq "${SIGIL_TAG}_ProcConsumer" | Remove-WmiObject
        Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding |
            Where-Object { $_.Filter -like "*${SIGIL_TAG}*" } | Remove-WmiObject
        Write-Log "T1546.003 [Process Watch Bomb] WMI objects removed." CLEAN
    } catch {
        Write-Log "T1546.003 [Process Watch Bomb] Nothing to clean or error: $_" INFO
    }
    $hit = "$TEMP_DIR\pwbomb_hit.txt"
    if (Test-Path $hit) { Remove-Item $hit -Force; Write-Log "  Marker file removed." CLEAN }
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 3: FILE DROP BOMB
# T1105 + T1547
# A FileSystemWatcher monitors %TEMP%\SIGIL_LB\ for a sentinel file.
# When SIGIL_SENTINEL.txt is created, the "bomb activates" (logs a hit).
# Simulates staged payload waiting for a dropper to signal readiness.
# ─────────────────────────────────────────────────────────────
function Invoke-FileDropBomb {
    Write-Log "LOGIC BOMB: File Drop Bomb (T1105 + T1547)" BOMB
    Write-Log "  FileSystemWatcher waits for a sentinel file. Create it to trigger activation." INFO
    Write-Log "  Sentinel file: $FILEDROP_SENTINEL" INFO

    if ($DryRun) {
        Write-Log "DRY RUN - Would set up FileSystemWatcher on $TEMP_DIR watching for SIGIL_SENTINEL.txt" DRY
        return
    }
    Ensure-TempDir
    try {
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path   = $TEMP_DIR
        $watcher.Filter = "SIGIL_SENTINEL.txt"
        $watcher.EnableRaisingEvents = $true

        $action = {
            $ts  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $msg = "[$ts] [B] T1105/T1547 [File Drop Bomb] SENTINEL FILE DETECTED -- bomb activated!"
            Write-Host $msg -ForegroundColor Red
            Add-Content -Path "$env:TEMP\SIGIL_LB\filedrop_hit.txt" -Value $msg
        }

        Register-ObjectEvent -InputObject $watcher -EventName Created `
            -SourceIdentifier "${SIGIL_TAG}_FileWatcher" -Action $action | Out-Null

        Write-Log "T1105 [File Drop Bomb] Watcher armed on: $TEMP_DIR" PASS
        Write-Log "  Sentinel file: $FILEDROP_SENTINEL" INFO
        Write-Log "  Hit log will write to: $TEMP_DIR\filedrop_hit.txt" INFO
        Write-Log "  To trigger: New-Item '$FILEDROP_SENTINEL'" INFO
        Write-Log "  Detection: FileSystemWatcher abuse, unexpected file creation in TEMP. Monitor via Sysmon EventID 11." INFO
        Write-Log "  NOTE: Watcher lives in this PowerShell session only. It will disarm when this window closes." WARN
    } catch {
        Write-Log "T1105 [File Drop Bomb] Failed: $_" FAIL
    }
}

function Remove-FileDropBomb {
    Unregister-Event -SourceIdentifier "${SIGIL_TAG}_FileWatcher" -ErrorAction SilentlyContinue
    foreach ($f in @($FILEDROP_SENTINEL, "$TEMP_DIR\filedrop_hit.txt")) {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Log "  Removed: $f" CLEAN }
    }
    Write-Log "T1105 [File Drop Bomb] Watcher and artifacts cleaned." CLEAN
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 4: LOGIN BOMB
# T1547.001
# Writes an HKCU Run key AND a companion "detonation log" file.
# On next logon the key fires notepad.exe and the marker file
# records the trigger time -- simulating a login-triggered bomb.
# ─────────────────────────────────────────────────────────────
function Invoke-LoginBomb {
    Write-Log "LOGIC BOMB: Login Bomb (T1547.001)" BOMB
    Write-Log "  Writes a Run key + a pre-stage marker. Activates on next user logon." INFO

    if ($DryRun) {
        Write-Log "DRY RUN - Would write HKCU Run key '$LOGINBOMB_KEY' and a staging marker file." DRY
        return
    }
    Ensure-TempDir
    try {
        # Write the run key
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
            -Name $LOGINBOMB_KEY `
            -Value "C:\Windows\System32\notepad.exe" `
            -PropertyType String -Force | Out-Null

        # Write a marker file the "bomb" would reference to know it already fired
        $markerPath = Join-Path $TEMP_DIR "login_bomb_stage.txt"
        Set-Content -Path $markerPath -Value "SIGIL_LOGIN_BOMB_ARMED|$(Get-Date -Format o)"

        Write-Log "T1547.001 [Login Bomb] Written to: HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\$LOGINBOMB_KEY -> C:\Windows\System32\notepad.exe" PASS
        Write-Log "  Staging marker written to: $markerPath" INFO
        Write-Log "  Detection: HKCU Run key creation. Monitor EventID 4657 (registry object modified) or Sysmon EventID 13." INFO
    } catch {
        Write-Log "T1547.001 [Login Bomb] Failed: $_" FAIL
    }
}

function Remove-LoginBomb {
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
        -Name $LOGINBOMB_KEY -Force -ErrorAction SilentlyContinue
    $marker = Join-Path $TEMP_DIR "login_bomb_stage.txt"
    if (Test-Path $marker) { Remove-Item $marker -Force }
    Write-Log "T1547.001 [Login Bomb] Run key and marker removed." CLEAN
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 5: DNS BEACON
# T1071.004
# Makes repeated DNS lookups to a test domain at a fixed interval.
# Simulates C2 beaconing behavior for DNS telemetry detection testing.
# Replace $DNS_BEACON_DOMAIN with your own canary domain for real alerting.
# ─────────────────────────────────────────────────────────────
function Invoke-DNSBeacon {
    Write-Log "LOGIC BOMB: DNS Beacon (T1071.004)" BOMB
    Write-Log "  Simulates C2 DNS beaconing. Making $DNS_BEACON_ROUNDS queries to: $DNS_BEACON_DOMAIN" INFO
    Write-Log "  Interval: ${DNS_BEACON_INTERVAL}s. Replace `$DNS_BEACON_DOMAIN with your canary domain." WARN

    if ($DryRun) {
        Write-Log "DRY RUN - Would perform $DNS_BEACON_ROUNDS DNS lookups against $DNS_BEACON_DOMAIN at ${DNS_BEACON_INTERVAL}s intervals." DRY
        return
    }
    try {
        for ($i = 1; $i -le $DNS_BEACON_ROUNDS; $i++) {
            $subdomain = "beacon-${i}-$([System.Guid]::NewGuid().ToString('N').Substring(0,8)).$DNS_BEACON_DOMAIN"
            try {
                [System.Net.Dns]::GetHostAddresses($subdomain) | Out-Null
            } catch {
                # NXDOMAIN is expected -- the DNS query itself is the signal
            }
            Write-Log "T1071.004 [DNS Beacon] Round $i/$DNS_BEACON_ROUNDS -- queried: $subdomain (via [System.Net.Dns]::GetHostAddresses)" PASS
            if ($i -lt $DNS_BEACON_ROUNDS) { Start-Sleep -Seconds $DNS_BEACON_INTERVAL }
        }
        Write-Log "T1071.004 [DNS Beacon] Beaconing complete. Validate DNS query logs in your SIEM/firewall." PASS
        Write-Log "  Detection: Repeated unique-subdomain DNS queries at regular intervals. Look in DNS debug logs, Zeek, or EDR network telemetry." INFO
    } catch {
        Write-Log "T1071.004 [DNS Beacon] Error: $_" FAIL
    }
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 6: SHADOW COPY WIPE (SAFE -- ECHO ONLY)
# T1490
# Simulates the vssadmin and wmic commands used to delete shadow copies.
# DOES NOT actually delete any copies -- only echoes the commands and
# logs them as if a ransomware pre-encryption wiper step fired.
# ─────────────────────────────────────────────────────────────
function Invoke-ShadowCopyWipe {
    Write-Log "LOGIC BOMB: Shadow Copy Wipe Simulation (T1490)" BOMB
    Write-Log "  SAFE MODE: Commands are echoed only -- no shadow copies will be deleted." WARN

    if ($DryRun) {
        Write-Log "DRY RUN - Would echo vssadmin/wmic shadow copy deletion commands." DRY
        return
    }
    Ensure-TempDir
    $commands = @(
        'vssadmin delete shadows /all /quiet',
        'wmic shadowcopy delete',
        'bcdedit /set {default} recoveryenabled No',
        'bcdedit /set {default} bootstatuspolicy ignoreallfailures',
        'wbadmin delete catalog -quiet'
    )
    $stagingFile = Join-Path $TEMP_DIR "shadow_wipe_cmds.txt"
    $commands | Out-File -FilePath $stagingFile -Encoding UTF8

    Write-Log "T1490 [Shadow Wipe] Command staging file written to: $stagingFile" PASS
    Write-Log "  Commands staged (not executed):" INFO
    foreach ($cmd in $commands) {
        Write-Log "    >> $cmd" INFO
    }
    Write-Log "  Detection: Process creation for vssadmin/wbadmin/bcdedit with shadow-delete arguments. Sysmon EventID 1 or EDR process telemetry." INFO
}

function Remove-ShadowCopyWipe {
    $f = Join-Path $TEMP_DIR "shadow_wipe_cmds.txt"
    if (Test-Path $f) { Remove-Item $f -Force; Write-Log "T1490 [Shadow Wipe] Staging file removed." CLEAN }
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 7: CREDENTIAL HARVEST MARKER
# T1555 + T1003
# Discovers DPAPI master key paths and Chrome/Firefox credential store
# locations, writes them to a staging file. Simulates the reconnaissance
# phase of a credential harvesting logic bomb without reading any secrets.
# ─────────────────────────────────────────────────────────────
function Invoke-CredHarvest {
    Write-Log "LOGIC BOMB: Credential Harvest Marker (T1555 + T1003)" BOMB
    Write-Log "  Discovers credential store paths and stages them. No secrets are read." INFO

    if ($DryRun) {
        Write-Log "DRY RUN - Would enumerate DPAPI key paths and browser credential store locations." DRY
        return
    }
    Ensure-TempDir
    $targets = @()

    # DPAPI master key directories
    $dpapiBase = Join-Path $env:APPDATA "Microsoft\Protect"
    if (Test-Path $dpapiBase) {
        Get-ChildItem -Path $dpapiBase -Recurse -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            ForEach-Object { $targets += "DPAPI: $($_.FullName)" }
    }

    # Chrome credentials (path only -- not opened)
    $chromeDB = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Login Data"
    if (Test-Path $chromeDB) { $targets += "CHROME_CREDS: $chromeDB" }

    # Firefox profiles (path only)
    $ffBase = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles"
    if (Test-Path $ffBase) {
        Get-ChildItem -Path $ffBase -Recurse -Filter "logins.json" -ErrorAction SilentlyContinue |
            ForEach-Object { $targets += "FIREFOX_CREDS: $($_.FullName)" }
    }

    # Windows Credential Manager vault paths
    $credVault = Join-Path $env:LOCALAPPDATA "Microsoft\Credentials"
    if (Test-Path $credVault) { $targets += "CRED_VAULT: $credVault" }

    $targets | Out-File -FilePath $CRED_STAGING_FILE -Encoding UTF8
    Write-Log "T1555 [Cred Harvest] Found $($targets.Count) credential store path(s)." PASS
    Write-Log "  Staging file written to: $CRED_STAGING_FILE" INFO
    Write-Log "  Detection: File path enumeration under AppData\Roaming\Microsoft\Protect and browser profile directories. Sysmon EventID 11/23." INFO
}

function Remove-CredHarvest {
    if (Test-Path $CRED_STAGING_FILE) {
        Remove-Item $CRED_STAGING_FILE -Force
        Write-Log "T1555 [Cred Harvest] Staging file removed." CLEAN
    }
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 8: ENVIRONMENT TRIGGER (ANTI-SANDBOX CHECK)
# T1082 + T1033 + T1497
# Collects system fingerprint data: hostname, username, domain membership,
# installed AV products, and system uptime. Writes the result to a staging
# file and evaluates whether the host "looks like a sandbox."
# Simulates malware that checks its environment before detonating.
# ─────────────────────────────────────────────────────────────
function Invoke-EnvTrigger {
    Write-Log "LOGIC BOMB: Environment Trigger / Anti-Sandbox Check (T1082 + T1033 + T1497)" BOMB
    Write-Log "  Fingerprints the host to simulate sandbox evasion logic." INFO

    if ($DryRun) {
        Write-Log "DRY RUN - Would collect hostname, username, AV products, and uptime for sandbox detection." DRY
        return
    }
    Ensure-TempDir

    $hostname  = $env:COMPUTERNAME
    $username  = $env:USERNAME
    $domain    = (Get-WmiObject Win32_ComputerSystem).Domain
    $uptime    = ((Get-Date) - (gcim Win32_OperatingSystem).LastBootUpTime).TotalMinutes
    $avProducts = @()
    try {
        $avProducts = (Get-CimInstance -Namespace root\SecurityCenter2 `
            -ClassName AntiVirusProduct -ErrorAction Stop).displayName
    } catch { $avProducts = @("Unable to query SecurityCenter2") }

    # Sandbox heuristics (common VM/sandbox indicators)
    $sandboxFlags = @()
    if ($hostname -match "SANDBOX|VIRUS|MALWARE|ANALYSIS|CUCKOO|ANY\.RUN|VMWARE|VBOX|QEMU") {
        $sandboxFlags += "Suspicious hostname: $hostname"
    }
    if ($username -match "SANDBOX|ANALYST|MALWARE|ADMIN|USER1|TEST") {
        $sandboxFlags += "Suspicious username: $username"
    }
    if ($uptime -lt 5) {
        $sandboxFlags += "Very low uptime ($([int]$uptime) min) -- possible sandbox reset"
    }

    $report = @{
        Hostname     = $hostname
        Username     = $username
        Domain       = $domain
        UptimeMin    = [int]$uptime
        AVProducts   = $avProducts -join ", "
        SandboxFlags = if ($sandboxFlags) { $sandboxFlags -join "; " } else { "None detected" }
        Decision     = if ($sandboxFlags) { "ABORT (sandbox suspected)" } else { "PROCEED (target looks real)" }
    }

    $envFile = Join-Path $TEMP_DIR "env_trigger_report.txt"
    $report.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } |
        Out-File -FilePath $envFile -Encoding UTF8

    Write-Log "T1082/T1033 [Env Trigger] Host fingerprint collected." PASS
    Write-Log "  Report written to: $envFile" INFO
    Write-Log "  Sandbox decision: $($report.Decision)" $(if ($sandboxFlags) { "WARN" } else { "PASS" })
    Write-Log "  Detection: WMI SecurityCenter2 queries, Win32_ComputerSystem enumeration. Sysmon EventID 1 / WMI activity logs." INFO
}

function Remove-EnvTrigger {
    $f = Join-Path $TEMP_DIR "env_trigger_report.txt"
    if (Test-Path $f) { Remove-Item $f -Force; Write-Log "T1082 [Env Trigger] Report file removed." CLEAN }
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 9: LOLBIN EXECUTION CHAIN
# T1218 + T1059.001 + T1140
# Chains three LOLBins in sequence: certutil (decode) → rundll32 (load DLL)
# → regsvr32 (register). Each step logs a hit. Simulates staged LOLBin abuse
# for payload delivery/evasion without executing actual payloads.
# ─────────────────────────────────────────────────────────────
function Invoke-LOLBinChain {
    Write-Log "LOGIC BOMB: LOLBin Execution Chain (T1218 + T1059 + T1140)" BOMB
    Write-Log "  Chains certutil → rundll32 → regsvr32 to simulate staged LOLBin payload delivery." INFO

    if ($DryRun) {
        Write-Log "DRY RUN - Would chain: certutil decode → rundll32 empty DLL → regsvr32 empty DLL" DRY
        return
    }
    Ensure-TempDir

    # STAGE 1: certutil -decode (T1140)
    Write-Log "  Stage 1/3 - certutil decode (T1140)" INFO
    try {
        $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("SIGIL_LOLBIN_STAGE1"))
        Set-Content -Path $LOLBIN_TEMP_B64 -Value $b64 -Encoding ASCII
        & certutil -decode $LOLBIN_TEMP_B64 $LOLBIN_TEMP_DLL 2>&1 | Out-Null
        Write-Log "  [+] Stage 1 complete -- certutil.exe decoded $LOLBIN_TEMP_B64 -> $LOLBIN_TEMP_DLL" PASS
    } catch {
        Write-Log "  [X] certutil stage failed: $_" FAIL
    }

    # STAGE 2: rundll32 (T1218.011) -- calls a non-existent export to generate telemetry
    Write-Log "  Stage 2/3 - rundll32 (T1218.011)" INFO
    try {
        Start-Process -FilePath "rundll32.exe" `
            -ArgumentList "$LOLBIN_TEMP_DLL,SimulatedEntry" `
            -WindowStyle Hidden -Wait
        Write-Log "  [+] Stage 2 complete -- rundll32.exe invoked with: $LOLBIN_TEMP_DLL,SimulatedEntry" PASS
    } catch {
        Write-Log "  [X] rundll32 stage failed: $_" FAIL
    }

    # STAGE 3: regsvr32 (T1218.010) -- calls with /s /u to generate COM registration telemetry
    Write-Log "  Stage 3/3 - regsvr32 (T1218.010)" INFO
    try {
        Start-Process -FilePath "regsvr32.exe" `
            -ArgumentList "/s /u `"$LOLBIN_TEMP_DLL`"" `
            -WindowStyle Hidden -Wait
        Write-Log "  [+] Stage 3 complete -- regsvr32.exe /s /u invoked with: $LOLBIN_TEMP_DLL" PASS
    } catch {
        Write-Log "  [X] regsvr32 stage failed: $_" FAIL
    }

    Write-Log "T1218 [LOLBin Chain] All 3 stages complete. Validate EDR process creation telemetry." PASS
    Write-Log "  Detection: Sysmon EventID 1 for each LOLBin process. Parent-child chain: powershell → certutil → rundll32 → regsvr32." INFO
}

function Remove-LOLBinChain {
    foreach ($f in @($LOLBIN_TEMP_DLL, $LOLBIN_TEMP_B64)) {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Log "T1218 [LOLBin Chain] Removed: $f" CLEAN }
    }
}

# ─────────────────────────────────────────────────────────────
# LOGIC BOMB 10: WMI PERSISTENCE BOMB
# T1546.003
# Creates a full WMI event subscription triple (Filter + Consumer + Binding).
# The consumer fires notepad.exe when the machine has been running 60+ seconds.
# Includes complete WMI cleanup (all 3 objects removed).
# ─────────────────────────────────────────────────────────────
function Invoke-WMIPersistence {
    Write-Log "LOGIC BOMB: WMI Persistence Bomb (T1546.003)" BOMB
    Write-Log "  Creates WMI EventFilter + CommandLineConsumer + FilterToConsumerBinding." INFO
    Write-Log "  Consumer fires when system uptime exceeds 60 seconds." INFO

    if ($DryRun) {
        Write-Log "DRY RUN - Would create: WMI Filter '$WMI_FILTER_NAME' (uptime >60s) + Consumer '$WMI_CONSUMER_NAME' + Binding." DRY
        return
    }
    try {
        $filter = Set-WmiInstance -Namespace root\subscription `
            -Class __EventFilter `
            -Arguments @{
                Name           = $WMI_FILTER_NAME
                EventNamespace = "root\cimv2"
                QueryLanguage  = "WQL"
                Query          = "SELECT * FROM __InstanceModificationEvent WITHIN 5 " +
                                 "WHERE TargetInstance ISA 'Win32_LocalTime' " +
                                 "AND TargetInstance.Second = 0"
            }

        $consumer = Set-WmiInstance -Namespace root\subscription `
            -Class CommandLineEventConsumer `
            -Arguments @{
                Name                = $WMI_CONSUMER_NAME
                CommandLineTemplate = "cmd.exe /c echo SIGIL_WMI_FIRED=$(Get-Date -Format o) >> $TEMP_DIR\wmi_hit.txt"
            }

        Set-WmiInstance -Namespace root\subscription `
            -Class __FilterToConsumerBinding `
            -Arguments @{
                Filter   = $filter
                Consumer = $consumer
            } | Out-Null

        Write-Log "T1546.003 [WMI Persistence Bomb] Written to: root\subscription\__EventFilter -> $WMI_FILTER_NAME" PASS
        Write-Log "  Consumer written to: root\subscription\CommandLineEventConsumer -> $WMI_CONSUMER_NAME" INFO
        Write-Log "  Binding written to: root\subscription\__FilterToConsumerBinding" INFO
        Write-Log "  Hit log will write to: $TEMP_DIR\wmi_hit.txt when triggered." INFO
        Write-Log "  Detection: WMI subscription creation. EventID 5859-5861 in Microsoft-Windows-WMI-Activity/Operational log." INFO
        Write-Log "  IMPORTANT: Run cleanup when done -- WMI subscriptions survive reboots." WARN
    } catch {
        Write-Log "T1546.003 [WMI Persistence Bomb] Failed (requires elevation): $_" FAIL
    }
}

function Remove-WMIPersistence {
    try {
        # Must remove the binding first, then consumer and filter
        Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding |
            Where-Object { $_.Filter -like "*$WMI_FILTER_NAME*" } | Remove-WmiObject
        Get-WmiObject -Namespace root\subscription -Class CommandLineEventConsumer |
            Where-Object Name -eq $WMI_CONSUMER_NAME | Remove-WmiObject
        Get-WmiObject -Namespace root\subscription -Class __EventFilter |
            Where-Object Name -eq $WMI_FILTER_NAME | Remove-WmiObject
        Write-Log "T1546.003 [WMI Persistence Bomb] All 3 WMI objects removed." CLEAN
    } catch {
        Write-Log "T1546.003 [WMI Persistence Bomb] Error during cleanup: $_" FAIL
    }
    $hit = "$TEMP_DIR\wmi_hit.txt"
    if (Test-Path $hit) { Remove-Item $hit -Force; Write-Log "  Hit log removed." CLEAN }
}

# ─────────────────────────────────────────────────────────────
# FULL CLEANUP ORCHESTRATOR
# ─────────────────────────────────────────────────────────────
function Invoke-FullCleanup {
    Write-Log "===== SIGIL LOGIC BOMBS - FULL CLEANUP =====" INFO
    Remove-TimeBomb
    Remove-ProcessWatchBomb
    Remove-FileDropBomb
    Remove-LoginBomb
    Remove-ShadowCopyWipe
    Remove-CredHarvest
    Remove-EnvTrigger
    Remove-LOLBinChain
    Remove-WMIPersistence

    if (Test-Path $TEMP_DIR) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force
        Write-Log "Working directory removed: $TEMP_DIR" CLEAN
    }
    Write-Log "===== CLEANUP COMPLETE =====" INFO
}

# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────
Write-Log "======================================================" INFO
Write-Log "  SIGIL Logic Bombs Module" INFO
Write-Log "  Trigger-Based Adversary Simulation" INFO
Write-Log "  !! FOR ISOLATED LAB USE ONLY !!" WARN
Write-Log "======================================================" INFO

if ($DryRun) {
    Write-Log "DRY RUN MODE - No changes will be made to this system." DRY
}

# Bare -Cleanup runs everything
if ($Cleanup -and -not $All -and -not $TimeBomb -and -not $ProcessWatchBomb `
    -and -not $FileDropBomb -and -not $LoginBomb -and -not $DNSBeacon `
    -and -not $ShadowCopyWipe -and -not $CredHarvest -and -not $EnvTrigger `
    -and -not $LOLBinChain -and -not $WMIPersistence) {
    Invoke-FullCleanup
    exit 0
}

Ensure-TempDir

# ── SIMULATE ─────────────────────────────────────────────────
if ($All -or $TimeBomb)         { Invoke-TimeBomb         }
if ($All -or $ProcessWatchBomb) { Invoke-ProcessWatchBomb }
if ($All -or $FileDropBomb)     { Invoke-FileDropBomb     }
if ($All -or $LoginBomb)        { Invoke-LoginBomb        }
if ($All -or $DNSBeacon)        { Invoke-DNSBeacon        }
if ($All -or $ShadowCopyWipe)   { Invoke-ShadowCopyWipe   }
if ($All -or $CredHarvest)      { Invoke-CredHarvest      }
if ($All -or $EnvTrigger)       { Invoke-EnvTrigger       }
if ($All -or $LOLBinChain)      { Invoke-LOLBinChain      }
if ($All -or $WMIPersistence)   { Invoke-WMIPersistence   }

# ── SELECTIVE CLEANUP ────────────────────────────────────────
if ($Cleanup) {
    Write-Log "===== SELECTIVE CLEANUP =====" INFO
    if ($All -or $TimeBomb)         { Remove-TimeBomb         }
    if ($All -or $ProcessWatchBomb) { Remove-ProcessWatchBomb }
    if ($All -or $FileDropBomb)     { Remove-FileDropBomb     }
    if ($All -or $LoginBomb)        { Remove-LoginBomb        }
    if ($All -or $ShadowCopyWipe)   { Remove-ShadowCopyWipe   }
    if ($All -or $CredHarvest)      { Remove-CredHarvest      }
    if ($All -or $EnvTrigger)       { Remove-EnvTrigger       }
    if ($All -or $LOLBinChain)      { Remove-LOLBinChain      }
    if ($All -or $WMIPersistence)   { Remove-WMIPersistence   }
    Write-Log "===== SELECTIVE CLEANUP COMPLETE =====" INFO
}

Write-Log "===== LOGIC BOMB SIMULATION COMPLETE =====" INFO
Write-Log "Validate EDR alerts, WMI logs, DNS telemetry, and Sysmon events now." INFO
if (-not $Cleanup -and -not $DryRun) {
    Write-Log "Reminder: Run with -Cleanup to disarm all active logic bombs when done." WARN
    Write-Log "WMI subscriptions and scheduled tasks WILL persist across reboots until cleaned." WARN
}
