


# Define connection details
$serverName = "127.0.0.1"
$port = 3306
$username = "root"
$password = "test"
$database_characters = "acore_characters"

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


##############################################################################
function Execute-Query {
    param (
        [string]$query,
        [string]$tablename
    )
		
		# Create a MySQL command object
		$command = $connectionCharacters.CreateCommand()
		$command.CommandText = $query
		
		# Execute the command to apply the modified SQL to the database
		try {
				$command.ExecuteNonQuery() | Out-Null
				# Write-Output "Query for $tablename executed successfully."
		} catch {
				Write-Output "($tablename) An error occurred: $_"
		}
		
}
##############################################################################
function Restore-Guild {
    param (
        [string]$folder,
        [string]$character,
        [int]$characterID,
        [string]$GuildName
    )
		
############## PROCESS GUILD.SQL - alter guildid[0] and leaderguid[2]
		# Write-Host "folder is $folder"
		$sqlFilePath = "$backupDir\$folder\guild.sql"
		if (Test-Path -Path $sqlFilePath) {
				$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
				
				Write-Host "`nRestoring guild $GuildName"
				# Write-Host "The file exists: $sqlFilePath"
				
				# Create a connection to the MySQL database
				$connectionCharacters.Open()
				
				# Create a SQL command to retrieve the maximum guid from the characters table
				$sqlQuery = "SELECT MAX(guildid) FROM guild"
				
				# Create a MySQL command object
				$command = $connectionCharacters.CreateCommand()
				$command.CommandText = $sqlQuery
				
				# Execute the command and retrieve the result
				$maxGuid = $command.ExecuteScalar()
				# Write-Output "The highest GUID in the characters table is: $maxGuid"
				
				# first check if ExecuteScalar found any value on the table
				if ($maxGuid -eq [System.DBNull]::Value) {
						$maxGuid = 0
				}
				#assign new guid to highest value in column guid + 1,
				$newGuid = $maxGuid + 1
				
				
############## CREATE A QUERY FOR GUILD_MEMBER
				# Join the modified rows into the final SQL query
				$modifiedSqlQuery = "INSERT INTO `guild_member` VALUES ($newGuid, $characterID, 0, '', '');"
				
				# Output the modified SQL to verify
				# Write-Output "`nModified SQL: $modifiedSqlQuery"
				
				#Execute the query
				Execute-Query -query $modifiedSqlQuery -tablename "guild_member"
				
############## PROCESS TABLES IN $TABLES ARRAY - alter guildid[0]
				# Array of tables to restore
				# format is tablename, column1, column1value, column2, column2value, column3, column3value
				# use -1 to skip
				# guild = guildid[0], PlayerGuid[2]
				# guild_bank_right, guild_bank_tab, guild_rank = guildid[0]
				# guild_eventlog = guildid[0], PlayerGuid[3]
				# guild_bank_eventlog - guildid[0], PlayerGuid[4]
				$tables = @(
						@("guild", 0, $newGuid, 2, $characterID, -1, -1),
						
						@("guild_bank_right", 0, $newGuid, -1, -1, -1, -1),
						@("guild_bank_tab", 0, $newGuid, -1, -1, -1, -1),
						@("guild_rank", 0, $newGuid, -1, -1, -1, -1),
						
						@("guild_eventlog", 0, $newGuid, 3, $characterID, -1, -1),
						@("guild_bank_eventlog", 0, $newGuid, 4, $characterID, -1, -1)
				)
				
				# Loop through each table in the array
				foreach ($entry in $tables) {
						# Extract the table name and the column number
						$table = $entry[0]
						$columnIndex1 = $entry[1]
						$columnIndex1Value = $entry[2]
						
						$columnIndex2 = $entry[3]
						$columnIndex2Value = $entry[4]
						
						$columnIndex3 = $entry[5]
						$columnIndex3Value = $entry[6]

						# Path to the .sql file
						$sqlFilePath = "$backupDir\$folder\$table.sql"
						
						if (Test-Path -Path $sqlFilePath) {
								# Read the contents of the .sql file
								$sqlContent = Get-Content -Path $sqlFilePath -Raw
								
								# Extract values inside parentheses
								$pattern = "(?<=\().*?(?=\))"
								$matches = [regex]::Matches($sqlContent, $pattern)
								
								# List to store modified rows
								$modifiedRows = @()
								
								# Loop through each match
								for ($i = 0; $i -lt $matches.Count; $i++) {
										$match = $matches[$i].Value
										
										# Split the row into individual values
										$values = $match -split ","
									
										# Modify the first value
										if ($columnIndex1 -ge 0){
											$values[$columnIndex1] = $columnIndex1Value
										}
										
										# Modify the second value
										if ($columnIndex2 -ge 0){
											$values[$columnIndex2] = $columnIndex2Value
										}
										
										# Modify the third value
										if ($columnIndex3 -ge 0){
											$values[$columnIndex3] = $columnIndex3Value
										}
										
										# Recreate the modified row and store it
										$modifiedRow = "(" + ($values -join ",") + ")"
										$modifiedRows += $modifiedRow
								}
								
								# Join the modified rows into the final SQL query
								$modifiedSqlQuery = "INSERT INTO $table VALUES " + ($modifiedRows -join ",") + ";"
								
								# Output the modified SQL to verify
								# Write-Output "`nModified SQL: $modifiedSqlQuery"
								
								#Execute the query
								Execute-Query -query $modifiedSqlQuery -tablename $table
						}
				}		
############################ PROCESS ITEM_INSTANCE - alter guid[0] taking into account existing items
						$sqlFilePath = "$backupDir\$folder\item_instance.sql"
						
						if (Test-Path -Path $sqlFilePath) {
								# Create a SQL command to retrieve the maximum guid from the item_instance table
								$sqlQuery = "SELECT MAX(guid) FROM item_instance"
								
								# Create a MySQL command object
								$command = $connectionCharacters.CreateCommand()
								$command.CommandText = $sqlQuery
								
								# Execute the command and retrieve the result
								$maxGuid = $command.ExecuteScalar()
								# Write-Output "The highest GUID in the item_instance table is: $maxGuid"
								
								#assign new guid to highest value in column guid + 1
								$newItemGuid = $maxGuid + 1
							
								# Read the contents of the .sql file
								$sqlContent = Get-Content -Path $sqlFilePath -Raw
								
								# Initialize the guidMapping as an ArrayList for dynamic addition
								$guidMappingpItems = [System.Collections.ArrayList]::new()

								# Extract values inside parentheses
								$pattern = "(?<=\().*?(?=\))"
								$matches = [regex]::Matches($sqlContent, $pattern)
						
								# List to store modified rows
								$modifiedRows = @()
						
								# Loop through each match
								for ($i = 0; $i -lt $matches.Count; $i++) {
										$match = $matches[$i].Value
										
										# Split the row into individual values
										$values = $match -split ","
										
										# Get the old GUID (first value), trim it for safety in case of spaces
										$oldGuid = $values[0].Trim()
								
										# Modify the first value with the incrementing GUID
										$newItemGuidValue = $newItemGuid + $i
										$values[0] = $newItemGuidValue
								
										# Store the old and new GUIDs in the array
										$guidMappingpItems += [pscustomobject]@{OldGuid = $oldGuid; NewGuid = $newItemGuidValue}

										# Modify the third value with the new GUID
										$values[2] = $newGuid
										
										# Recreate the modified row and store it
										$modifiedRow = "(" + ($values -join ",") + ")"
										$modifiedRows += $modifiedRow
								}
						
								# Join the modified rows into the final SQL query
								$modifiedSqlQuery = "INSERT INTO `item_instance` VALUES " + ($modifiedRows -join ",") + ";"
								
								# Output the array to verify
								# Write-Output $guidMappingpItems
								
								# Output the modified SQL to verify
								# Write-Output "`nModified SQL: $modifiedSqlQuery"
								
								#Execute the query
								Execute-Query -query $modifiedSqlQuery -tablename "item_instance"
								
############################ PROCESS GUILD_BANK_ITEM - alter guidid[0] and item_guid[3]
								$sqlFilePath = "$backupDir\$folder\guild_bank_item.sql"
								
								if (Test-Path -Path $sqlFilePath) {
										# Read the contents of the .sql file
										$sqlContent = Get-Content -Path $sqlFilePath -Raw
										
										# Extract values inside parentheses
										$pattern = "(?<=\().*?(?=\))"
										$matches = [regex]::Matches($sqlContent, $pattern)
										
										# List to store modified rows
										$modifiedRows = @()
								
										# Loop through each match
										for ($i = 0; $i -lt $matches.Count; $i++) {
												$match = $matches[$i].Value
												
												# Split the row into individual values
												$values = $match -split ","
												
###################### THIS IS FOR ITEM_GUID
												# Get the current value in the target column (adjust for 0-based index)
												$currentValue = $values[3]
												
												# Check if the current value matches an old GUID in the mapping
												$matchingGuid = $guidMappingpItems | Where-Object { $_.OldGuid -eq $currentValue }
												
												# If a match is found, replace the old GUID with the new GUID
												if ($matchingGuid) {
														$values[3] = $matchingGuid.NewGuid
												}
###################### THIS IS FOR GUILD GUID
												$values[0] = $newGuid
####################################
												# Recreate the modified row and store it
												$modifiedRow = "(" + ($values -join ",") + ")"
												$modifiedRows += $modifiedRow
										}
								
										# Join the modified rows into the final SQL query
										$modifiedSqlQuery = "INSERT INTO `guild_bank_item` VALUES " + ($modifiedRows -join ",") + ";"
						
										# Output the modified SQL to verify
										# Write-Output "`nModified SQL: $modifiedSqlQuery"
										
										#Execute the query
										Execute-Query -query $modifiedSqlQuery -tablename "guild_bank_item"
								}
########################################################
						}
############################
						$stopwatch.Stop()
						Write-Host "`nSuccessfully imported $GuildName in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..."
						#close connection
						$connectionCharacters.Close()
				} else {
						Write-Host "No guild file found. Aborting..."
				}
#################################################
		}
#################################################


########################################
function Check-Character {
    param (
        [string]$characterNameToSearch
    )
		
		# Query to find guid based on username
    $query = "SELECT guid FROM characters WHERE name = @characterNameToSearch;"
		
		$guid = $null
		try {
				$connectionCharacters.Open()
		
				# Create a command object for auth database
				$command = $connectionCharacters.CreateCommand()
				$command.CommandText = $query
				$command.Parameters.Add((New-Object MySql.Data.MySqlClient.MySqlParameter("@characterNameToSearch", [MySql.Data.MySqlClient.MySqlDbType]::VarChar))).Value = $characterNameToSearch
		
				# Execute the query and read the result
				$reader = $command.ExecuteReader()
		
				if ($reader.Read()) {
						$guid = $reader["guid"]
						Write-Host "`nID for username '$characterNameToSearch': $guid"
						return $guid
##########################
				#found no character with that name
				} else {
						Write-Host "`nNo character found with name '$characterNameToSearch'"
						return $null
				}
				$reader.Close()
##########################
		} catch {
				Write-Host "Error: $($_.Exception.Message)"
		} finally {
				$connectionCharacters.Close()
		}
##########################
}
################################


################################
do {
################ MENU
		$selectedGuild = $false
		$selectedGuildAll = $false
		# Get the account folders (like rndbot3 and test1)
		$accountFolders = Get-ChildItem -Path $backupDir -Directory
		
		# Initialize an array to hold all subfolders
		$guildFolders = @()
		
		# Loop through each account folder to get its subfolders
		foreach ($accountFolder in $accountFolders) {
				$guildFolders += $accountFolder
		}
		
		# Check if any folders were found
		if ($guildFolders.Count -eq 0) {
				Write-Host "No guilds found in the directory '$backupDir'."
				exit
		}
		
		# Display the menu with formatted output
		Write-Host "`nPlease select a guild by typing the corresponding number:`n"
		for ($i = 0; $i -lt $guildFolders.Count; $i++) {
				# $accountFolder = $guildFolders[$i].Parent.Name
				$folderName = $guildFolders[$i].Name
				Write-Host "$($i + 1). $folderName"
		}
		Write-Host "$($guildFolders.Count + 1). All guilds in list"
		Write-Host "$($guildFolders.Count + 2). Exit"
		
		# Prompt the user to select a folder or exit
		$selection = Read-Host "`nEnter your choice (1-$($guildFolders.Count + 2))"
		
		# 1
		if ($selection -ge 1 -and $selection -lt ($guildFolders.Count + 1).ToString()) {
				$selectedGuild = $true
				
				$selectedFolder = $guildFolders[$selection - 1].Name
				
				$GuildName = ($selectedFolder -split " - ")[0]
				Write-Host "`nYou selected: $GuildName"
		}
		# All
		elseif ($selection -eq ($guildFolders.Count + 1).ToString()) {
				$selectedGuildAll = $true
		}
		# Validate the input and handle the exit option
		elseif ($selection -eq ($guildFolders.Count + 2).ToString()) {
				Write-Host "Exiting the script."
				exit
		}
		#invalid
		else {
				Write-Host "`nInvalid selection."
		}
################################################
################ 	CHARACTER(S) SELECTED			
########################## 1
				if ($selectedGuild -eq $true){
						Write-Host "`nThe script requires a character name to transfer the guild $GuildName to."
						# Prompt for account name
						$characterNameToSearch = Read-Host "Enter character name"
						
						$characterGuid = Check-Character -characterNameToSearch $characterNameToSearch
						
						if ($characterGuid){
								Restore-Guild -folder $selectedFolder -character $characterNameToSearch -characterID $characterGuid -GuildName $GuildName
						}
				}
########################### All
				elseif ($selectedGuildAll -eq $true){
						Write-Host "`nImporting up all guilds from list."
						
						foreach ($folder in $guildFolders) {
								$selectedFolder = $folder.Name
								$GuildName = ($selectedFolder -split " - ")[0]
								
								Write-Host "`nThe script requires a character name to transfer the guild $GuildName to."
								# Prompt for account name
								$characterNameToSearch = Read-Host "Enter character name"
								
								$characterGuid = Check-Character -characterNameToSearch $characterNameToSearch
		
								if ($characterGuid){
										Restore-Guild -folder $folder.Name -character $characterNameToSearch -characterID $characterGuid -GuildName $GuildName
								}
						}
				}
################################################

} while (-not $exitScript)
###################################################


