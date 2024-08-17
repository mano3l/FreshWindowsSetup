#Requires -RunAsAdministrator

# Displays a confirmation screen for script execution
function Show-MWarning {
    Write-Host "WARNING: This script will alter system settings and registry." -ForegroundColor Yellow
    Write-Host "It is recommended to create a system restore point before proceeding." -ForegroundColor Yellow

    $confirmation = Read-Host "Do you want to continue? (Y/N)"

    if (-not($confirmation -eq 'Y' -or $confirmation -eq 'y')) {
        exit
    }
}

# Create a custom powershell profile
function New-MCustomProfile {
    $ProfilePath = ".\PowerShell\Microsoft.PowerShell_profile.ps1"
    $Destination = "$env:HOMEPATH\Documents\PowerShell"

    if (-not(Test-Path $Destination)) {
        Write-Progress -Activity "Creating Powershell Profile" -Status "Creating directories..." -PercentComplete 0
        try {
            mkdir $Destination | Out-Null
        }
        catch {
            Write-Error "Failed to create profile folder: $_"
            return
        }
    }
    
    Write-Progress -Activity "Creating Powershell Profile" -Status "Creating profile..." -PercentComplete 100
    try {
        Copy-Item -Path $ProfilePath -Destination $Destination
    }
    catch {
        Write-Error "Error copying powershell profile: $_"
    }
}

# Disable hibernate and consequently fast startup so tasks triggered at startup can be executed correctly
function Disable-MFastStartup {
    powercfg -h off
}

# Register a task (SyncClock) on root folder to run "W32tm /resync" on startup
function Set-MSynchronizeTimeTrigger {
    # Set SynchronizeTime task to be executed at startup
    try {
        Write-Progress -Activity "Creating SyncClock Task" -Status "Creating trigger..." -PercentComplete 0
        $TaskValues = @{
            TaskPath = "\Microsoft\Windows\Time Synchronization\"
            TaskName = "SynchronizeTime"
            Trigger  = New-ScheduledTaskTrigger -AtStartup
        }

        Write-Progress -Activity "Creating SyncClock Task" -Status "Modifying (SynchronizeTime) task..." -PercentComplete 17
        Set-ScheduledTask @TaskValues | Out-Null
    }
    catch {
        Write-Error "Failed to modify (SynchronizeTime) scheduled task: $_"
    }

    # Set W32Time service to be initialized automatically and start it
    try {
        Write-Progress -Activity "Creating SyncClock Task" -Status "Setting W32Time startup type to automatic..." -PercentComplete 34
        Set-Service -Name "W32Time" -StartupType Automatic
        Write-Progress -Activity "Creating SyncClock Task" -Status "Starting W32Time service..." -PercentComplete 51
        Start-Service -Name "W32Time"
    }
    catch {
        Write-Error "Failed to start windows time service: $_"
    }

    # Check if the task already exists
    if (Get-ScheduledTask -TaskName "SyncClock" -ErrorAction SilentlyContinue) {
        Write-Host "Failed to register SyncClock task" -ForegroundColor Yellow
        Write-Host "There is already a task named SyncClock in your system." -ForegroundColor Yellow

        $confirmation = Read-Host "Do you want to replace it? (Y/N)"

        if (-not($confirmation -eq 'Y' -or $confirmation -eq 'y')) {
            return
        }
        Write-Progress -Activity "Creating SyncClock Task" -Status "Unregistering task..." -PercentComplete 68
        Unregister-ScheduledTask -TaskName "SyncClock"
    }

    # Create a new task to synchronize the clock on every startup
    Write-Progress -Activity "Creating SyncClock Task" -Status "Creating the task..." -PercentComplete 85
    $TaskDetails = @{
        TaskName = "SyncClock"
        Trigger  = New-ScheduledTaskTrigger -AtLogOn
        User     = $env:USERNAME
        Action   = New-ScheduledTaskAction -Execute "W32tm" -Argument "/resync"
        RunLevel = "Highest"
        Settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -Compatibility Win8
    }

    #Register SyncClock Task
    try {
        Write-Progress -Activity "Creating SyncClock Task" -Status "Registering task..." -PercentComplete 100
        Register-ScheduledTask @TaskDetails | Out-Null
    }
    catch {
        Write-Error "Failed to register SyncClock task: $_"
    }
}

# Disables the Windows Search indexer
function Disable-MWSearchIndexer {
    try {
        Write-Progress -Activity "Disabling Window Search Indexer" -Status "Setting WSearch startup type to disabled..." -PercentComplete 0
        Set-Service -Name "WSearch" -StartupType Disabled
        Write-Progress -Activity "Disabling Window Search Indexer" -Status "Stopping WSearch service..." -PercentComplete 100
        Stop-Service -Name "WSearch"
    }
    catch {
        Write-Error "Failed to disable windows search indexer: $_"
    }
}

# Disables Bing search in the start menu
function Disable-MBingSearch {
    $EntryValues = @{
        Name         = "DisableSearchBoxSuggestions"
        PropertyType = "DWord"
        Value        = 1
        Path         = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    }

    if (!(Test-Path $EntryValues.Path)) {
        Write-Progress -Activity "Disabling Bing Search" -Status "Creating key..." -PercentComplete 0
        try {
            New-Item -Path $EntryValues.Path -Force | Out-Null
        }
        catch {
            Write-Error "Failed to create the registry key: $_"
            return
        }
    }

    Write-Progress -Activity "Disabling Bing Search" -Status "Adding entry..." -PercentComplete 100
    try {
        New-ItemProperty @EntryValues -Force | Out-Null
    }
    catch {
        Write-Error "Failed to create entry: $_"
    }
}

# Disables delivery optimization
function Disable-MDeliveryOptimization {
    try {
        Write-Progress -Activity "Disabling Delivery Optimization" -Status "Creating key..." -PercentComplete 0
        Set-Service -Name "DoSvc" -StartupType Manual
        Write-Progress -Activity "Disabling Delivery Optimization" -Status "Adding entry..." -PercentComplete 50
        Stop-Service -Name "DoSvc"
        Write-Progress -Activity "Disabling Delivery Optimization" -Status "Deleting cache..." -PercentComplete 100
        Delete-DeliveryOptimizationCache
    }
    catch {
        Write-Error "Failed to disable delivery optmization service: $_"
    }
}

# Disables Green Ethernet and EEE from the Ethernet adapter as way to prevent connection performance issues
function Disable-MGreenEthernetAndEEE {
    try {
        $adapterProperties = Get-NetAdapterAdvancedProperty -Name "Ethernet"

        if ($adapterProperties | Where-Object { $_.RegistryKeyword -eq "EnableGreenEthernet" }) {
            Write-Progress -Activity "Disabling Green Ethernet and EEE" -Status "Disabling Green Ethernet..." -PercentComplete 0
            Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "EnableGreenEthernet" -RegistryValue 0 | Out-Null
        }
        else {
            Write-Host "Green Ethernet property not found on the adapter."
        }

        if ($adapterProperties | Where-Object { $_.RegistryKeyword -eq "EEE" }) {
            Write-Progress -Activity "Disabling Green Ethernet and EEE" -Status "Disabling EEE..." -PercentComplete 100
            Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "EEE" -RegistryValue 0 | Out-Null
        }
        else {
            Write-Host "EEE property not found on the adapter."
        }
    }
    catch {
        Write-Error "Failed to disable Green Ethernet and EEE: $_"
    }
}

############ MAIN ############
# Function calls
Show-MWarning

New-MCustomProfile
Disable-MBingSearch
Disable-MFastStartup
Set-MSynchronizeTimeTrigger
Disable-MWSearchIndexer
Disable-MGreenEthernetAndEEE
