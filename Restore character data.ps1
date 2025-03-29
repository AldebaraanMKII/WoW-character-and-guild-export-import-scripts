
###################################################
function Restore-Character {
    param (
        [string]$folder,
        [string]$account,
        [int]$accountID
    )
	
############## PROCESS CHARACTERS.SQL
	# Write-Host "folder is $folder"
	$sqlFilePath = "$CharacterBackupDir\*\$folder\characters.sql"
	if (Test-Path -Path $sqlFilePath) {
		# Write-Host "The file exists: $sqlFilePath"

		# Get the maximum GUID from the characters table
		$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(guid) AS MaxGuid FROM characters"
		
		# Extract the numeric value from the DataRow
		if ($maxGuidResult -and $maxGuidResult.MaxGuid -ne [DBNull]::Value) {
			$maxGuid = $maxGuidResult.MaxGuid
		} else {
			# If no records found, set maxGuid to 0
			$maxGuid = 0
		}
		
		# Calculate the new GUID as the next sequential number
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
		
		Write-Host "`nRestoring character $characterName" -ForegroundColor Yellow
		
		#Execute the query
		Execute-Query -query "$modifiedSqlQuery" -tablename "characters" -ConnectionName "CharConn"
		
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
		
		Write-Host "Importing character data..." -ForegroundColor Yellow
		# Loop through each table in the array
		foreach ($entry in $tables) {
			# Extract the table name and the column number
			$table = $entry[0]
			$columnIndex = $entry[1]

			# Path to the .sql file
			$sqlFilePath = "$CharacterBackupDir\*\$folder\$table.sql"
			
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
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				
				#Execute the query
				Execute-Query -query "$modifiedSqlQuery" -tablename $table -ConnectionName "CharConn"
			}
		}	
############## PROCESS HOMEBIND (this was giving errors because the old azerothcore homebind had a extra column at the end which the new azerothcore doesn`t have)
			$sqlFilePath = "$CharacterBackupDir\*\$folder\character_homebind.sql"
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
				Execute-Query -query "$modifiedSqlQuery" -tablename "character_homebind" -ConnectionName "CharConn"
			}
############## PROCESS PET TABLES
			$sqlFilePath = "$CharacterBackupDir\*\$folder\character_pet.sql"
			
			if (Test-Path -Path $sqlFilePath) {
				Write-Host "Importing pet data..." -ForegroundColor Yellow
				
				$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(id) AS MaxID FROM character_pet"
				
				# Extract the numeric value from the DataRow
				if ($maxGuidResult -and $maxGuidResult.MaxID -ne [DBNull]::Value) {
					$maxGuid = $maxGuidResult.MaxID
				} else {
					# If no records found, set maxGuid to 0
					$maxGuid = 0
				}
				
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
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				
				#Execute the query
				Execute-Query -query "$modifiedSqlQuery" -tablename "character_pet" -ConnectionName "CharConn"
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
					
					$sqlFilePath = "$CharacterBackupDir\*\$folder\$table.sql"
					
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
						# Write-Host "`nModified SQL: $modifiedSqlQuery"
						
						#Execute the query
						Execute-Query -query "$modifiedSqlQuery" -tablename $table -ConnectionName "CharConn"
					}
				}
############################
			}
############################

############################ PROCESS ITEM_INSTANCE - guid[0], owner_guid[2]
		$sqlFilePath = "$CharacterBackupDir\*\$folder\item_instance.sql"
		
		if (Test-Path -Path $sqlFilePath) {
			Write-Host "Importing character items..." -ForegroundColor Yellow
			
			$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(guid) AS MaxGuid FROM item_instance"

			# Extract the numeric value from the DataRow
			if ($maxGuidResult -and $maxGuidResult.MaxGuid -ne [DBNull]::Value) {
				$maxGuid = $maxGuidResult.MaxGuid
			} else {
				# If no records found, set maxGuid to 0
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
			# Write-Host $guidMappingpItems
			
			# Output the modified SQL to verify
			# Write-Host "`nModified SQL: $modifiedSqlQuery"
			
			#Execute the query
			Execute-Query -query "$modifiedSqlQuery" -tablename "item_instance" -ConnectionName "CharConn"
			
############################ PROCESS CHARACTER_INVENTORY - guid[0], bag[1], item[3]
			$sqlFilePath = "$CharacterBackupDir\*\$folder\character_inventory.sql"
			
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
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				
				#Execute the query
				Execute-Query -query "$modifiedSqlQuery" -tablename "character_inventory" -ConnectionName "CharConn"
			}
################## 

############################ PROCESS CUSTOM_TRANSMOGRIFICATION - GUID[0], Owner[2]
			$sqlFilePath = "$CharacterBackupDir\*\$folder\custom_transmogrification.sql"
			
			if (Test-Path -Path $sqlFilePath) {
				Write-Host "Importing transmog item data..." -ForegroundColor Yellow
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
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				
				#Execute the query
				Execute-Query -query "$modifiedSqlQuery" -tablename "custom_transmogrification" -ConnectionName "CharConn"
				
				
############################ PROCESS CUSTOM_TRANSMOGRIFICATION_SETS - Owner[0], PresetID[1]
				$sqlFilePath = "$CharacterBackupDir\*\$folder\custom_transmogrification_sets.sql"
				
				if (Test-Path -Path $sqlFilePath) {
					Write-Host "Importing transmog sets..." -ForegroundColor Yellow
					
					# Get the maximum PresetID from the database
					$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(PresetID) AS MaxPresetID FROM custom_transmogrification_sets"
					
					# Extract the numeric value from the DataRow and check for DBNull
					if ($maxGuidResult -and $maxGuidResult.MaxPresetID -ne [DBNull]::Value) {
						$maxGuid = $maxGuidResult.MaxPresetID
					} else {
						# If no records found or value is DBNull, set maxGuid to 0
						$maxGuid = 0
					}
					
					# Calculate the new starting PresetID
					$newPresetID = $maxGuid + 1
					
					# Read the contents of the .sql file
					$sqlContent = Get-Content -Path $sqlFilePath -Raw
					
					# Improved pattern to handle quoted strings
					$pattern = "(?<=\().*?(?=\))"
					$matches = [regex]::Matches($sqlContent, $pattern)
					
					# List to store modified rows
					$modifiedRows = @()
					
					# Loop through each match
					for ($i = 0; $i -lt $matches.Count; $i++) {
						$match = $matches[$i].Value
						
						# Handle quoted strings properly
						$values = $match -split ",(?=(?:[^']*'[^']*')*[^']*$)"
						
						# Modify the owner GUID
						$values[0] = $newGuid
						
						# Assign a new unique PresetID
						$values[1] = $newPresetID + $i
						
						# Add default values for missing columns
						$setName = "Set $($newPresetID + $i)"
						$items = "0 0"  # Default items string
						
						# Recreate the modified row with all four columns
						$modifiedRow = "($($values[0]), $($values[1]), '$setName', '$items')"
						$modifiedRows += $modifiedRow
					}
					
					# Join the modified rows into the final SQL query
					$modifiedSqlQuery = "INSERT INTO `custom_transmogrification_sets` VALUES " + ($modifiedRows -join ",") + ";"
						
					# Execute the query
					Execute-Query -query $modifiedSqlQuery -tablename "custom_transmogrification_sets" -ConnectionName "CharConn"
				}

############################ PROCESS CUSTOM_UNLOCKED_APPEARANCES - account_id[0], item_template_id[1]
				$sqlFilePath = "$CharacterBackupDir\*\$folder\custom_unlocked_appearances.sql"
				
				if (Test-Path -Path $sqlFilePath) {
					Write-Host "Importing transmog unlocked appearances..." -ForegroundColor Yellow
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
						if (-not (Row-Exists-custom-unlocked-appearances -accountID $accountID -itemTemplateID $itemTemplateID -ConnectionName "CharConn")) {
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
					# Write-Host "`nModified SQL: $modifiedSqlQuery"
					
					#Execute the query
					Execute-Query -query $modifiedSqlQuery -tablename "custom_unlocked_appearances" -ConnectionName "CharConn"
				}
################## END TRANSMOG BRACKET
			}
################## 

############################ PROCESS character_equipmentsets - guid[0], setguid[1]
			$sqlFilePath = "$CharacterBackupDir\*\$folder\character_equipmentsets.sql"
			
			if (Test-Path -Path $sqlFilePath) {
				Write-Host "Importing character equipment sets..." -ForegroundColor Yellow
				
				$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(setguid) AS MaxSetguid FROM character_equipmentsets"

				# Extract the numeric value from the DataRow
				if ($maxGuidResult -and $maxGuidResult.MaxSetguid -ne [DBNull]::Value) {
					$maxGuid = $maxGuidResult.MaxSetguid
				} else {
					# If no records found, set maxGuid to 0
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
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				
				#Execute the query
				Execute-Query -query "$modifiedSqlQuery" -tablename "character_equipmentsets" -ConnectionName "CharConn"
			}
####################################
################## END ITEM BRACKET
		}
#################################################
#################################################
################## END CHARACTER BRACKET
	} else {
		Write-Host "No character file found. Aborting..." -ForegroundColor Red
	}
#################################################
}
###################################################

###################################################
function Restore-Character-Main {
	# Create SimplySql connections
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "AuthConn"
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "CharConn"

################ MENU
	$selectedCharacters = $false
	$selectedCharactersAll = $false
	# Get the account folders (like rndbot3 and test1)
	$accountFolders = Get-ChildItem -Path $CharacterBackupDir -Directory
	
	# Initialize an array to hold all character subfolders
	$characterFolders = @()
	
	# Loop through each account folder to get its subfolders
	foreach ($accountFolder in $accountFolders) {
		$subFolders = Get-ChildItem -Path $accountFolder.FullName -Directory
		$characterFolders += $subFolders
	}
	
	# Check if any character folders were found
	if ($characterFolders.Count -eq 0) {
		Write-Host "No characters found in the directories under '$CharacterBackupDir'." -ForegroundColor Red
		exit
	}
	
	# Display the menu with formatted output
	Write-Host "`nPlease select a character by typing the corresponding number:`n" -ForegroundColor Yellow
	for ($i = 0; $i -lt $characterFolders.Count; $i++) {
		$accountFolder = $characterFolders[$i].Parent.Name
		$folderName = $characterFolders[$i].Name
		Write-Host "$($i + 1). ($accountFolder) $folderName" -ForegroundColor Green
	}
	Write-Host "$($characterFolders.Count + 1). All characters in list" -ForegroundColor Green
	Write-Host "$($characterFolders.Count + 2). Exit" -ForegroundColor Green
	
	# Prompt the user to select a folder or exit
	$selection = Read-Host "`nEnter your choice (1-$($characterFolders.Count + 2))"
	
	# 1
	if ($selection -ge 1 -and $selection -lt ($characterFolders.Count + 1).ToString()) {
		$selectedCharacters = $true
		
		$selectedFolder = $characterFolders[$selection - 1]
		Write-Host "`nYou selected: ($($selectedFolder.Parent.Name)) $($selectedFolder.Name)" -ForegroundColor Yellow
	}
	# All
	elseif ($selection -eq ($characterFolders.Count + 1).ToString()) {
		$selectedCharactersAll = $true
	}
	# Validate the input and handle the exit option
	elseif ($selection -eq ($characterFolders.Count + 2).ToString()) {
		Write-Host "Exiting the script." -ForegroundColor Yellow
		exit
	}
	#invalid
	else {
		Write-Host "`nInvalid selection." -ForegroundColor Red
	}
################################################
################ 	CHARACTER(S) SELECTED
	if ($selectedCharacters -eq $true -or $selectedCharactersAll -eq $true) {
		# Prompt for account name
		$userNameToSearch = Read-Host "Enter account name to transfer the character(s)."
		
		$UsernameID = $null
		try {
			$UsernameID = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id FROM account WHERE username = @userNameToSearch;" -Parameters @{ userNameToSearch = $userNameToSearch }
	
			if ($UsernameID) {
				$AccountId = $UsernameID.id
				Write-Host "`nID for username '$userNameToSearch': $AccountId" -ForegroundColor Yellow
				#1
				if ($selectedCharacters -eq $true){
				$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
				
				# Write-Host "folder is: $($selectedFolder.Name)"
				Restore-Character -folder $($selectedFolder.Name) -account $userNameToSearch -accountID $AccountId
				
				$stopwatch.Stop()
				Write-Host "`nImport done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
				}
				#All
				elseif ($selectedCharactersAll -eq $true){
				$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
				Write-Host "`nImporting up all characters from list." -ForegroundColor Yellow
				
				foreach ($folder in $characterFolders) {
					# Write-Host "folder is: $folder.Name"
					Restore-Character -folder $folder.Name -account $userNameToSearch -accountID $AccountId
				}
				
				$stopwatch.Stop()
				Write-Host "`nImport done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
				}
############################################
			#found no account with that name
			} else {
				Write-Host "`nNo account found with username '$userNameToSearch'" -ForegroundColor Red
			}
		} catch {
		Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
		}
################################################
	}
################################################

	# Close all connections
	Close-SqlConnection -ConnectionName "AuthConn"
	Close-SqlConnection -ConnectionName "CharConn"
	# Close-SqlConnection -ConnectionName "WorldConn"
}
###################################################

###################################################
###################################################

