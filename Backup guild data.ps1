
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

    # List of tables to back up
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

    # Handle item_instance table
	try {
		$itemGuids = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT item_guid FROM guild_bank_item WHERE guildid = @GuildID" -Parameters @{GuildID = $GuildID}
		if ($itemGuids.Count -gt 0) {
			# Extract item_guid values from DataRow objects
			$guidList = $itemGuids | ForEach-Object { $_.item_guid } | Where-Object { $_ -ne $null }
			if ($guidList.Count -gt 0) {
				$backupFile = "$backupDirFull\item_instance.sql"
				$whereClause = "guid IN (" + ($guidList -join ',') + ")"
				
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$SourceDatabaseCharacters`" item_instance > `"$backupFile`""
				
				# Run the mysqldump command
				# Start-Process -FilePath "cmd.exe" -ArgumentList "/c $mysqldumpCommand" -Wait
				
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
	

    # Delete empty SQL files
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









