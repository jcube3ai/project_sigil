# APT28 SIM: Simulation Test Runner Using Background Jobs

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'APT28 SIM Test Runner'
$form.Size = New-Object System.Drawing.Size(600,500)
$form.StartPosition = 'CenterScreen'

# Log TextBox
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$txtLog.Location = [System.Drawing.Point]::new(20,350)
$txtLog.Size = New-Object System.Drawing.Size(550,120)
$form.Controls.Add($txtLog)

function Log-Message {
    param([string]$msg)
    $ts = Get-Date -Format 'HH:mm:ss'
    $txtLog.AppendText("[$ts] $msg`r`n")
    $txtLog.ScrollToCaret()
}

# Ensure temp directory
$TempRoot = Join-Path $env:TEMP 'APT28_SIM'
if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force }
New-Item -Path $TempRoot -ItemType Directory | Out-Null

# Define simulation scriptblocks
$simulations = @{
    'Scheduled-Task Dropper' = {
        $action = New-ScheduledTaskAction -Execute 'notepad.exe'
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(30)
        Register-ScheduledTask -TaskName 'APT28Test' -Action $action -Trigger $trigger -Force
        Start-ScheduledTask -TaskName 'APT28Test'
        "Sleep 35;" | Out-Host # placeholder sleep within job
    }
    'Macro Dropper' = {
        $dir = Join-Path $TempRoot 'Macro'; New-Item $dir -ItemType Directory -Force | Out-Null
        $exe = Join-Path $dir 'payload.exe'; $bat = $exe -Replace '\.exe$','.bat'
        "@echo off`necho Payload>nul" | Out-File -FilePath $bat -Encoding ASCII
        Rename-Item -Path $bat -NewName (Split-Path $exe -Leaf) -Force
        Start-Process -FilePath $exe -WindowStyle Hidden
    }
    'WMI Repository Dropper' = {
        $dir = Join-Path $TempRoot 'WMI'; New-Item $dir -ItemType Directory -Force | Out-Null
        $dll = Join-Path $dir 'inject.dll'; "" | Out-File -FilePath $dll -Encoding ASCII
        $target = Join-Path $env:windir 'System32\wbem\repository\inject.dll'
        Copy-Item -Path $dll -Destination $target -Force
        Start-Process -FilePath 'rundll32.exe' -ArgumentList "$target,EntryPoint" -WindowStyle Hidden
    }
    'Service-Account Dropper' = {
        $dir = Join-Path $TempRoot 'Service'; New-Item $dir -ItemType Directory -Force | Out-Null
        $exe = Join-Path $dir 'svc.exe'; $bat = $exe -Replace '\.exe$','.bat'
        "@echo off`necho Service>nul" | Out-File -FilePath $bat -Encoding ASCII
        Rename-Item -Path $bat -NewName (Split-Path $exe -Leaf) -Force
        Start-Process -FilePath $exe -WindowStyle Hidden
    }
    'Process Hollowing' = { Start-Process -FilePath notepad.exe -PassThru | Out-Null }
    'DLL Proxy Execution' = {
        $dir = Join-Path $TempRoot 'Proxy'; New-Item $dir -ItemType Directory -Force | Out-Null
        $dll = Join-Path $dir 'proxy.dll'; "" | Out-File -FilePath $dll -Encoding ASCII
        Start-Process -FilePath 'rundll32.exe' -ArgumentList "$dll,EntryPoint" -WindowStyle Hidden
    }
    'Remote Thread Injection' = { Start-Process -FilePath notepad.exe -PassThru | Out-Null }
    'Reflective Code Loading' = {
        $dir = Join-Path $TempRoot 'Reflect'; New-Item $dir -ItemType Directory -Force | Out-Null
        $dll = Join-Path $dir 'reflective.dll'; "" | Out-File -FilePath $dll -Encoding ASCII
    }
}

# Create checkboxes dynamically
$y=20
$checkboxes = @{}
foreach ($key in $simulations.Keys) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $key; $cb.AutoSize = $true
    $cb.Location = [System.Drawing.Point]::new(20,$y)
    $form.Controls.Add($cb)
    $checkboxes[$key] = $cb
    $y += 30
}

# Run Selected button
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text='Run Selected'; $btnRun.Size=[Drawing.Size]::new(120,30)
$btnRun.Location=[Drawing.Point]::new(20,$y+10)
$btnRun.Add_Click({
    foreach ($key in $checkboxes.Keys) {
        if ($checkboxes[$key].Checked) {
            Log-Message "Starting $key job"
            Start-Job -Name $key -ScriptBlock $simulations[$key] | Out-Null
        }
    }
})
$form.Controls.Add($btnRun)

# Cleanup button
$btnClean = New-Object System.Windows.Forms.Button
$btnClean.Text='Cleanup'; $btnClean.Size=[Drawing.Size]::new(120,30)
$btnClean.Location=[Drawing.Point]::new(160,$y+10)
$btnClean.Add_Click({
    Log-Message 'Cleaning up'
    Unregister-ScheduledTask -TaskName 'APT28Test' -Confirm:$false -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -Force
    if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force }
    Log-Message 'Cleanup done'
})
$form.Controls.Add($btnClean)

# Initial log
Log-Message 'APT28 SIM Ready'
# Show UI
[void]$form.ShowDialog()