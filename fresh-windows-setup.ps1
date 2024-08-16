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

# Sets an execution trigger on the "SynchronizeTime" task and set "Windows Time" to auto start so the 
# clock is synchronized with the Microsoft server when the machine is turned on
function Set-MSynchronizeTimeTrigger {
    try {
        Write-Progress -Activity "Creating Scheduled Task" -Status "Creating trigger..." -PercentComplete 0
        $TaskValues = @{
            TaskPath = "\Microsoft\Windows\Time Synchronization\"
            TaskName = "SynchronizeTime"
            Trigger  = New-ScheduledTaskTrigger -AtStartup
        }

        Write-Progress -Activity "Creating Scheduled Task" -Status "Setting scheduled task..." -PercentComplete 100
        Set-ScheduledTask @TaskValues | Out-Null
    }
    catch {
        Write-Error "Failed to create the scheduled task: $_"
    }

    try {
        Write-Progress -Activity "Enabling Windows Time" -Status "Setting W32Time startup type to automatic..." -PercentComplete 0
        Set-Service -Name "W32Time" -StartupType Automatic
        Write-Progress -Activity "Disabling Window Search Indexer" -Status "Starting W32Time service..." -PercentComplete 100
        Start-Service -Name "W32Time"
    }
    catch {
        Write-Error "Failed to start windows time service: $_"
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
    }
    catch {
        Write-Error "Failed to disable delivery optmization service: $_"
        return
    }

    try {
        Write-Progress -Activity "Disabling Delivery Optimization" -Status "Adding entry..." -PercentComplete 100
        Stop-Service -Name "DoSvc"
    }
    catch {
        Write-Error "Failed to stop delivery optimization service: $_"
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

############ MAIN ############
# Function calls
Show-MWarning
Disable-MBingSearch
Set-MSynchronizeTimeTrigger
Disable-MWSearchIndexer
New-MCustomProfile
