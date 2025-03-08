


# Define connection details
$serverName = "127.0.0.1"
$port = 3306
$username = "root"
$password = "test"
$database_auth = "acore_auth"
$database_characters = "acore_characters"

# Paths to executables
$mysqldumpPath = "H:\My Repack\mysql\bin\mysqldump.exe"  # path to mysqldump executable
$mysqlPath = "H:\My Repack\mysql\bin\mysql.exe"   # path to mysql executable

#backup directory for sqls
$backupDir = "./character_data"

# Load MySQL assembly
# this version of MySql.Data needs to be 8.x.x and net 8.0 to work with powershell 7.4.x
# try {
   # Add-Type -Path "./MySql.Data.dll" 2>$null
# } catch {

# }

# Create a connection string for the acore_auth database
$connectionStringAuth = "Server=$serverName;Port=$port;Database=$database_auth;User ID=$username;Password=$password;"
		
# Create and open a MySQL connection to acore_auth
$connectionAuth = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionStringAuth)

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
# Function to check if a row already exists in a table
function Row-Exists {
    param (
        [int]$accountID,
        [int]$itemTemplateID
    )
    
    # SQL query to check if the row exists
    $query = "SELECT COUNT(*) FROM custom_unlocked_appearances WHERE account_id = @accountID AND item_template_id = @itemTemplateID;"

    # Create a command object
    $command = $connectionCharacters.CreateCommand()
    $command.CommandText = $query
    $command.Parameters.Add((New-Object MySql.Data.MySqlClient.MySqlParameter("@accountID", [MySql.Data.MySqlClient.MySqlDbType]::Int32))).Value = $accountID
    $command.Parameters.Add((New-Object MySql.Data.MySqlClient.MySqlParameter("@itemTemplateID", [MySql.Data.MySqlClient.MySqlDbType]::Int32))).Value = $itemTemplateID

    # Execute the query
    $result = $command.ExecuteScalar()

    # Return true if the row exists, otherwise false
    return ($result -gt 0)
}

##############################################################################
function Restore-Character {
    param (
        [string]$folder,
        [string]$account,
        [int]$accountID
    )
		
############## PROCESS CHARACTERS.SQL
		# Write-Host "folder is $folder"
		$sqlFilePath = "$backupDir\*\$folder\characters.sql"
		if (Test-Path -Path $sqlFilePath) {
				# Write-Host "The file exists: $sqlFilePath"
				
				# Create a connection to the MySQL database
				$connectionCharacters.Open()
				
				# Create a SQL command to retrieve the maximum guid from the characters table
				$sqlQuery = "SELECT MAX(guid) FROM characters"
				
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
				
				# Read the content of the SQL file as a single string
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
					
						# Modify the first value with the incrementing GUID
						$values[0] = $newGuid
				
						# Modify the second value with the new GUID
						$values[1] = $accountID
						
						#gets the character name
						$characterName = $values[2]
						
						# Recreate the modified row and store it
						$modifiedRow = "(" + ($values -join ",") + ")"
						$modifiedRows += $modifiedRow
				}
				
				# Join the modified rows into the final SQL query
				$modifiedSqlQuery = "INSERT INTO `characters` VALUES " + ($modifiedRows -join ",") + ";"
				
				# Output the modified SQL to verify
			  # Write-Output "`nModified SQL: $modifiedSqlQuery"
				
				Write-Host "`nRestoring character $characterName"
				
				#Execute the query
				Execute-Query -query $modifiedSqlQuery -tablename "characters"
				
############## PROCESS TABLES IN $TABLES ARRAY
				# Array of tables to restore
				# format is tablename, column
				$tables = @(
						@("character_account_data", 0),
						@("character_achievement_progress", 0),
						@("character_action", 0),
						@("character_aura", 0),
						@("character_glyphs", 0),
						@("character_queststatus", 0),
						@("character_queststatus_rewarded", 0),
						@("character_reputation", 0),
						@("character_skills", 0),
						@("character_spell", 0),
						@("character_talent", 0),
						@("mail_sender", 4),
						@("mail_receiver", 5),
						@("custom_reagent_bank", 0)          #new
				)
				
				Write-Output "Importing character data..."
				# Loop through each table in the array
				foreach ($entry in $tables) {
						# Extract the table name and the column number
						$table = $entry[0]
						$columnIndex = $entry[1]

						# Path to the .sql file
						$sqlFilePath = "$backupDir\*\$folder\$table.sql"
						
						if (Test-Path -Path $sqlFilePath) {
								# Read the contents of the .sql file
								$sqlContent = Get-Content -Path $sqlFilePath -Raw
								
								# Pattern to match the correct column
								# The pattern matches values inside parentheses (ignoring the last comma)
								$pattern = "(?<=\().*?(?=\))"
								
								# Replace function
								$modifiedSqlQuery = [regex]::Replace($sqlContent, $pattern, { 
									param($match) 
									
									# Split the row into values
									$values = $match.Value -split ","
									
									# Replace the value at the target column index
									$values[$columnIndex] = $newGuid
									
									# Join back the modified values
									return ($values -join ",")
								})
								
								# Output the modified SQL to verify
								# Write-Output "`nModified SQL: $modifiedSqlQuery"
								
								#Execute the query
								Execute-Query -query $modifiedSqlQuery -tablename $table
						}
				}		
############## PROCESS HOMEBIND (this was giving errors because the old azerothcore homebind had a extra column at the end which the new azerothcore doesn`t have)
						$sqlFilePath = "$backupDir\*\$folder\character_homebind.sql"
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
										
										# Check if the 7th column exists (index 6), and remove it if it does
										if ($values.Count -ge 7) {
												# $values = $values[0..6] + $values[7..($values.Count - 1)]
												$values = $values[0..5]
										}
										
										# Modify the first value with the incrementing GUID
										$values[0] = $newGuid
								
										# Recreate the modified row and store it
										$modifiedRow = "(" + ($values -join ",") + ")"
										$modifiedRows += $modifiedRow
								}
								
								# Join the modified rows into the final SQL query
								$modifiedSqlQuery = "INSERT INTO `character_homebind` VALUES " + ($modifiedRows -join ",") + ";"
								
								#Execute the query
								Execute-Query -query $modifiedSqlQuery -tablename "character_homebind"
						}
############## PROCESS PET TABLES
						$sqlFilePath = "$backupDir\*\$folder\character_pet.sql"
						
						if (Test-Path -Path $sqlFilePath) {
								Write-Output "Importing pet data..."
								
								# Create a SQL command to retrieve the maximum guid from the character_pet table
								$sqlQuery = "SELECT MAX(id) FROM character_pet"
								
								# Create a MySQL command object
								$command = $connectionCharacters.CreateCommand()
								$command.CommandText = $sqlQuery
								
								# Execute the command and retrieve the result
								$maxGuid = $command.ExecuteScalar()
								# Write-Output "The highest GUID in the character_pet table is: $maxGuid"
								
								#assign new guid to highest value in column guid + 1
								$newPetGuid = $maxGuid + 1
							
								# Read the contents of the .sql file
								$sqlContent = Get-Content -Path $sqlFilePath -Raw
								
								# Initialize the guidMapping as an ArrayList for dynamic addition
								$guidMappingpPets = [System.Collections.ArrayList]::new()

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
										$newPetGuidValue = $newPetGuid + $i
										$values[0] = $newPetGuidValue
								
										# Store the old and new GUIDs in the array
										$guidMappingpPets += [pscustomobject]@{OldGuid = $oldGuid; NewGuid = $newPetGuidValue}

										# Modify the third value with the new GUID
										$values[2] = $newGuid
										
										# Recreate the modified row and store it
										$modifiedRow = "(" + ($values -join ",") + ")"
										$modifiedRows += $modifiedRow
								}
						
								# Join the modified rows into the final SQL query
								$modifiedSqlQuery = "INSERT INTO `character_pet` VALUES " + ($modifiedRows -join ",") + ";"
    
								# Output the modified SQL to verify
								# Write-Output "`nModified SQL: $modifiedSqlQuery"
								
								#Execute the query
								Execute-Query -query $modifiedSqlQuery -tablename "character_pet"
############## PROCESS OTHER PET TABLES
								$tables = @(
										@("pet_aura", 1),
										@("pet_spell", 1),
										@("pet_spell_cooldown", 1)
								)
				
								# Loop through each table in the array
								foreach ($entry in $tables) {
										# Extract the table name and the column number
										$table = $entry[0]
										$columnIndex = $entry[1]
										
										$sqlFilePath = "$backupDir\*\$folder\$table.sql"
										
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
														
														# Get the current value in the target column (adjust for 0-based index)
														$currentValue = $values[$columnIndex - 1]
														
														# Check if the current value matches an old GUID in the mapping
														$matchingGuid = $guidMappingpPets | Where-Object { $_.OldGuid -eq $currentValue }
														
														# If a match is found, replace the old GUID with the new GUID
														if ($matchingGuid) {
																$values[$columnIndex - 1] = $matchingGuid.NewGuid
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
						}
############################

############################ PROCESS ITEM_INSTANCE - guid[0], owner_guid[2]
				$sqlFilePath = "$backupDir\*\$folder\item_instance.sql"
				
				if (Test-Path -Path $sqlFilePath) {
						Write-Output "Importing character items..."
						# Create a SQL command to retrieve the maximum guid from the item_instance table
						$sqlQuery = "SELECT MAX(guid) FROM item_instance"
						
						# Create a MySQL command object
						$command = $connectionCharacters.CreateCommand()
						$command.CommandText = $sqlQuery
						
						# Execute the command and retrieve the result
						$maxGuid = $command.ExecuteScalar()
						# Write-Output "The highest GUID in the item_instance table is: $maxGuid"
						
						# first check if ExecuteScalar found any value on the table
						if ($maxGuid -eq [System.DBNull]::Value) {
								$maxGuid = 0
						}
						
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
								# $oldGuid = $values[0].Trim()
								$oldGuid = $values[0]
						
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
						
############################ PROCESS CHARACTER_INVENTORY - guid[0], bag[1], item[3]
						$sqlFilePath = "$backupDir\*\$folder\character_inventory.sql"
						
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
										
###################### THIS IS FOR ITEM GUID
										# Get the current value in the target column (adjust for 0-based index)
										$currentValue = $values[3]
										
										# Check if the current value matches an old GUID in the mapping
										$matchingGuid = $guidMappingpItems | Where-Object { $_.OldGuid -eq $currentValue }
										
										# If a match is found, replace the old GUID with the new GUID
										if ($matchingGuid) {
												$values[3] = $matchingGuid.NewGuid
										}
####################################
###################### THIS IS FOR BAG GUID
										# Get the current value in the target column (adjust for 0-based index)
										$currentValue = $values[1]
										
										# Check if the current value matches an old GUID in the mapping
										$matchingGuid = $guidMappingpItems | Where-Object { $_.OldGuid -eq $currentValue }
										
										# If a match is found, replace the old GUID with the new GUID
										if ($matchingGuid) {
												$values[1] = $matchingGuid.NewGuid
										}
####################################
###################### THIS IS FOR OWNER GUID
										$values[0] = $newGuid
####################################
										# Recreate the modified row and store it
										$modifiedRow = "(" + ($values -join ",") + ")"
										$modifiedRows += $modifiedRow
								}
						
								# Join the modified rows into the final SQL query
								$modifiedSqlQuery = "INSERT INTO `character_inventory` VALUES " + ($modifiedRows -join ",") + ";"
						
								# Output the modified SQL to verify
								# Write-Output "`nModified SQL: $modifiedSqlQuery"
								
								#Execute the query
								Execute-Query -query $modifiedSqlQuery -tablename "character_inventory"
						}
################## 

############################ PROCESS CUSTOM_TRANSMOGRIFICATION - GUID[0], Owner[2]
						$sqlFilePath = "$backupDir\*\$folder\custom_transmogrification.sql"
						
						if (Test-Path -Path $sqlFilePath) {
								Write-Output "Importing transmog item data..."
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
										
###################### THIS IS FOR ITEM GUID
										# Get the current value in the target column (adjust for 0-based index)
										$currentValue = $values[0]
										
										# Check if the current value matches an old GUID in the mapping
										$matchingGuid = $guidMappingpItems | Where-Object { $_.OldGuid -eq $currentValue }
										
										# If a match is found, replace the old GUID with the new GUID
										if ($matchingGuid) {
												$values[0] = $matchingGuid.NewGuid
										}
####################################
###################### THIS IS FOR OWNER GUID
										$values[2] = $newGuid
####################################
										# Recreate the modified row and store it
										$modifiedRow = "(" + ($values -join ",") + ")"
										$modifiedRows += $modifiedRow
								}
						
								# Join the modified rows into the final SQL query
								$modifiedSqlQuery = "INSERT INTO `custom_transmogrification` VALUES " + ($modifiedRows -join ",") + ";"
						
								# Output the modified SQL to verify
								# Write-Output "`nModified SQL: $modifiedSqlQuery"
								
								#Execute the query
								Execute-Query -query $modifiedSqlQuery -tablename "custom_transmogrification"
								
								
############################ PROCESS CUSTOM_TRANSMOGRIFICATION_SETS - Owner[0], PresetID[1]
								$sqlFilePath = "$backupDir\*\$folder\custom_transmogrification_sets.sql"
								
								if (Test-Path -Path $sqlFilePath) {
										Write-Output "Importing transmog sets..."
										# Create a SQL command to retrieve the maximum guid from the custom_transmogrification_sets table
										$sqlQuery = "SELECT MAX(PresetID) FROM custom_transmogrification_sets"
										
										# Create a MySQL command object
										$command = $connectionCharacters.CreateCommand()
										$command.CommandText = $sqlQuery
										
										# Execute the command and retrieve the result
										$maxGuid = $command.ExecuteScalar()
										# Write-Output "The highest GUID in the custom_transmogrification_sets table is: $maxGuid"
										
										# first check if ExecuteScalar found any value on the table
										if ($maxGuid -eq [System.DBNull]::Value) {
												$maxGuid = 0
										}
										
										#assign new guid to highest value in column guid + 1
										$newPresetID = $maxGuid + 1
									
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
												
												$oldGuid = $values[0]
										
												# Modify the value with the new GUID
												$values[0] = $newGuid
												
												# Modify the first value with the incrementing GUID
												$values[1] = $newPresetID + $i
										
												# Recreate the modified row and store it
												$modifiedRow = "(" + ($values -join ",") + ")"
												$modifiedRows += $modifiedRow
										}
								
										# Join the modified rows into the final SQL query
										$modifiedSqlQuery = "INSERT INTO `custom_transmogrification_sets` VALUES " + ($modifiedRows -join ",") + ";"
										
										# Output the modified SQL to verify
										# Write-Output "`nModified SQL: $modifiedSqlQuery"
										
										#Execute the query
										Execute-Query -query $modifiedSqlQuery -tablename "custom_transmogrification_sets"
								}
####################################
								
############################ PROCESS CUSTOM_UNLOCKED_APPEARANCES - account_id[0], item_template_id[1]
								$sqlFilePath = "$backupDir\*\$folder\custom_unlocked_appearances.sql"
								
								if (Test-Path -Path $sqlFilePath) {
										Write-Output "Importing transmog unlocked appearances..."
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
												
												# Extract account_id and item_template_id
												# $accountID = [int]$values[0]
												$itemTemplateID = $values[1]
								
												# Check if the row already exists in the database
												if (-not (Row-Exists -accountID $accountID -itemTemplateID $itemTemplateID)) {
														$values[0] = $accountID # Update this with the appropriate variable for the new account ID
								
														# Recreate the modified row and store it
														$modifiedRow = "(" + ($values -join ",") + ")"
														$modifiedRows += $modifiedRow
												}
										}
										
										#remove duplicates
										$modifiedRows = $modifiedRows | Select-Object -Unique
										
										# Join the modified rows into the final SQL query
										$modifiedSqlQuery = "INSERT INTO `custom_unlocked_appearances` VALUES " + ($modifiedRows -join ",") + ";"
										
										# Output the modified SQL to verify
										# Write-Output "`nModified SQL: $modifiedSqlQuery"
										
										#Execute the query
										Execute-Query -query $modifiedSqlQuery -tablename "custom_unlocked_appearances"
								}
								
####################################
################## END TRANSMOG BRACKET
						}
################## 

############################ PROCESS character_equipmentsets - guid[0], setguid[1]
						$sqlFilePath = "$backupDir\*\$folder\character_equipmentsets.sql"
						
						if (Test-Path -Path $sqlFilePath) {
								Write-Output "Importing character equipment sets..."
								# Create a SQL command to retrieve the maximum guid from the character_equipmentsets table
								$sqlQuery = "SELECT MAX(setguid) FROM character_equipmentsets"
								
								# Create a MySQL command object
								$command = $connectionCharacters.CreateCommand()
								$command.CommandText = $sqlQuery
								
								# Execute the command and retrieve the result
								$maxGuid = $command.ExecuteScalar()
								# Write-Output "The highest GUID in the character_equipmentsets table is: $maxGuid"
								
								# first check if ExecuteScalar found any value on the table
								if ($maxGuid -eq [System.DBNull]::Value) {
										$maxGuid = 0
								}
								
								#assign new guid to highest value in column guid + 1
								$newID = $maxGuid + 1
							
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
										
										$oldGuid = $values[0]
								
										# Modify the value with the new GUID
										$values[0] = $newGuid
										
										# Modify the first value with the incrementing GUID
										$values[1] = $newID + $i
								
										# Recreate the modified row and store it
										$modifiedRow = "(" + ($values -join ",") + ")"
										$modifiedRows += $modifiedRow
								}
						
								# Join the modified rows into the final SQL query
								$modifiedSqlQuery = "INSERT INTO `character_equipmentsets` VALUES " + ($modifiedRows -join ",") + ";"
								
								# Output the modified SQL to verify
								# Write-Output "`nModified SQL: $modifiedSqlQuery"
								
								#Execute the query
								Execute-Query -query $modifiedSqlQuery -tablename "character_equipmentsets"
						}
####################################


################## END ITEM BRACKET
				}
#################################################
#################################################
				#close connection
				$connectionCharacters.Close()
################## END CHARACTER BRACKET
		} else {
				Write-Host "No character file found. Aborting..."
		}
#################################################
}
########################################



do {
################ MENU
		$selectedCharacters = $false
		$selectedCharactersAll = $false
		# Get the account folders (like rndbot3 and test1)
		$accountFolders = Get-ChildItem -Path $backupDir -Directory
		
		# Initialize an array to hold all character subfolders
		$characterFolders = @()
		
		# Loop through each account folder to get its subfolders
		foreach ($accountFolder in $accountFolders) {
				$subFolders = Get-ChildItem -Path $accountFolder.FullName -Directory
				$characterFolders += $subFolders
		}
		
		# Check if any character folders were found
		if ($characterFolders.Count -eq 0) {
				Write-Host "No characters found in the directories under '$backupDir'."
				exit
		}
		
		# Display the menu with formatted output
		Write-Host "`nPlease select a character by typing the corresponding number:`n"
		for ($i = 0; $i -lt $characterFolders.Count; $i++) {
				$accountFolder = $characterFolders[$i].Parent.Name
				$folderName = $characterFolders[$i].Name
				Write-Host "$($i + 1). ($accountFolder) $folderName"
		}
		Write-Host "$($characterFolders.Count + 1). All characters in list"
		Write-Host "$($characterFolders.Count + 2). Exit"
		
		# Prompt the user to select a folder or exit
		$selection = Read-Host "`nEnter your choice (1-$($characterFolders.Count + 2))"
		
		# 1
		if ($selection -ge 1 -and $selection -lt ($characterFolders.Count + 1).ToString()) {
				$selectedCharacters = $true
				
				$selectedFolder = $characterFolders[$selection - 1]
				Write-Host "`nYou selected: ($($selectedFolder.Parent.Name)) $($selectedFolder.Name)"
		}
		# All
		elseif ($selection -eq ($characterFolders.Count + 1).ToString()) {
				$selectedCharactersAll = $true
		}
		# Validate the input and handle the exit option
		elseif ($selection -eq ($characterFolders.Count + 2).ToString()) {
				Write-Host "Exiting the script."
				exit
		}
		#invalid
		else {
				Write-Host "`nInvalid selection."
		}
################################################
################ 	CHARACTER(S) SELECTED
		if ($selectedCharacters -eq $true -or $selectedCharactersAll -eq $true) {
				# Prompt for account name
				$userNameToSearch = Read-Host "Enter account name to transfer the character(s)."
				
				# Query to find id based on username
				$queryAuth = "SELECT id FROM account WHERE username = @userNameToSearch;"
		
				$id = $null
						try {
								$connectionAuth.Open()
				
								# Create a command object for auth database
								$commandAuth = $connectionAuth.CreateCommand()
								$commandAuth.CommandText = $queryAuth
								$commandAuth.Parameters.Add((New-Object MySql.Data.MySqlClient.MySqlParameter("@userNameToSearch", [MySql.Data.MySqlClient.MySqlDbType]::VarChar))).Value = $userNameToSearch
				
								# Execute the query and read the result
								$readerAuth = $commandAuth.ExecuteReader()
				
								if ($readerAuth.Read()) {
										$id = $readerAuth["id"]
										Write-Host "`nID for username '$userNameToSearch': $id"
										#1
										if ($selectedCharacters -eq $true){
												$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
												
												# Write-Host "folder is: $($selectedFolder.Name)"
												Restore-Character -folder $($selectedFolder.Name) -account $userNameToSearch -accountID $id
												
												$stopwatch.Stop()
                        Write-Host "`nImport done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..."
										}
										#All
										elseif ($selectedCharactersAll -eq $true){
												$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
												Write-Host "`nImporting up all characters from list."
												
												foreach ($folder in $characterFolders) {
														# Write-Host "folder is: $folder.Name"
														Restore-Character -folder $folder.Name -account $userNameToSearch -accountID $id
												}
												
												$stopwatch.Stop()
                        Write-Host "`nImport done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..."
										}
								#found no account with that name
								} else {
										Write-Host "`nNo account found with username '$userNameToSearch'"
								}
								$readerAuth.Close()
						} catch {
								Write-Host "Error: $($_.Exception.Message)"
						} finally {
								$connectionAuth.Close()
						}
		}
################################################

} while (-not $exitScript)
###################################################


