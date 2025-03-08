
# Using a Timer in the Script
# $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Define connection details
$serverName = "127.0.0.1"
$port = 3306
$username = "root"
$password = "test"
$database_auth = "acore_auth"
$database_characters = "acore_characters"
$database_world = "acore_world"

# Paths to executables
$mysqldumpPath = "H:\My Repack\mysql\bin\mysqldump.exe"  # path to mysqldump executable
$mysqlPath = "H:\My Repack\mysql\bin\mysql.exe"   # path to mysql executable

#backup directory for sqls
$backupDir = "./guild_data"

# Load MySQL assembly
# this version of MySql.Data needs to be 8.x.x and net 8.0 to work with powershell 7.4.x
try {
   Add-Type -Path "./MySql.Data.dll" 2>$null
} catch {

}

# Create a connection string for the acore_characters database
$connectionStringCharacters = "Server=$serverName;Port=$port;Database=$database_characters;User ID=$username;Password=$password;"

# Create and open a MySQL connection to acore_characters
$connectionCharacters = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionStringCharacters)

########################################
function GetCharacterData {
    param (
        [int]$CharacterID,
        [string]$TableName,
        [string]$ColumnNameToGetValue,
        [string]$ColumnNameToSearchForID
    )
		
		# $queryPets = "SELECT id, entry, level, name FROM character_pet WHERE owner = @owner;"

		# Query to find characters based on account ID
		$queryCharacters = "SELECT $ColumnNameToGetValue FROM $TableName WHERE $ColumnNameToSearchForID = @CharacterID;"
	  # Write-Host "`nQuery: $queryCharacters"

		try {
				# $connectionCharacters.Open()	  

				# Create a command object for characters database
				$commandCharacters = $connectionCharacters.CreateCommand()
				$commandCharacters.CommandText = $queryCharacters
				$commandCharacters.Parameters.Add((New-Object MySql.Data.MySqlClient.MySqlParameter("@CharacterID", [MySql.Data.MySqlClient.MySqlDbType]::Int32))).Value = $CharacterID
		
				# Execute the query and read the results into a collection
				$characterData = @()
				$readerCharacters = $commandCharacters.ExecuteReader()
		
				# Initialize variable to hold the return value
        $result = $null
        
        # If the reader finds a result, read the value
        if ($readerCharacters.Read()) {
            # Return the value of the requested column
            $result = $readerCharacters[$ColumnNameToGetValue]
        }

        # Close the reader
        $readerCharacters.Close()

        # Close the connection
				# $connectionCharacters.Close()
				
        # Return the result
        return $result
		}
		catch {
        Write-Host "Error fetching character data: $_"
        return $null
    }
}
########################################
function ConvertToGoldSilverCopper {
    param (
        [int]$MoneyAmount
    )
		
		if ($MoneyAmount -gt 0) {
				# Calculate gold, silver, and copper
				$gold = [math]::Floor($MoneyAmount / 10000)
				$remainingAfterGold = $MoneyAmount % 10000
		
				$silver = [math]::Floor($remainingAfterGold / 100)
				$copper = $remainingAfterGold % 100
		
				# Build the result string
				$result = ""
		
				if ($gold -gt 0) {
						$result += "$gold gold"
				}
		
				if ($silver -gt 0) {
						if ($result -ne "") {
								$result += ", "
						}
						$result += "$silver silver"
				}
		
				if ($copper -gt 0) {
						if ($result -ne "") {
								if ($silver -gt 0) {
										$result += " and "
								} else {
										$result += ", "
								}
						}
						$result += "$copper copper"
				}
		
				# Return the result
				return $result
		}
		else {
				return 0
		}
}
########################################
function ConvertFromUnixTime {
    param (
        [int64]$unixTime
    )

    # Convert the Unix time to DateTime
    $epoch = [datetime]'1970-01-01 00:00:00'
    $readableTime = $epoch.AddSeconds($unixTime).ToLocalTime()

    # Return the formatted date and time
    return $readableTime
}
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
		
		Write-Host "`nBacking up guild $GuildName..."
		

############# BACKUP TABLES WITH GUILDID
		# List of tables to back up
		$tables = @(
				"guild",
				"guild_bank_right",
				"guild_bank_tab",
				"guild_rank",
				"guild_bank_item",
				"guild_bank_eventlog"
		)
		
		foreach ($table in $tables) {
				# Write-Host "Dumping table $table"
				# Create a backup filename
				# e.g. The Breachers - Sylea
				$backupDirFull = "$backupDir\$GuildName - $LeaderName"
				# Create folders if they do not exist
				if (-not (Test-Path $backupDirFull)) {
						New-Item -Path $backupDirFull -ItemType Directory | Out-Null
				}
				
				$backupFile = "$backupDirFull\$table.sql"

				# Define the mysqldump command
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$serverName`" --port=`"$port`" --user=`"$username`" --password=`"$password`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"guildid=$GuildID`" `"$database_characters`" `"$table`" > `"$backupFile`""
				# Write-Host "$mysqldumpCommand"

				# Run the mysqldump command
				Invoke-Expression $mysqldumpCommand
				
				if ($LASTEXITCODE -eq 0) {
						# Write-Host "Backed up data from $tableName to $sqlFilePath"
				} else {
						Write-Host "Error backing up data from $tableName"
				}
		}
############# ITEM INSTANCE
		# Query to retrieve all item_guid values from guild_bank_item where guildid = $GuildID
    $query = "SELECT item_guid FROM guild_bank_item WHERE guildid = @GuildID"

		try {
        # Create a command object
        $command = $connectionCharacters.CreateCommand()
        $command.CommandText = $query
        $command.Parameters.Add((New-Object MySql.Data.MySqlClient.MySqlParameter("@GuildID", [MySql.Data.MySqlClient.MySqlDbType]::Int32))).Value = $GuildID

        # Execute the query
        $reader = $command.ExecuteReader()

        # Initialize a list to store item_guids
        $itemGuids = @()

        # Read the results
        while ($reader.Read()) {
            $itemGuids += $reader["item_guid"]
        }

        # Close the reader
        $reader.Close()
				
				#found items
				if ($itemGuids.Count -gt 0) {
						# Write-Host "Found items in itemGuids list"
						# Construct the SQL query for the item_instance table
						$guidList = $itemGuids -join ','
						$query = "SELECT guid FROM item_instance WHERE guid IN ($guidList);"
		
						# Create a command object
						$command = $connectionCharacters.CreateCommand()
						$command.CommandText = $query
		
						# Execute the query and fetch the GUIDs
						$reader = $command.ExecuteReader()
		
						# Initialize a list to store matching GUIDs from item_instance
						$matchedGuids = @()
		
						# Read the results
						while ($reader.Read()) {
								$matchedGuids += $reader["guid"]
						}
		
						# Close the reader
						$reader.Close()
						
##################found items
						if ($matchedGuids.Count -gt 0) {
								# Write-Host "Found items in matchedGuids list"
								# Define the mysqldump command for each matched GUID
								$backupDirFull = "$backupDir\$GuildName - $LeaderName"
								if (-not (Test-Path $backupDirFull)) {
										New-Item -Path $backupDirFull -ItemType Directory | Out-Null
								}
				
								$backupFile = "$backupDirFull\item_instance.sql"
								
								$whereClause = "guid IN (" + ($matchedGuids -join ',') + ")"
								$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$serverName`" --port=`"$port`" --user=`"$username`" --password=`"$password`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$database_characters`" item_instance > `"$backupFile`""
				
								# Write-Host "Running mysqldump command..."
								# Write-Host $mysqldumpCommand
				
								# Run the mysqldump command
								Invoke-Expression $mysqldumpCommand
				
								if ($LASTEXITCODE -eq 0) {
										# Write-Host "Successfully backed up item_instance table to $backupFile"
								} else {
										Write-Host "Error backing up item_instance table."
								}
						}
####################################
				}
####################################
    } catch {
        Write-Host "Error fetching guild bank items: $_"
    }
###################### DELETE ALL EMPTY SQL FILES
		Get-ChildItem -Path $backupDir -Filter "*.sql" -Recurse | Where-Object { $_.Length -eq 0 } | Remove-Item
#################################
}
########################################


########################################
do {
		# Define the SQL query to retrieve all rows from the guild table
		$query = "SELECT * FROM guild;"
		
		try {
				$connectionCharacters.Open()
		
				# Create a command object for characters database
				$command = $connectionCharacters.CreateCommand()
				$command.CommandText = $query
		
				# Execute the query and read the results into a collection
				$guildData = @()
				$readerGuild = $command.ExecuteReader()
		
				while ($readerGuild.Read()) {
						$guildData += [PSCustomObject]@{
								GuildID   = $readerGuild["guildid"]
								GuildName = $readerGuild["name"]
								LeaderGUID = $readerGuild["leaderguid"]										
								
								CreateDate = $readerGuild["createdate"]
								CreateDateConverted = ConvertFromUnixTime -unixTime $readerGuild["createdate"]
								
								BankMoney = $readerGuild["BankMoney"]
								BankMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $readerGuild["BankMoney"]
						}
				}
				
				#close reader
				$readerGuild.Close()
				
				# $connectionCharacters.Close()
		
				# Now process the character data from the collection
				if ($guildData.Count -gt 0) {
						$exitScript = $false
						$foundGuild = $true
						while (-not $exitScript) {
								Write-Host "`nFound $($guildData.Count) Guilds."
								Write-Host "`nGuild List:"
								$index = 1
								foreach ($guild in $guildData) {
										$GuildID = $guild.GuildID
										$GuildName = $guild.GuildName
										# $LeaderGUID = $guild.LeaderGUID
										$CreateDate = $guild.CreateDate
										$BankMoney = $guild.BankMoney
										$LeaderName = $guild.LeaderName
										
										$LeaderName = GetCharacterData -CharacterID $guild.LeaderGUID -TableName "characters" -ColumnNameToGetValue "name" -ColumnNameToSearchForID "guid"
								
										$CreateDateConverted = $guild.CreateDateConverted
										$BankMoneyConverted = $guild.BankMoneyConverted
										
										Write-Host "$index. (ID: $GuildID) $GuildName - Leader: $LeaderName, Created at $CreateDateConverted, Bank Money: $BankMoneyConverted"
										$index++
								}
								Write-Host "$index. Back up all Guilds"
								# Write-Host "$($index + 1). Go back"
								Write-Host "$($index + 1). Exit script"
		
								$choice = Read-Host "`nType a number (1-$($index + 1))"
		
								if ($choice -match '^\d+$') {
										$choice = [int]$choice
										
										#backup 1
										if ($choice -ge 1 -and $choice -le $guildData.Count) {
												$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
												$selectedGuild = $guildData[$choice - 1]
												
												$LeaderName = GetCharacterData -CharacterID $selectedGuild.LeaderGUID -TableName "characters" -ColumnNameToGetValue "name" -ColumnNameToSearchForID "guid"

												Backup-Guild -GuildID $selectedGuild.GuildID `
																		 -GuildName $selectedGuild.GuildName `
																		 -LeaderGUID $selectedGuild.LeaderGUID `
																		 -CreateDate $selectedGuild.CreateDate `
																		 -BankMoney $selectedGuild.BankMoney `
																		 -LeaderName $LeaderName `
																		 -CreateDateConverted $selectedGuild.CreateDateConverted `
																		 -BankMoneyConverted $selectedGuild.BankMoneyConverted
																		 
												$stopwatch.Stop()
												Write-Host "Backup done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..."
												
										#backup all
										} elseif ($choice -eq $index) {
												$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
												
												foreach ($guild in $guildData) {
														$LeaderName = GetCharacterData -CharacterID $guild.LeaderGUID -TableName "characters" -ColumnNameToGetValue "name" -ColumnNameToSearchForID "guid"

														Backup-Guild -GuildID $guild.GuildID `
																				 -GuildName $guild.GuildName `
																				 -LeaderGUID $guild.LeaderGUID `
																				 -CreateDate $guild.CreateDate `
																				 -BankMoney $guild.BankMoney `
																				 -LeaderName $LeaderName `
																				 -CreateDateConverted $guild.CreateDateConverted `
																				 -BankMoneyConverted $guild.BankMoneyConverted
												}
												
												$stopwatch.Stop()
												Write-Host "All Guilds backed up in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..."
												
										#go back
										##} elseif ($choice -eq ($index + 1)) {
										##		Write-Host "Going back..."
										##		break # This will restart the loop and prompt for a new account name
										##		
										#exit
										} elseif ($choice -eq ($index + 1)) {
												Write-Host "Exiting script..."
												$exitScript = $true
												
										#invalid selection for list
										} else {
												Write-Host "Invalid selection. Please try again."
										}
								} else {
										Write-Host "Invalid selection. Please try again."
								}
						}
				} else {
						Write-Host "No guilds found in the database."
						$exitScript = $true
				}
		} catch {
				Write-Host "Error: $($_.Exception.Message)"
				$exitScript = $true
		} finally {
				$connectionCharacters.Close()
		}

} while (-not $exitScript)
###################################################

