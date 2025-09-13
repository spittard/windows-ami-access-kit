# Create log directory and start transcript
$logPath = "C:\PostLaunch\Recovery.log"
New-Item -ItemType Directory -Path (Split-Path $logPath) -Force | Out-Null
Start-Transcript -Path $logPath -Append

# Function: Check EC2 metadata access
function Test-MetadataReachability {
    Write-Host "`n--- EC2 Metadata Check ---"
    try {
        $instanceId = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id
        Write-Host "Instance ID: $instanceId"
        return $true
    } catch {
        Write-Host "Metadata access failed: $($_.Exception.Message)"
        return $false
    }
}

# Function: Check EC2Launch log for task success
function Test-EC2LaunchStatus {
    Write-Host "`n--- EC2Launch Log Check ---"
    $launchLog = "C:\ProgramData\Amazon\EC2Launch\log\launch.log"
    if (Test-Path $launchLog) {
        Get-Content $launchLog -Tail 50
    } else {
        Write-Host "EC2Launch log not found."
    }
}

# Function: Check SSM agent status
function Test-SSMStatus {
    Write-Host "`n--- SSM Agent Status ---"
    $ssm = Get-Service AmazonSSMAgent -ErrorAction SilentlyContinue
    if ($ssm -and $ssm.Status -eq 'Running') {
        Write-Host "SSM Agent is running."
        return $true
    } else {
        Write-Host "SSM Agent is not running."
        return $false
    }
}

# Function: Attempt to restart SSM agent
function Recover-SSM {
    Write-Host "`n--- Attempting SSM Recovery ---"
    try {
        Start-Service AmazonSSMAgent
        Write-Host "SSM Agent started successfully."
    } catch {
        Write-Host "Failed to start SSM Agent: $($_.Exception.Message)"
    }
}

# Function: Check RDP port availability
function Test-RDPAccess {
    Write-Host "`n--- RDP Port Check ---"
    $rdpTest = Test-NetConnection -Port 3389
    if ($rdpTest.TcpTestSucceeded) {
        Write-Host "RDP port is open."
        return $true
    } else {
        Write-Host "RDP port is closed."
        return $false
    }
}

# Function: Add firewall rule for RDP if missing
function Recover-RDP {
    Write-Host "`n--- Attempting RDP Firewall Recovery ---"
    try {
        New-NetFirewallRule -DisplayName "Allow RDP Inbound" `
            -Direction Inbound -Protocol TCP -LocalPort 3389 `
            -Action Allow -Profile Any -Enabled True
        Write-Host "RDP firewall rule added."
    } catch {
        Write-Host "Failed to add RDP firewall rule: $($_.Exception.Message)"
    }
}

# Function: Check IIS bindings and listener state
function Test-IISAccess {
    Write-Host "`n--- IIS Binding and Listener Check ---"
    Import-Module WebAdministration
    $site = Get-WebSite -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($site -and $site.State -eq "Started") {
        Write-Host "Default Web Site is running."
        $bindings = Get-WebBinding | Select bindingInformation
        Write-Host "Bindings:"
        $bindings | ForEach-Object { Write-Host $_.bindingInformation }
        $netstat = netstat -an | findstr ":80"
        Write-Host "Port 80 listeners:"
        $netstat
    } else {
        Write-Host "Default Web Site is not running or not found."
    }
}

# Function: Add loopback firewall rule for IIS self-access
function Recover-IISLoopback {
    Write-Host "`n--- Adding Loopback Firewall Rule for IIS ---"
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.InterfaceAlias -like "Ethernet*" -and $_.IPAddress -notlike "169.*" }).IPAddress
    if ($localIP) {
        try {
            New-NetFirewallRule -DisplayName "Allow Loopback to Self on Port 80" `
                -Direction Outbound -Protocol TCP -LocalPort 80 `
                -RemoteAddress $localIP -Action Allow -Profile Any
            Write-Host "Loopback rule added for IP $localIP."
        } catch {
            Write-Host "Failed to add loopback rule: $($_.Exception.Message)"
        }
    } else {
        Write-Host "Could not determine local IP."
    }
}

# Run all checks and remediations
$metadataOK = Test-MetadataReachability
Test-EC2LaunchStatus
$ssmOK = Test-SSMStatus
if (-not $ssmOK) { Recover-SSM }

$rdpOK = Test-RDPAccess
if (-not $rdpOK) { Recover-RDP }

Test-IISAccess
Recover-IISLoopback

Stop-Transcript