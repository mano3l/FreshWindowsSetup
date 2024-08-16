## Customize the prompt
function prompt {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $identity
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

    $prefix = $(if ($principal.IsInRole($adminRole)) { "👑 " }
                else { "🖥️ " })
    $body = $(Get-Location)
    $suffix = $(if ($NestedPromptLevel -ge 1) { '>>' }) + '> '

    $prefix + $body + $suffix
}

## Customize PSReadLine
Set-PSReadLineOption -PredictionSource None
Set-PSReadLineOption -BellStyle None

Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key Ctrl+y -Function DeleteLine