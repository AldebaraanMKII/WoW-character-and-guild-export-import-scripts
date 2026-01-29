#################################################################
#region Backup-Guilds
#################################################################
function Backup-Guild {
	param (
		[int]$GuildID,
		[string]$GuildName,
		[string]$BackupDir
	)

	Write-Host "`nBacking up guild $GuildName..." -ForegroundColor Cyan
	# $backupDirFull = "$GuildBackupDir\$GuildName ($CurrentDate) - $LeaderName"
		
	# Ensure backup directory exists 
	if (-not (Test-Path $BackupDir)) { 
		New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null 
	}
########### Create guild_members.json
	$memberGuids = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT guid FROM guild_member WHERE guildid = @GuildID" -Parameters @{GuildID = $GuildID} 3>$null		#supress warnings when no results found
	$memberMapping = @{}
	if ($memberGuids) {
		foreach ($member in $memberGuids) {
			$memberName = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT name FROM characters WHERE guid = @guid" -Parameters @{guid = $member.guid} 3>$null		#supress warnings when no results found
			if ($memberName) {
				$memberMapping[($member.guid).ToString()] = $memberName.name
			}
		}
	}
	$memberMappingJson = $memberMapping | ConvertTo-Json
	$memberMappingJson | Out-File -FilePath "$($BackupDir)\guild_members.json" -Encoding utf8
	
########### List of tables to back up
	$tables = @(
		"guild",
		"guild_bank_right",
		"guild_bank_tab",
		"guild_bank_item",
		"guild_bank_eventlog",
		"guild_rank",
		"guild_member"
	)

	foreach ($table in $tables) {
		if (-not (Test-Path $BackupDir)) {
			New-Item -Path $BackupDir -ItemType Directory | Out-Null
		}

		$backupFile = "$BackupDir\$table.sql"
		
		# Define the mysqldump command
		$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"guildid=$GuildID`" `"$SourceDatabaseCharacters`" `"$table`" > `"$backupFile`""
		# Write-Host "$mysqldumpCommand"

		# Run the mysqldump command
		Invoke-Expression $mysqldumpCommand 2>$null
		
		if ($LASTEXITCODE -eq 0) {
				# Write-Host "Backed up data from $tableName to $sqlFilePath"
		} else {
				Write-Host "Error backing up data from $tableName" -ForegroundColor Red
		}
	}

########### Handle item_instance table
	try {
		$itemGuids = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT item_guid FROM guild_bank_item WHERE guildid = @GuildID" -Parameters @{GuildID = $GuildID} 3>$null		#supress warnings when no results found
		if ($itemGuids.Count -gt 0) {
			# Extract item_guid values from DataRow objects
			$guidList = $itemGuids | ForEach-Object { $_.item_guid } | Where-Object { $_ -ne $null }
			if ($guidList.Count -gt 0) {
				$backupFile = "$BackupDir\item_instance.sql"
				$whereClause = "guid IN (" + ($guidList -join ',') + ")"
				
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$SourceDatabaseCharacters`" item_instance > `"$backupFile`""
				
				# Write-Host "Running mysqldump command..."
				# Write-Host $mysqldumpCommand
				
				# Run the mysqldump command
				Invoke-Expression $mysqldumpCommand 2>$null
								
								
				if ($LASTEXITCODE -eq 0) {
					# Write-Host "Successfully backed up item_instance table to $backupFile" -ForegroundColor Green
				} else {
					Write-Host "Error backing up item_instance table." -ForegroundColor Red
				}
			}
		}
	} catch {
		Write-Host "Error backing up item_instance table: $_" -ForegroundColor Red
	}
	
########### Guild House Data
	if (Table-Exists -TableName "guild_house" -ConnectionName "CharConn") {
		$GuildGuids = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT id FROM guild_house WHERE guild = @GuildID" -Parameters @{GuildID = $GuildID} 3>$null		#supress warnings when no results found
		if ($GuildGuids.Count -gt 0) {
			# Extract id values from DataRow objects
			$guidList = $GuildGuids | ForEach-Object { $_.id } | Where-Object { $_ -ne $null }
			if ($guidList.Count -gt 0) {
				$backupFile = "$BackupDir\guild_house.sql"
				$whereClause = "id IN (" + ($guidList -join ',') + ")"
				
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$SourceDatabaseCharacters`" guild_house > `"$backupFile`""
				
				# Write-Host "Running mysqldump command..."
				# Write-Host $mysqldumpCommand
				
				# Run the mysqldump command
				Invoke-Expression $mysqldumpCommand 2>$null
								
				if ($LASTEXITCODE -eq 0) {
					# Write-Host "Successfully backed up item_instance table to $backupFile" -ForegroundColor Green
				} else {
					Write-Host "Error backing up guild_house table." -ForegroundColor Red
				}
			}
		}
	}
########### Delete empty SQL files
	Get-ChildItem -Path $GuildBackupDir -Filter "*.sql" -Recurse | Where-Object { $_.Length -eq 0 } | Remove-Item
}
#################################################################
function Backup-Guild-Main {
	param (
		[switch]$AllGuilds
	)
	# Open database connections
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "CharConn"

	$query = "SELECT g.*, c.name as leader_name 
			  FROM guild g 
			  LEFT JOIN characters c ON g.leaderguid = c.guid"
	try {
		$guildData = Invoke-SqlQuery -ConnectionName "CharConn" -Query $query 3>$null		#supress warnings when no results found
		if (-not ([string]::IsNullOrEmpty($GuildNameRegexFilter))) {
			$guildData = $guildData | Where-Object { $_.name -match $GuildNameRegexFilter }
		}
		if (-not ([string]::IsNullOrEmpty($GuildNameRegexFilter))) {
			$guildData = $guildData | Where-Object { $_.name -match $GuildNameRegexFilter }
		}
########################################
		if ($guildData.ItemArray.Length -gt 0) {
			if ($AllGuilds) {
				$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
				
				$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
				foreach ($guild in $guildData) {
					# $CreateDateConverted = (Get-Date (ConvertFromUnixTime -unixTime $guild.createdate)).ToString("dd/MM/yyyy HH:mm:ss")
					# $BankMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $guild.BankMoney
					$GuildName = $guild.name
					$LeaderName = $guild.leader_name
					$BackupDirFull = "$GuildBackupDir\full_backups\$SourceServerName ($($CurrentDate))"
					$BackupDir = "$GuildBackupDir\full_backups\$SourceServerName ($($CurrentDate))\$GuildName ($CurrentDate) - $LeaderName"
					
					Backup-Guild -GuildID $guild.guildid `
								-GuildName $guild.name `
								-BackupDir $BackupDir
				}
################################################### Handle creature table
				Write-Host "Backing up guild NPCs..." -ForegroundColor Cyan
				$backupFile = "$BackupDirFull\creature.sql"
				
				$NPCIds = @(26327, 26324, 26325, 26326, 26328, 26329, 26330, 26331, 26332, 500030, 500031, 500032, 30605, 29195, 2836, 8128, 8736, 18774, 18751, 18773, 18753, 30721, 30722, 19187, 19180, 19052, 908, 2627, 19184, 2834, 19185, 8719, 9856, 184137, 1685, 4087, 500000, 500001, 500002, 500003, 500004, 500005, 500006, 500007, 500008, 500009, 187293, 28692, 28776, 4255, 6491, 191028, 29636, 29493, 28690, 9858, 2622) 
				
				$whereClause = "id1 IN (" + ($NPCIds -join ',') + ") AND map = 1 AND zoneId = 0 AND areaId = 0"
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$SourceDatabaseWorld`" creature > `"$backupFile`""
				
				# Write-Host "Running mysqldump command..."
				# Write-Host $mysqldumpCommand
				
				# Run the mysqldump command
				Invoke-Expression $mysqldumpCommand 2>$null
			
				if ($LASTEXITCODE -eq 0) {
					# Write-Host "Successfully backed up creature table to $backupFile" -ForegroundColor Green
				} else {
					Write-Host "Error backing up creature table." -ForegroundColor Red
				}
########################################
				$stopwatch.Stop()
				Write-Host "All Guilds backed up in $($stopwatch.Elapsed.TotalSeconds) seconds." -ForegroundColor Green
				return
			}
########################################
			$exitScript = $false
			$foundGuild = $true
			while (-not $exitScript) {
				Write-Host "`nFound $($guildData.Count) Guilds." -ForegroundColor Green
				Write-Host "`nGuild List:" -ForegroundColor Green
				$index = 1
				foreach ($guild in $guildData) {
					$CreateDateConverted = (Get-Date (ConvertFromUnixTime -unixTime $guild.createdate)).ToString("dd/MM/yyyy HH:mm:ss")
					$BankMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $guild.BankMoney

					Write-Host "$index. (ID: $($guild.guildid)) $($guild.name) - Leader: $($guild.leader_name), Created at $CreateDateConverted, Bank Money: $BankMoneyConverted" -ForegroundColor Green
					$index++
				}
				Write-Host "$index. Back up all Guilds" -ForegroundColor Green
				Write-Host "$($index + 1). Exit script" -ForegroundColor Green

				$choice = Read-Host "`nType a number (1-$($index + 1))"
########################################
				if ($choice -match '^\d+$') {
					$choice = [int]$choice
########################################
					if ($choice -ge 1 -and $choice -le $guildData.Count) {
						$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
						$selectedGuild = $guildData[$choice - 1]

						$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
						$GuildName = $selectedGuild.name
						$LeaderName = $selectedGuild.leader_name
						$BackupDir = "$GuildBackupDir\single_backups\$GuildName ($CurrentDate) - $LeaderName"
						Backup-Guild -GuildID $selectedGuild.guildid `
									-GuildName $selectedGuild.name `
									-BackupDir $BackupDir

						$stopwatch.Stop()
						Write-Host "Backup done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
########################################
					} elseif ($choice -eq $index) {
						$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

						foreach ($guild in $guildData) {
							# $CreateDateConverted = (Get-Date (ConvertFromUnixTime -unixTime $guild.createdate)).ToString("dd/MM/yyyy HH:mm:ss")
							# $BankMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $guild.BankMoney

							$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
							$GuildName = $guild.name
							$LeaderName = $guild.leader_name
							$BackupDir = "$GuildBackupDir\single_backups\$GuildName ($CurrentDate) - $LeaderName"
							
							Backup-Guild -GuildID $guild.guildid `
										-GuildName $guild.name `
										-BackupDir $BackupDir
						}
						$stopwatch.Stop()
						Write-Host "All Guilds backed up in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
########################################
					} elseif ($choice -eq ($index + 1)) {
						Write-Host "Exiting script..." -ForegroundColor Yellow
						$exitScript = $true
########################################
					} else {
						Write-Host "Invalid selection. Please try again." -ForegroundColor Red
					}
########################################
				} else {
					Write-Host "Invalid selection. Please try again." -ForegroundColor Red
				}
			}
########################################
		} else {
			Write-Host "No guilds found in the database." -ForegroundColor Red
			$exitScript = $true
		}
########################################
	} catch {
		Write-Host "An error occurred (line $($_.InvocationInfo.ScriptLineNumber)): $($_.Exception.Message)" -ForegroundColor Red
		$exitScript = $true
	}
	
	Close-SqlConnection -ConnectionName "CharConn"
	[console]::beep()
}
#################################################################
function Backup-All-Guilds-Main-Wrapper {
	Backup-Guild-Main -AllGuilds
}
#################################################################
#endregion
#################################################################