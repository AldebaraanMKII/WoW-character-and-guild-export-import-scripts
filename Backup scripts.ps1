# Install required module if not already installed
if (-not (Get-Module -ListAvailable -Name SimplySql)) {
    Install-Module -Name SimplySql -Force
}
########################################
# Import the module
Import-Module SimplySql
########################################
. "./(Config) Backup scripts.ps1"	# import configuration
. "./Functions.ps1"	# import functions
# import scripts
. "./Backup character data.ps1"	
. "./Backup guild data.ps1"
. "./Restore character data.ps1"
. "./Restore guild data.ps1"
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
		Write-Host "2. Backup guild(s)." -ForegroundColor Green
		Write-Host "3. Restore character(s)." -ForegroundColor Green
		Write-Host "4. Restore guild(s)." -ForegroundColor Green
		Write-Host "5. Exit script" -ForegroundColor Green
		
		$choice = $(Write-Host "`nType a number (1-5):" -ForegroundColor green -NoNewLine; Read-Host) 
########################################
		if ($choice -eq 1) {
			Backup-Character-Main
########################################
		} elseif ($choice -eq 2){
			Backup-Guild-Main
########################################
		} elseif ($choice -eq 3){
			Restore-Character-Main
########################################
		} elseif ($choice -eq 4){
			Restore-Guild-Main
######################################## exit
		} elseif ($choice -eq 5){
			exit
########################################
		} else {
			Write-Host "`nInvalid choice. Try again." -ForegroundColor Red
		}
########################################
	}
########################################
} catch {
	Write-Error "An error occurred: $($_.Exception.Message)"
} finally {
	Stop-Transcript
	# Write-Output "Transcript stopped"
}
########################################
########################################
