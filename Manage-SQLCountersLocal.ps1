<#
.SYNOPSIS
    Manage SQL Server performance counter data collector sets with optional timed runs.
    
.DESCRIPTION
    This script creates, starts, and stops performance counter data collector sets for SQL Server instances.
    It discovers instances by enumerating services whose Name starts with "MSSQL" AND DisplayName starts with "SQL Server",
    ensuring only actual SQL Server Database Engine instances are processed (excluding FD Launcher, etc.).

    For the default instance: MSSQLSERVER (Counters remain \SQLServer:...)
    For named instances: MSSQL$InstanceName (Counters will replace SQLServer with MSSQL$InstanceName)

    If you specify -DurationMinutes when using -Action Start, the script will:
    - Start the collectors
    - Wait for the specified duration
    - Then stop the collectors automatically

.PARAMETER Action
    "Create", "Start", or "Stop"
    
.PARAMETER InstanceName
    Specify a single instance ("MSSQLSERVER" for default or "MSSQL$InstanceName" for named), or omit to apply to all discovered instances.
    
.PARAMETER CounterListFile
    Provide a custom file with counters (one per line) if desired. If not provided, a default comprehensive set is used.

.PARAMETER DurationMinutes
    (Optional) If used with -Action Start, specifies how many minutes to run before automatically stopping.

.EXAMPLE
    # Create data collector sets for all SQL Server instances
    .\Manage-SQLCounterslocal.ps1 -Action Create

.EXAMPLE
    # Start data collector sets for a named instance for 30 minutes
    .\Manage-SQLCounterslocal.ps1 -Action Start -InstanceName "MSSQL$SQLXXX1" -DurationMinutes 30

.EXAMPLE
    # Stop data collector sets for the default instance
    .\Manage-SQLCounterslocal.ps1 -Action Stop -InstanceName "MSSQLSERVER"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Create","Start","Stop")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$InstanceName,

    [Parameter(Mandatory=$false)]
    [string]$CounterListFile,

    [Parameter(Mandatory=$false)]
    [int]$DurationMinutes
)

function Get-SqlInstances {
    # Only actual SQL Server database engine services (not FDLauncher, etc.)
    $services = Get-Service | Where-Object {
        $_.Name -like "MSSQL*" -and $_.DisplayName -like "SQL Server*"
    }

    return $services.Name
}

function Get-DefaultCounters {
    @(
        # Processor
        "\Processor(_Total)\% Processor Time",
        "\Processor(_Total)\% Privileged Time",
        "\Processor(_Total)\% User Time",
        "\Processor(_Total)\% Interrupt Time",
        "\System\Processor Queue Length",

        # Memory
        "\Memory\Available MBytes",
        "\Memory\Pages/sec",
        "\Memory\Page Faults/sec",
        "\Memory\Cache Faults/sec",
        "\Memory\Committed Bytes",
        "\Memory\Pool Paged Bytes",
        "\Memory\Pool Nonpaged Bytes",

        # Disk and I/O
        "\PhysicalDisk(_Total)\Disk Reads/sec",
        "\PhysicalDisk(_Total)\Disk Writes/sec",
        "\PhysicalDisk(_Total)\Avg. Disk sec/Read",
        "\PhysicalDisk(_Total)\Avg. Disk sec/Write",
        "\PhysicalDisk(_Total)\Avg. Disk Queue Length",
        "\PhysicalDisk(_Total)\% Disk Time",
        "\PhysicalDisk(_Total)\% Idle Time",
        "\LogicalDisk(_Total)\% Free Space",
        "\LogicalDisk(_Total)\Free Megabytes",

        # Network
        "\Network Interface(*)\Bytes Total/sec",
        "\Network Interface(*)\Packets Outbound Errors",
        "\Network Interface(*)\Packets Received Errors",

        # System
        "\System\Context Switches/sec",
        "\System\System Calls/sec",

        # SQL Server General
        "\SQLServer:General Statistics\User Connections",
        "\SQLServer:General Statistics\Processes blocked",
        "\SQLServer:SQL Statistics\Batch Requests/sec",
        "\SQLServer:SQL Statistics\SQL Compilations/sec",
        "\SQLServer:SQL Statistics\SQL Re-Compilations/sec",
        "\SQLServer:Locks(_Total)\Number of Deadlocks/sec",
        "\SQLServer:Locks(_Total)\Lock Waits/sec",
        "\SQLServer:Databases(_Total)\Transactions/sec",
        "\SQLServer:Databases(_Total)\Log Flushes/sec",
        "\SQLServer:Databases(_Total)\Active Transactions",

        # SQL Server Buffer Management
        "\SQLServer:Buffer Manager\Buffer cache hit ratio",
        "\SQLServer:Buffer Manager\Page life expectancy",
        "\SQLServer:Buffer Manager\Checkpoint pages/sec",
        "\SQLServer:Buffer Node(_Total)\Database pages",
        "\SQLServer:Buffer Node(_Total)\Free pages",

        # SQL Server Access Methods
        "\SQLServer:Access Methods\Full Scans/sec",
        "\SQLServer:Access Methods\Page Splits/sec",
        "\SQLServer:Access Methods\Index Searches/sec",

        # SQL Server Memory
        "\SQLServer:Memory Manager\Total Server Memory (KB)",
        "\SQLServer:Memory Manager\Target Server Memory (KB)",
        "\SQLServer:Memory Manager\Memory Grants Pending",

        # SQL Server Plan Cache
        "\SQLServer:Plan Cache(_Total)\Cache Hit Ratio",
        "\SQLServer:Plan Cache(_Total)\Cache Pages",

        # SQL Server CLR
        "\SQLServer:CLR\CLR Execution",
        "\SQLServer:CLR\CLR Memory (KB)",

        # Always On AG
        "\SQLServer:Database Replica(*)\Transaction Delay",
        "\SQLServer:Database Replica(*)\File Bytes Sent/sec",
        "\SQLServer:Database Replica(*)\Log Send Queue",
        "\SQLServer:Availability Replica(*)\Bytes Sent to Replica/sec",
        "\SQLServer:Availability Replica(*)\Bytes Received from Replica/sec",
        "\SQLServer:Availability Replica(*)\Flow Control Time (ms/sec)",

        # SQL Server Broker
        "\SQLServer:Broker Statistics\SQL Service Broker Transmissions/sec",
        "\SQLServer:Broker Statistics\Task Limit Reached/sec",

        # SQL Server Latches
        "\SQLServer:Latches\Average Latch Wait Time (ms)",
        "\SQLServer:Latches\Latch Waits/sec",

        # SQL Server Transactions
        "\SQLServer:Transactions\Active Transactions",
        "\SQLServer:Transactions\Transactions",

        # Windows Clustering
        "\Cluster Node\Cluster Network Interface Failures",
        "\Cluster Node\Cluster Service Uptime",
        "\Cluster Network\Network Failures"
    )
}

function Create-DataCollectorSet($instance, $counters) {
    $shortInstanceName = $instance
    if ($instance -match "MSSQL\$.+") {
        $shortInstanceName = $instance -replace "^MSSQL\$",""
    }

    $dcsName = "SQLPerfCounters_$shortInstanceName"
    & logman delete $dcsName 2>$null | Out-Null

    $outPath = "C:\PerfLogs\SQLPerfCounters_$shortInstanceName"
    if (!(Test-Path $outPath)) { New-Item -ItemType Directory -Path $outPath | Out-Null }

    $counterFile = Join-Path $env:TEMP "Counters_$shortInstanceName.txt"
    $counters | Out-File -FilePath $counterFile -Encoding ASCII

    & logman create counter $dcsName `
        -f bin `
        -o "$outPath\$dcsName" `
        -cf "$counterFile" `
        -si 15 `
        -max 50 `
        -y | Out-Null
}

function Start-DataCollectorSet($instance) {
    $shortInstanceName = $instance
    if ($instance -match "MSSQL\$.+") {
        $shortInstanceName = $instance -replace "^MSSQL\$",""
    }
    $dcsName = "SQLPerfCounters_$shortInstanceName"
    & logman start $dcsName | Out-Null
}

function Stop-DataCollectorSet($instance) {
    $shortInstanceName = $instance
    if ($instance -match "MSSQL\$.+") {
        $shortInstanceName = $instance -replace "^MSSQL\$",""
    }
    $dcsName = "SQLPerfCounters_$shortInstanceName"
    & logman stop $dcsName | Out-Null
}

# MAIN LOGIC
if ([string]::IsNullOrEmpty($InstanceName)) {
    $instancesToProcess = Get-SqlInstances
} else {
    $instancesToProcess = @($InstanceName)
}

if ($CounterListFile -and (Test-Path $CounterListFile)) {
    $counters = Get-Content $CounterListFile
} else {
    $counters = Get-DefaultCounters
}

switch ($Action) {
    "Create" {
        foreach ($inst in $instancesToProcess) {
            Write-Host "Creating data collector set for instance: $inst"
            # For default instance, leave "SQLServer" in the counters
            if ($inst -eq "MSSQLSERVER") {
                $instanceCounters = $counters
            } else {
                $instanceCounters = $counters | ForEach-Object { $_ -replace "SQLServer", $inst }
            }
            Create-DataCollectorSet -instance $inst -counters $instanceCounters
        }
    }
    "Start" {
        foreach ($inst in $instancesToProcess) {
            Write-Host "Starting data collector set for instance: $inst"
            Start-DataCollectorSet -instance $inst
        }

        if ($DurationMinutes -and $DurationMinutes -gt 0) {
            Write-Host "Running for $DurationMinutes minute(s) before stopping..."
            Start-Sleep -Seconds ($DurationMinutes * 60)
            foreach ($inst in $instancesToProcess) {
                Write-Host "Stopping data collector set for instance: $inst after $DurationMinutes minute(s)"
                Stop-DataCollectorSet -instance $inst
            }
        }
    }
    "Stop" {
        foreach ($inst in $instancesToProcess) {
            Write-Host "Stopping data collector set for instance: $inst"
            Stop-DataCollectorSet -instance $inst
        }
    }
}
