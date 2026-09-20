#requires -Version 7.5
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$GamePath,
 [string]$BuildDirectory=(Join-Path $PSScriptRoot 'artifacts'),
 [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
$manifest=Get-Content (Join-Path $BuildDirectory 'build-manifest.json') -Raw|ConvertFrom-Json
$dll=Join-Path $BuildDirectory 'CitiesIIAgentBridge.dll'
$game=Join-Path $GamePath 'Cities2_Data/Managed/Game.dll'
if((Get-FileHash -LiteralPath $game).Hash -ne $manifest.gameAssemblySha256){throw 'Game.dll fingerprint mismatch. Build against this installation; do not bypass the check.'}
if((Get-FileHash -LiteralPath $dll).Hash -ne $manifest.dllSha256){throw 'Patched DLL hash does not match its build manifest.'}
$destination=Join-Path $env:USERPROFILE 'AppData/LocalLow/Colossal Order/Cities Skylines II/Mods/CitiesIIAgentBridge'
if($CheckOnly){Write-Output "Checks passed. Version $($manifest.modVersion). Destination: $destination. Nothing installed.";return}
if(Get-Process Cities2 -ErrorAction SilentlyContinue){throw 'Save and close Cities II before installation. The installer will not close, kill or restart the game.'}
New-Item -ItemType Directory -Force $destination|Out-Null
$target=Join-Path $destination 'CitiesIIAgentBridge.dll'
if(Test-Path $target){
 $backup=Join-Path $destination ('backups/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Force $backup|Out-Null
 Copy-Item -LiteralPath $target -Destination $backup
 Write-Output "Existing DLL backed up: $backup"
}
Copy-Item -LiteralPath $dll -Destination $target -Force
if((Get-FileHash -LiteralPath $target).Hash -ne $manifest.dllSha256){throw 'Installed hash mismatch. Inspect before launching.'}
Write-Output "Installed $($manifest.modVersion). Runtime test still required. Launch/load your test save, enable controls after loading, and close Options."
