# Customize the prompt
function prompt {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $identity
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    $currentLocation = Get-Location
    $homePath = [regex]::Escape($HOME)
    $mhome = $(if ($currentLocation.Path -match "^$homePath") { $currentLocation.Path -replace "^$homePath", "~" } else { $currentLocation })

    $prefix = $(if ($principal.IsInRole($adminRole)) { "👑 " } else { "🖥️ " })

    $body = $mhome

    $suffix = $(if ($NestedPromptLevel -ge 1) { '>>' }) + '>'

    Write-Host -NoNewLine $prefix
    Write-Host -NoNewLine $body
    Write-Host -NoNewLine $suffix -ForegroundColor Blue

    return " "
}

# Customize PSReadLine
Set-PSReadLineOption -PredictionSource None
Set-PSReadLineOption -BellStyle None

Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Ctrl+y -Function DeleteLine

########### Alias ###########

# Create a new folder and cd to it
function mkcd {
    param (
        [string]$newDir
    )
    New-Item -ItemType Directory -Name $newDir | Set-Location -Path {$_.FullName}
}

# Navigate to projects folder
function cdp {
    $projectsDirectory = "$env:HOMEDRIVE" + "$env:HOMEPATH" + "*\Documents\Projetos"
    Set-Location -Path $projectsDirectory
}