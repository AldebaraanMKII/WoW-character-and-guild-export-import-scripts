
########################################
function Backup-Guild {
    param (
        [int]$GuildID,
        [string]$GuildName,
        [int]$LeaderGUID,
        [string]$CreateDate,
        [string]$BankMoney,
        [string]$LeaderName,
        [string]$CreateDateConverted,
        [string]$BankMoneyConverted
    )

    Write-Host "`nBacking up guild $GuildName..." -ForegroundColor Yellow

########### List of tables to back up
    $tables = @(
        "guild",
        "guild_bank_right",
        "guild_bank_tab",
        "guild_bank_item",
        "guild_bank_eventlog",
        "guild_rank"
    )

    foreach ($table in $tables) {
        $backupDirFull = "$GuildBackupDir\$GuildName - $LeaderName"
        if (-not (Test-Path $backupDirFull)) {
            New-Item -Path $backupDirFull -ItemType Directory | Out-Null
        }

        $backupFile = "$backupDirFull\$table.sql"
		
		# Define the mysqldump command
		$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"guildid=$GuildID`" `"$SourceDatabaseCharacters`" `"$table`" > `"$backupFile`""
		# Write-Host "$mysqldumpCommand"

		# Run the mysqldump command
		Invoke-Expression $mysqldumpCommand
		
		if ($LASTEXITCODE -eq 0) {
				# Write-Host "Backed up data from $tableName to $sqlFilePath"
		} else {
				Write-Host "Error backing up data from $tableName" -ForegroundColor Red
		}
    }

########### Handle item_instance table
	try {
		$itemGuids = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT item_guid FROM guild_bank_item WHERE guildid = @GuildID" -Parameters @{GuildID = $GuildID}
		if ($itemGuids.Count -gt 0) {
			# Extract item_guid values from DataRow objects
			$guidList = $itemGuids | ForEach-Object { $_.item_guid } | Where-Object { $_ -ne $null }
			if ($guidList.Count -gt 0) {
				$backupFile = "$backupDirFull\item_instance.sql"
				$whereClause = "guid IN (" + ($guidList -join ',') + ")"
				
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$SourceDatabaseCharacters`" item_instance > `"$backupFile`""
				
				# Write-Host "Running mysqldump command..."
				# Write-Host $mysqldumpCommand
				
				# Run the mysqldump command
				Invoke-Expression $mysqldumpCommand
								
								
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
	try {
		$GuildGuids = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT id FROM guild_house WHERE guild = @GuildID" -Parameters @{GuildID = $GuildID}
		if ($GuildGuids.Count -gt 0) {
			# Extract id values from DataRow objects
			$guidList = $GuildGuids | ForEach-Object { $_.id } | Where-Object { $_ -ne $null }
			if ($guidList.Count -gt 0) {
				$backupFile = "$backupDirFull\guild_house.sql"
				$whereClause = "id IN (" + ($guidList -join ',') + ")"
				
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$SourceDatabaseCharacters`" guild_house > `"$backupFile`""
				
				# Write-Host "Running mysqldump command..."
				# Write-Host $mysqldumpCommand
				
				# Run the mysqldump command
				Invoke-Expression $mysqldumpCommand
								
				if ($LASTEXITCODE -eq 0) {
					# Write-Host "Successfully backed up item_instance table to $backupFile" -ForegroundColor Green
				} else {
					Write-Host "Error backing up guild_house table." -ForegroundColor Red
				}
			}
		}
	} catch {
		Write-Host "Error backing up guild_house table: $_" -ForegroundColor Red
	}
########### Handle creature_respawn table

	$backupFile = "$backupDirFull\creature.sql"
	
	$NPCIds = @(26327, 26324, 26325, 26326, 26328, 26329, 26330, 26331, 26332, 500030, 500031, 500032, 30605, 29195, 2836, 8128, 8736, 18774, 18751, 18773, 18753, 30721, 30722, 19187, 19180, 19052, 908, 2627, 19184, 2834, 19185, 8719, 9856, 184137, 1685, 4087, 500000, 500001, 500002, 500003, 500004, 500005, 500006, 500007, 500008, 500009, 187293, 28692, 28776, 4255, 6491, 191028, 29636, 29493, 28690, 9858, 2622) 
	
	$whereClause = "id1 IN (" + ($NPCIds -join ',') + ") AND map = 1 AND zoneId = 0 AND areaId = 0"
	
	$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$SourceDatabaseWorld`" creature > `"$backupFile`""
	
	# Write-Host "Running mysqldump command..."
	# Write-Host $mysqldumpCommand
	
	# Run the mysqldump command
	Invoke-Expression $mysqldumpCommand

	if ($LASTEXITCODE -eq 0) {
		# Write-Host "Successfully backed up creature table to $backupFile" -ForegroundColor Green
	} else {
		Write-Host "Error backing up creature table." -ForegroundColor Red
	}

########### Delete empty SQL files
    Get-ChildItem -Path $GuildBackupDir -Filter "*.sql" -Recurse | Where-Object { $_.Length -eq 0 } | Remove-Item
}
########################################

########################################
function Backup-Guild-Main {
	# Open database connections
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "CharConn"

    $query = "SELECT g.*, c.name as leader_name 
              FROM guild g 
              LEFT JOIN characters c ON g.leaderguid = c.guid"
    try {
        $guildData = Invoke-SqlQuery -ConnectionName "CharConn" -Query $query

        if ($guildData.Count -gt 0) {
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

                if ($choice -match '^\d+$') {
                    $choice = [int]$choice

                    if ($choice -ge 1 -and $choice -le $guildData.Count) {
                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        $selectedGuild = $guildData[$choice - 1]

                        Backup-Guild -GuildID $selectedGuild.guildid `
                                    -GuildName $selectedGuild.name `
                                    -LeaderGUID $selectedGuild.leaderguid `
                                    -CreateDate $selectedGuild.createdate `
                                    -BankMoney $selectedGuild.BankMoney `
                                    -LeaderName $selectedGuild.leader_name `
                                    -CreateDateConverted $CreateDateConverted `
                                    -BankMoneyConverted $BankMoneyConverted

                        $stopwatch.Stop()
                        Write-Host "Backup done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green

                    } elseif ($choice -eq $index) {
                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                        foreach ($guild in $guildData) {
                            $CreateDateConverted = (Get-Date (ConvertFromUnixTime -unixTime $guild.createdate)).ToString("dd/MM/yyyy HH:mm:ss")
                            $BankMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $guild.BankMoney

                            Backup-Guild -GuildID $guild.guildid `
                                        -GuildName $guild.name `
                                        -LeaderGUID $guild.leaderguid `
                                        -CreateDate $guild.createdate `
                                        -BankMoney $guild.BankMoney `
                                        -LeaderName $guild.leader_name `
                                        -CreateDateConverted $CreateDateConverted `
                                        -BankMoneyConverted $BankMoneyConverted
                        }

                        $stopwatch.Stop()
                        Write-Host "All Guilds backed up in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green

                    } elseif ($choice -eq ($index + 1)) {
                        Write-Host "Exiting script..." -ForegroundColor Yellow
                        $exitScript = $true
                    } else {
                        Write-Host "Invalid selection. Please try again." -ForegroundColor Red
                    }
                } else {
                    Write-Host "Invalid selection. Please try again." -ForegroundColor Red
                }
            }
        } else {
            Write-Host "No guilds found in the database." -ForegroundColor Red
            $exitScript = $true
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        $exitScript = $true
    }
	
	Close-SqlConnection -ConnectionName "CharConn"
}
########################################









