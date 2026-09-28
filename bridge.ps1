# Compatibility entry point. The one real transport is bridge-client.ps1; this file only forwards
# to it so the two can never drift apart again (they had: this copy lacked the preview-safety guard
# and newer commands). Same parameters as bridge-client.ps1.
param(
    [Parameter(Position=0)][string]$Command = 'ping',
    [string]$ArgsJson = '{}',
    [ValidateRange(1,45)][int]$TimeoutSeconds = 15,
    [string]$MailboxPath = (Join-Path $env:LOCALAPPDATA 'CitiesIIAgentBridge'),
    [switch]$LibraryOnly
)
& (Join-Path $PSScriptRoot 'bridge-client.ps1') $Command -ArgsJson $ArgsJson -TimeoutSeconds $TimeoutSeconds -MailboxPath $MailboxPath -LibraryOnly:$LibraryOnly
