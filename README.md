# sql-perfmon-automation
This PowerShell script automates the creation, starting, stopping, and optional timed execution of performance counter data collector sets for SQL Server instances running on a Windows server.

SQL Server Performance Counter Collection Script
Overview
This PowerShell script automates the creation, starting, stopping, and optional timed execution of performance counter data collector sets for SQL Server instances running on a Windows server. By enumerating SQL Server services, the script identifies which instances are present and then collects a comprehensive set of Windows, SQL Server, and Always On counters.
Key features:
•	Discovers SQL Server instances by filtering services (default and named).
•	Uses logman to create and manage data collector sets.
•	Allows default or custom counters.
•	Handles default (MSSQLSERVER) and named (MSSQL$InstanceName) SQL instances.
•	Optionally runs data collection for a specified duration and automatically stops afterward.
•	Filters out non-database engine services like FD Launchers.
Requirements
•	Operating System: Windows Server (e.g., Windows Server 2019, 2022).
•	Permissions: Requires administrative privileges to create/manage data collector sets and access SQL counters.
•	PowerShell: Script uses standard PowerShell cmdlets; no additional modules required.
•	SQL Server: Tested with SQL Server database engine services. Script logic expects standard naming conventions:
o	Default instance: MSSQLSERVER
o	Named instances: MSSQL$InstanceName
How the Script Works
1.	Instance Discovery:
o	Uses Get-Service to find services with:
	Name starting with MSSQL
	DisplayName starting with SQL Server
o	This ensures that only SQL Server database engine instances are detected, excluding services like the Full-Text Daemon Launcher.
2.	Counter Configuration:
o	By default, the script collects a wide range of counters related to CPU, memory, disk I/O, network, system, and SQL Server components (including Buffer Manager, SQL Statistics, Databases, Plan Cache, Availability Groups, etc.).
o	Default counters are defined in the Get-DefaultCounters function.
o	A -CounterListFile parameter allows specifying a custom set of counters.
3.	Instance-Specific Counter Paths:
o	For the default instance (MSSQLSERVER), SQL Server counters are typically prefixed with \SQLServer:.
o	For named instances (MSSQL$InstanceName), counters are prefixed with \MSSQL$InstanceName:.
o	The script conditionally replaces SQLServer with the instance name for named instances, ensuring that the counters align with the instance’s actual performance objects.
4.	Creating Data Collector Sets:
o	The Create-DataCollectorSet function uses logman to create a new data collector set in binary format (.blg files).
o	The collector set is named SQLPerfCounters_<InstanceName> or SQLPerfCounters_<ShortenedName> for named instances.
o	Data is stored under C:\PerfLogs\SQLPerfCounters_<InstanceName> by default, and a temporary counters file is generated in %TEMP%.
5.	Starting and Stopping Collection:
o	The Start action runs logman start to begin collecting data into .blg files.
o	The Stop action runs logman stop to halt data collection.
6.	Timing Functionality (DurationMinutes):
o	If -DurationMinutes is specified with -Action Start, the script:
	Starts the collector sets.
	Pauses (sleeps) for the specified number of minutes.
	Automatically stops the collector sets after that time.
7.	Integration with Scheduling Tools:
o	The script can be integrated into third-party schedulers or Windows Task Scheduler by calling powershell.exe -File <scriptpath> with appropriate parameters and actions.
Parameters
•	-Action (String, Mandatory):
Specifies the desired action: Create, Start, or Stop.
•	-InstanceName (String, Optional):
Targets a specific instance. If omitted, the script enumerates all discovered SQL Server instances.
o	Default instance: MSSQLSERVER
o	Named instance: MSSQL$InstanceName
•	-CounterListFile (String, Optional):
Path to a custom text file containing counters (one per line). If not provided, a default comprehensive set of counters is used.
•	-DurationMinutes (Int, Optional):
When used with -Action Start, specifies how long (in minutes) to run before automatically stopping. If not provided, the collector runs indefinitely until manually stopped.
Example Usages
1.	Create collectors for all instances:
powershell
Copy code
powershell.exe -File "C:\Scripts\Manage-SQLCounterslocal.ps1" -Action Create
2.	Start collectors for the default instance indefinitely:
powershell
Copy code
powershell.exe -File "C:\Scripts\Manage-SQLCounterslocal.ps1" -Action Start -InstanceName "MSSQLSERVER"
Manually stop later:
powershell
Copy code
powershell.exe -File "C:\Scripts\Manage-SQLCounterslocal.ps1" -Action Stop -InstanceName "MSSQLSERVER"
3.	Start collectors for a named instance and stop after 30 minutes:
powershell
Copy code
powershell.exe -File "C:\Scripts\Manage-SQLCounterslocal.ps1" -Action Start -InstanceName "MSSQL$SQLXXX1" -DurationMinutes 30
The script will start collection, wait 30 minutes, then automatically stop.
4.	Use a custom counter list:
powershell
Copy code
powershell.exe -File "C:\Scripts\Manage-SQLCounterslocal.ps1" -Action Create -CounterListFile "C:\Counters\CustomCounters.txt"
Logging and Validation
•	After creation, you can verify that the data collector sets were created by running:
powershell
Copy code
logman query
•	Running:
powershell
Copy code
logman query SQLPerfCounters_<InstanceName>
Provides details about the collector set.
•	Check the output directory C:\PerfLogs\SQLPerfCounters_<InstanceName> for the .blg files.
•	You can open the .blg files in Performance Monitor to review the collected data:
o	Launch perfmon.exe
o	Go to File > Open
o	Select the .blg file
o	View and analyze the captured performance metrics.
Error Handling & Troubleshooting
•	Execution Policy: If you encounter an execution policy error, set a less restrictive execution policy temporarily:
powershell
Copy code
Set-ExecutionPolicy RemoteSigned -Scope Process
•	Permissions: Ensure you run PowerShell as Administrator to allow logman operations.
•	Counter Availability: If certain counters do not appear in collected data, verify that those counters exist on the system by opening Performance Monitor and checking their availability.
•	Instance Discovery: If no instances are found, ensure your SQL Server services follow the expected naming conventions and that the DisplayName starts with "SQL Server".

