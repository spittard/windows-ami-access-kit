$logPath = "C:\PostLaunch\AccessCheck.log"
New-Item -ItemType Directory -Path (Split-Path $logPath) -Force | Out-Null
Start-Transcript -Path $logPath -Append

Write-Host "`n--- EC2 Metadata Check ---"
try {
    $instanceId = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id
    Write-Host "Instance ID: $instanceId"
} catch {
    Write-Host "Metadata access failed: $($_.Exception.Message)"
}

Write-Host "`n--- EC2Launch Log Tail ---"
$launchLog = "C:\ProgramData\Amazon\EC2Launch\log\launch.log"
if (Test-Path $launchLog) {
    Get-Content $launchLog -Tail 20
} else {
    Write-Host "EC2Launch log not found."
}

Write-Host "`n--- SSM Agent Status ---"
Get-Service AmazonSSMAgent | Select Status, StartType

Write-Host "`n--- RDP Port Check ---"
Test-NetConnection -Port 3389

Stop-Transcript