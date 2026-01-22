param (
    [ValidateSet(
        "Backup-Character-Main",
        "Restore-Character-Main",
        "Backup-All-Accounts-Main",
        "Restore-All-Accounts-Main",
        "Backup-Guild-Main",
        "Restore-Guild-Main",
        "Backup-All-Guilds-Main-Wrapper",
        "Restore-All-Guilds-Main"
    )]
    [string]$Function
)

# Install required module if not already installed
if (-not (Get-Module -ListAvailable -Name SimplySql)) {
    Install-Module -Name SimplySql -Force
}
if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
	Install-Module -Name PSSQLite -Force
}
########################################
# Import the module
Import-Module SimplySql
Import-Module PSSQLite
########################################
# Initialize the guidMapping as an ArrayList for dynamic addition
$guidMappingAccounts = [System.Collections.ArrayList]::new()
$guidMappingCharacters = [System.Collections.ArrayList]::new()
$guidMappingpPets = [System.Collections.ArrayList]::new()
$guidMappingItems = [System.Collections.ArrayList]::new()
$guidMappingGuilds = [System.Collections.ArrayList]::new()
########################################
# import configuration
. "$PSScriptRoot/(Config) Backup scripts.ps1"
# import functions
. "$PSScriptRoot/_functions/Utility.ps1"
. "$PSScriptRoot/_functions/Characters-Backup.ps1"
. "$PSScriptRoot/_functions/Characters-Restore.ps1"
. "$PSScriptRoot/_functions/Guilds-Backup.ps1"
. "$PSScriptRoot/_functions/Guilds-Restore.ps1"
. "$PSScriptRoot/_functions/FusionGEN-Backup.ps1"
. "$PSScriptRoot/_functions/FusionGEN-Restore.ps1"
########################################
Function Show-Menu {
	Write-Host "`nWoW Backup/Restore Scripts" -ForegroundColor Green
	Write-Host "`nSelect a option:" -ForegroundColor Green
	Write-Host "1. Backup character(s)." -ForegroundColor Green
	Write-Host "2. Restore character(s)." -ForegroundColor Green
	Write-Host "3. Backup all accounts and characters." -ForegroundColor Green
	Write-Host "4. Restore all accounts and characters." -ForegroundColor Green
	Write-Host "5. Backup guild(s)." -ForegroundColor Green
	Write-Host "6. Restore guild(s)." -ForegroundColor Green
	Write-Host "7. Backup all guilds." -ForegroundColor Green
	Write-Host "8. Restore all guilds." -ForegroundColor Green
	Write-Host "9. Backup FusionGEN data." -ForegroundColor Green
	Write-Host "10. Restore FusionGEN data." -ForegroundColor Green
	Write-Host "11. Exit script" -ForegroundColor Green
}
########################################
try {
	# Start logging
	$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
	Start-Transcript -Path "./logs/BackupScripts_$($CurrentDate).log" -Append
	
    if ($Function) {
        Invoke-Expression -Command $Function
    } else {
        $exitScript = $false
        while (-not $exitScript) {
            Show-Menu #shows menu options
            $choice = $(Write-Host "`nType a number (1-9):" -ForegroundColor green -NoNewLine; Read-Host) 
########################################
            if ($choice -eq 1) {
                Backup-Character-Main
########################################
            } elseif ($choice -eq 2){
                Restore-Character-Main
########################################
            } elseif ($choice -eq 3){
                Backup-All-Accounts-Main
########################################
            } elseif ($choice -eq 4){
                Restore-All-Accounts-Main
########################################
            } elseif ($choice -eq 5){
                Backup-Guild-Main
########################################
            } elseif ($choice -eq 6){
                Restore-Guild-Main
########################################
            } elseif ($choice -eq 7){
                Backup-All-Guilds-Main-Wrapper
########################################
            } elseif ($choice -eq 8){
                Restore-All-Guilds-Main
########################################
            } elseif ($choice -eq 9){
                Backup-FusionGen-Main
########################################
            } elseif ($choice -eq 10){
                Restore-FusionGen-Main
######################################## exit
            } elseif ($choice -eq 11){
                exit
########################################
            } else {
                Write-Host "`nInvalid choice. Try again." -ForegroundColor Red
            }
########################################
        }
    }
########################################
} catch {
	Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
} finally {
	Stop-Transcript
	# Write-Output "Transcript stopped"
}
########################################
