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
. "./(Config) Backup scripts.ps1"	# import configuration
. "./Functions.ps1"	# import functions
########################################
try {
	# Start logging
	$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
	Start-Transcript -Path "./logs/BackupScripts_$($CurrentDate).log" -Append
	
	$exitScript = $false
	while (-not $exitScript) {
		Write-Host "`nWoW Backup Scripts" -ForegroundColor Green
		Write-Host "`nSelect a option:" -ForegroundColor Green
		Write-Host "1. Backup character(s)." -ForegroundColor Green
		Write-Host "2. Restore character(s)." -ForegroundColor Green
        Write-Host "3. Backup all accounts and characters." -ForegroundColor Green
        Write-Host "4. Restore all accounts and characters." -ForegroundColor Green
		Write-Host "5. Backup guild(s)." -ForegroundColor Green
		Write-Host "6. Restore guild(s)." -ForegroundColor Green
        Write-Host "7. Backup all guilds." -ForegroundColor Green
        Write-Host "8. Restore all guilds." -ForegroundColor Green
		Write-Host "9. Exit script" -ForegroundColor Green
		
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
################################################################################
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
######################################## exit
		} elseif ($choice -eq 9){
			exit
########################################
		} else {
			Write-Host "`nInvalid choice. Try again." -ForegroundColor Red
		}
########################################
	}
########################################
} catch {
	Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
} finally {
	Stop-Transcript
	# Write-Output "Transcript stopped"
}
########################################
########################################
