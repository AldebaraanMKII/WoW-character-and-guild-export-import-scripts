#################################################################
#region Restore-Characters
#################################################################
function Restore-Character {
	param (
		[string]$account,
		[int]$accountID,
		[string]$BackupDir
	)
############## PROCESS CHARACTERS.SQL
	# Write-Host "folder is $BackupDir"
	# $sqlFilePath = "$BackupDir\*\$folder\characters.sql"
	$sqlFilePath = "$BackupDir\characters.sql"
	if (Test-Path -Path $sqlFilePath) {
		if (Table-Exists -TableName "characters" -ConnectionName "CharConn") {
			# Write-Host "The file exists: $sqlFilePath"
	
			# Get the maximum GUID from the characters table
			$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(guid) AS MaxGuid FROM characters" 3>$null		#supress warnings when no results found
			
			# Extract the numeric value from the DataRow
			if ($maxGuidResult -and $maxGuidResult.MaxGuid -ne [DBNull]::Value) {
				$maxGuid = $maxGuidResult.MaxGuid
			} else {
				# If no records found, set maxGuid to 0
				$maxGuid = 0
			}
			
			# Calculate the new GUID as the next sequential number
			$newGuid = $maxGuid + 1
			# Write-Host "New GUID: $newGuid" -ForegroundColor Cyan
				
			# Read the content of the SQL file as a single string
			$sqlContent = Get-Content -Path $sqlFilePath -Raw
			
			# Extract values inside parentheses
			$pattern = "(?<=\().*?(?=\))"
			$matches = [regex]::Matches($sqlContent, $pattern)
			
			# List to store modified rows
			$modifiedRows = @()
############################################
			# Loop through each match
			for ($i = 0; $i -lt $matches.Count; $i++) {
				$match = $matches[$i].Value
				
				# Split the row into individual values
				$values = $match -split ","
				
				$oldGuid = $values[0]
				
				# Modify the first value with the incrementing GUID
				$values[0] = $newGuid
			
				# Modify the second value with the new GUID
				$values[1] = $accountID
				
				#gets the character name
				$characterName = $values[2]
				
				$guidMappingCharacters.Add([pscustomobject]@{
					CharacterName = $characterName
					OldGuid       = $oldGuid
					NewGuid       = $newGuid
				}) | Out-Null
				# Write-Host "`nAdded mapping: $characterName (OldGuid=$oldGuid, NewGuid=$newGuid)" -ForegroundColor Cyan
				
				# Recreate the modified row and store it
				$modifiedRow = "(" + ($values -join ",") + ")"
				$modifiedRows += $modifiedRow
			}
			
			# if ($modifiedRows.Count -gt 0) {
			# Join the modified rows into the final SQL query
			$modifiedSqlQuery = "INSERT INTO characters VALUES " + ($modifiedRows -join ",") + ";"
############################################
			# check if character exists first, if yes return
			$Query = "SELECT guid FROM characters WHERE name = $characterName LIMIT 1;"
			$ValueColumn = "guid"
			$ConnectionName = "CharConn"
			$result = Check-Value-in-DB -Query $Query -ValueColumn $ValueColumn -ConnectionName $ConnectionName
			if ($result) {
				Write-Host "`nCharacter $($characterName) already exists in database! Skipping..." -ForegroundColor Yellow
				return
			}
############################################
			Write-Host "`nRestoring character $($characterName)..." -ForegroundColor Cyan
		
			# Output the modified SQL to verify
			# Write-Output "`nModified SQL: $modifiedSqlQuery"
			# Execute the query
			Execute-Query -query "$modifiedSqlQuery" -tablename "characters" -ConnectionName "CharConn"
			# } else {
				# Write-Host "`nNo characters.sql rows modified. Report this to the script developer." -ForegroundColor Red
				# return
			# }
############################################ PROCESS TABLES IN $TABLES ARRAY
			# Array of tables to restore
			# format is tablename, column index 1, column value 1, column index 2, column value 2, column index 3, column value 3
			$tables = @(
				@("character_account_data", 0, $newGuid, -1, -1, -1, -1),
				@("character_achievement", 0, $newGuid, -1, -1, -1, -1),		#fix achievements not being restored
				@("character_achievement_progress", 0, $newGuid, -1, -1, -1, -1),
				@("character_action", 0, $newGuid, -1, -1, -1, -1),
				@("character_aura", 0, $newGuid, -1, -1, -1, -1),
				@("character_glyphs", 0, $newGuid, -1, -1, -1, -1),
				@("character_queststatus", 0, $newGuid, -1, -1, -1, -1),
				@("character_queststatus_rewarded", 0, $newGuid, -1, -1, -1, -1),
				@("character_reputation", 0, $newGuid, -1, -1, -1, -1),
				@("character_skills", 0, $newGuid, -1, -1, -1, -1),
				@("character_spell", 0, $newGuid, -1, -1, -1, -1),
				@("character_talent", 0, $newGuid, -1, -1, -1, -1),
				@("mail_sender", 4, $newGuid, -1, -1, -1, -1),
				@("mail_receiver", 5, $newGuid, -1, -1, -1, -1),
				@("custom_reagent_bank", 0, $newGuid, -1, -1, -1, -1),		  #new
				@("character_settings", 0, $newGuid, -1, -1, -1, -1),		  #new 27-12-2025
				################ new 13-01-2026
				@("character_arena_stats", 0, $newGuid, -1, -1, -1, -1),
				@("character_banned", 0, $newGuid, -1, -1, -1, -1),
				@("character_battleground_random", 0, $newGuid, -1, -1, -1, -1),
				@("character_brew_of_the_month", 0, $newGuid, -1, -1, -1, -1),
				@("character_entry_point", 0, $newGuid, -1, -1, -1, -1),
				@("character_instance", 0, $newGuid, -1, -1, -1, -1),
				@("character_queststatus_daily", 0, $newGuid, -1, -1, -1, -1),
				@("character_queststatus_weekly", 0, $newGuid, -1, -1, -1, -1),
				@("character_queststatus_monthly", 0, $newGuid, -1, -1, -1, -1),
				@("character_queststatus_seasonal", 0, $newGuid, -1, -1, -1, -1),
				@("character_spell_cooldown", 0, $newGuid, -1, -1, -1, -1),
				@("character_stats", 0, $newGuid, -1, -1, -1, -1),
				@("beastmaster_tamed_pets", 0, $newGuid, -1, -1, -1, -1),
				@("mod_improved_bank", 1, $newGuid, 2, $accountID, -1, -1),
				################ new 14-01-2026
				@("battleground_deserters", 0, $newGuid, -1, -1, -1, -1)
				####################
			)
			
			Write-Host "Importing character data..." -ForegroundColor Cyan
			# Loop through each table in the array
			foreach ($entry in $tables) {
				# Extract the table name and the column number
				$table = $entry[0]
	
				# Path to the .sql file
				# $sqlFilePath = "$CharacterBackupDir\*\$folder\$table.sql"
				$sqlFilePath = "$BackupDir\$table.sql"
				
				if (Test-Path -Path $sqlFilePath) {
					if (Table-Exists -TableName $table -ConnectionName "CharConn") {
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
						
							# Loop through column/value pairs (index 1/2, 3/4, 5/6 in $entry)
							for ($i = 1; $i -lt $entry.Count; $i += 2) {
								$colIndex = $entry[$i]
								$colValue = $entry[$i + 1]
						
								if ($colIndex -ne -1 -and $colValue -ne -1) {
									# Replace the value at the target column index
									$values[$colIndex] = $colValue
								}
							}
						
							# Join back the modified values
							return ($values -join ",")
						})

						
						# Output the modified SQL to verify
						# Write-Host "`nModified SQL: $modifiedSqlQuery"
						
						#Execute the query
						Execute-Query -query "$modifiedSqlQuery" -tablename $table -ConnectionName "CharConn"
					} else {
						Write-Host "Table '$table' does not exist, skipping restore for this table." -ForegroundColor Yellow
					}
				}
			}
############################################ PROCESS HOMEBIND (this was giving errors because the old azerothcore homebind had a extra column at the end which the new azerothcore doesn`t have)
				$sqlFilePath = "$BackupDir\character_homebind.sql"
				if (Test-Path -Path $sqlFilePath) {
					if (Table-Exists -TableName "character_homebind" -ConnectionName "CharConn") {
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
						$modifiedSqlQuery = "INSERT INTO character_homebind VALUES " + ($modifiedRows -join ",") + ";"
						
						#Execute the query
						Execute-Query -query "$modifiedSqlQuery" -tablename "character_homebind" -ConnectionName "CharConn"
					} else {
						Write-Host "Table 'character_homebind' does not exist, skipping restore for this table." -ForegroundColor Red
					}
				}
############################################ PROCESS PET TABLES
				#region Pet Tables
				$sqlFilePath = "$BackupDir\character_pet.sql"
				
				
				if (Test-Path -Path $sqlFilePath) {
					if (Table-Exists -TableName "character_pet" -ConnectionName "CharConn") {
						Write-Host "Importing pet data..." -ForegroundColor Cyan
						
						$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(id) AS MaxID FROM character_pet" 3>$null		#supress warnings when no results found
						
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
						$guidMappingpPetsTemp = [System.Collections.ArrayList]::new()
						
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
							$PetName = $values[9].Trim()
							$guidMappingpPets.Add([pscustomobject]@{
								PetName       = $PetName
								OldGuid       = $oldGuid
								NewGuid       = $newPetGuidValue
							}) | Out-Null
							
							#add to temp guid mapping, because using the above caused slowdowns over time
							$guidMappingpPetsTemp.Add([pscustomobject]@{
								PetName       = $PetName
								OldGuid       = $oldGuid
								NewGuid       = $newPetGuidValue
							}) | Out-Null
							
							# Modify the third value with the new GUID
							$values[2] = $newGuid
							
							# Recreate the modified row and store it
							$modifiedRow = "(" + ($values -join ",") + ")"
							$modifiedRows += $modifiedRow
						}
					
						# Join the modified rows into the final SQL query
						$modifiedSqlQuery = "INSERT INTO character_pet VALUES " + ($modifiedRows -join ",") + ";"
			
						# Output the modified SQL to verify
						# Write-Host "`nModified SQL: $modifiedSqlQuery"
						
						#Execute the query
						Execute-Query -query "$modifiedSqlQuery" -tablename "character_pet" -ConnectionName "CharConn"
############################################ PROCESS OTHER PET TABLES
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
							
							$sqlFilePath = "$BackupDir\$table.sql"
							
							if (Test-Path -Path $sqlFilePath) {
								if (Table-Exists -TableName $table -ConnectionName "CharConn") {
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
										$matchingGuid = $guidMappingpPetsTemp | Where-Object { $_.OldGuid -eq $currentValue }
										
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
								} else {
									Write-Host "Table '$table' does not exist, skipping restore for this table." -ForegroundColor Red
								}
							}
						}
############################################
					} else {
						Write-Host "Table 'character_pet' does not exist, skipping restore for this table." -ForegroundColor Red
					}
				}
				#endregion
############################################ PROCESS ITEM_INSTANCE - guid[0], owner_guid[2]
			#region ITEM_INSTANCE
			$sqlFilePath = "$BackupDir\item_instance.sql"
			
			if (Test-Path -Path $sqlFilePath) {
				if (Table-Exists -TableName "item_instance" -ConnectionName "CharConn") {
					Write-Host "Importing character items..." -ForegroundColor Cyan
					
					$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(guid) AS MaxGuid FROM item_instance" 3>$null		#supress warnings when no results found
	
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
	
					#initialize temp guid mapping, because using the main one caused slowdowns that got worse over time
					$guidMappingItemsTemp = [System.Collections.ArrayList]::new()
						
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
						#add to list
						$guidMappingItems.Add([pscustomobject]@{
							OldGuid       = $oldGuid
							NewGuid       = $newItemGuidValue
						}) | Out-Null
						
						#temp guid mapping
						$guidMappingItemsTemp.Add([pscustomobject]@{
							OldGuid       = $oldGuid
							NewGuid       = $newItemGuidValue
						}) | Out-Null
						
						# Modify the third value with the new GUID
						$values[2] = $newGuid
						
						# Recreate the modified row and store it
						$modifiedRow = "(" + ($values -join ",") + ")"
						$modifiedRows += $modifiedRow
					}
				
					# Join the modified rows into the final SQL query
					$modifiedSqlQuery = "INSERT INTO item_instance VALUES " + ($modifiedRows -join ",") + ";"
					
					# Output the array to verify
					# Write-Host $guidMappingpItemsTemp
					
					# Output the modified SQL to verify
					# Write-Host "`nModified SQL: $modifiedSqlQuery"
					
					#Execute the query
					Execute-Query -query "$modifiedSqlQuery" -tablename "item_instance" -ConnectionName "CharConn"
					
############################################ PROCESS CHARACTER_INVENTORY - guid[0], bag[1], item[3]
					$sqlFilePath = "$BackupDir\character_inventory.sql"
					
					if (Test-Path -Path $sqlFilePath) {
						if (Table-Exists -TableName "character_inventory" -ConnectionName "CharConn") {
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
								
############################################ THIS IS FOR ITEM GUID
								# Get the current value in the target column (adjust for 0-based index)
								$currentValue = $values[3]
								
								# Check if the current value matches an old GUID in the mapping
								$matchingGuid = $guidMappingItemsTemp | Where-Object { $_.OldGuid -eq $currentValue }
								
								# If a match is found, replace the old GUID with the new GUID
								if ($matchingGuid) {
									$values[3] = $matchingGuid.NewGuid
								}
############################################ THIS IS FOR BAG GUID
								# Get the current value in the target column (adjust for 0-based index)
								$currentValue = $values[1]
								
								# Check if the current value matches an old GUID in the mapping
								$matchingGuid = $guidMappingItemsTemp | Where-Object { $_.OldGuid -eq $currentValue }
								
								# If a match is found, replace the old GUID with the new GUID
								if ($matchingGuid) {
									$values[1] = $matchingGuid.NewGuid
								}
############################################ THIS IS FOR OWNER GUID
								$values[0] = $newGuid
############################################
								# Recreate the modified row and store it
								$modifiedRow = "(" + ($values -join ",") + ")"
								$modifiedRows += $modifiedRow
							}
						
							# Join the modified rows into the final SQL query
							$modifiedSqlQuery = "INSERT INTO character_inventory VALUES " + ($modifiedRows -join ",") + ";"
						
							# Output the modified SQL to verify
							# Write-Host "`nModified SQL: $modifiedSqlQuery"
							
							#Execute the query
							Execute-Query -query "$modifiedSqlQuery" -tablename "character_inventory" -ConnectionName "CharConn"
						} else {
							Write-Host "Table 'character_inventory' does not exist, skipping restore for this table." -ForegroundColor Red
						}
					} 
############################################ PROCESS auctionhouse - itemguid[2], itemowner[3]
					$sqlFilePath = "$BackupDir\auctionhouse.sql"
					
					if (Test-Path -Path $sqlFilePath) {
						if (Table-Exists -TableName "auctionhouse" -ConnectionName "CharConn") {
							# Read the contents of the .sql file
							$sqlContent = Get-Content -Path $sqlFilePath -Raw
							
############################################
							$maxIDResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(id) AS MaxID FROM auctionhouse" 3>$null		#supress warnings when no results found
			
							# Extract the numeric value from the DataRow
							if ($maxIDResult -and $maxIDResult.MaxID -ne [DBNull]::Value) {
								$maxID = $maxIDResult.MaxID
							} else {
								# If no records found, set maxID to 0
								$maxID = 0
							}
							
							#assign new ID to highest value in column ID + 1
							$newAuctionID = $maxID + 1
############################################
							
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
############################################ THIS IS FOR AUCTION ID
								#get a new ID
								$newAuctionIDValue = $newAuctionID + $i
								$values[0] = $newAuctionIDValue
############################################ THIS IS FOR ITEM GUID
								# Get the current value in the target column (adjust for 0-based index)
								$currentValue = $values[2]
								
								# Check if the current value matches an old GUID in the mapping
								$matchingGuid = $guidMappingItemsTemp | Where-Object { $_.OldGuid -eq $currentValue }
								
								# If a match is found, replace the old GUID with the new GUID
								if ($matchingGuid) {
									$values[2] = $matchingGuid.NewGuid
								}
############################################ THIS IS FOR OWNER GUID
								$values[3] = $newGuid
############################################
								# Recreate the modified row and store it
								$modifiedRow = "(" + ($values -join ",") + ")"
								$modifiedRows += $modifiedRow
							}
						
							# Join the modified rows into the final SQL query
							$modifiedSqlQuery = "INSERT INTO auctionhouse VALUES " + ($modifiedRows -join ",") + ";"
						
							# Output the modified SQL to verify
							# Write-Host "`nModified SQL: $modifiedSqlQuery"
							
							#Execute the query
							Execute-Query -query "$modifiedSqlQuery" -tablename "auctionhouse" -ConnectionName "CharConn"
						} else {
							Write-Host "Table 'auctionhouse' does not exist, skipping restore for this table." -ForegroundColor Red
						}
					}
############################################ 
	
############################################ PROCESS CUSTOM_TRANSMOGRIFICATION - GUID[0], Owner[2]
					#region TRANSMOG
					$sqlFilePath = "$BackupDir\custom_transmogrification.sql"
					
					if (Test-Path -Path $sqlFilePath) {
						if (Table-Exists -TableName "custom_transmogrification" -ConnectionName "CharConn") {
							Write-Host "Importing transmog item data..." -ForegroundColor Cyan
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
								
############################################ THIS IS FOR ITEM GUID
								# Get the current value in the target column (adjust for 0-based index)
								$currentValue = $values[0]
								
								# Check if the current value matches an old GUID in the mapping
								$matchingGuid = $guidMappingItemsTemp | Where-Object { $_.OldGuid -eq $currentValue }
								
								# If a match is found, replace the old GUID with the new GUID
								if ($matchingGuid) {
									$values[0] = $matchingGuid.NewGuid
								}
############################################ THIS IS FOR OWNER GUID
								$values[2] = $newGuid
############################################
								# Recreate the modified row and store it
								$modifiedRow = "(" + ($values -join ",") + ")"
								$modifiedRows += $modifiedRow
							}
						
							# Join the modified rows into the final SQL query
							$modifiedSqlQuery = "INSERT INTO custom_transmogrification VALUES " + ($modifiedRows -join ",") + ";"
						
							# Output the modified SQL to verify
							# Write-Host "`nModified SQL: $modifiedSqlQuery"
							
							#Execute the query
							Execute-Query -query "$modifiedSqlQuery" -tablename "custom_transmogrification" -ConnectionName "CharConn"
						} else {
							Write-Host "Table 'custom_transmogrification' does not exist, skipping restore for this table." -ForegroundColor Red
						}
						
						
############################################ PROCESS CUSTOM_TRANSMOGRIFICATION_SETS - Owner[0], PresetID[1]
						$sqlFilePath = "$BackupDir\custom_transmogrification_sets.sql"
						
						if (Test-Path -Path $sqlFilePath) {
							if (Table-Exists -TableName "custom_transmogrification_sets" -ConnectionName "CharConn") {
								Write-Host "Importing transmog sets..." -ForegroundColor Cyan
								
								# Get the maximum PresetID from the database
								$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(PresetID) AS MaxPresetID FROM custom_transmogrification_sets" 3>$null		#supress warnings when no results found
								
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
								$modifiedSqlQuery = "INSERT INTO custom_transmogrification_sets VALUES " + ($modifiedRows -join ",") + ";"
									
								# Execute the query
								Execute-Query -query $modifiedSqlQuery -tablename "custom_transmogrification_sets" -ConnectionName "CharConn"
							} else {
								Write-Host "Table 'custom_transmogrification_sets' does not exist, skipping restore for this table." -ForegroundColor Red
							}
						}
	
############################################ PROCESS CUSTOM_UNLOCKED_APPEARANCES - account_id[0], item_template_id[1]
						$sqlFilePath = "$BackupDir\custom_unlocked_appearances.sql"
						
						if (Test-Path -Path $sqlFilePath) {
							if (Table-Exists -TableName "custom_unlocked_appearances" -ConnectionName "CharConn") {
								Write-Host "Importing transmog unlocked appearances..." -ForegroundColor Cyan
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
									$Query = "SELECT COUNT(*) as count FROM custom_unlocked_appearances WHERE account_id = $AccountID AND item_template_id = $ItemTemplateID;"
									$ValueColumn = "count"
									$ConnectionName = "CharConn"
									$result = Check-Value-in-DB -Query $Query -ValueColumn $ValueColumn -ConnectionName $ConnectionName
					
									if (-not ($result)) {
										$values[0] = $accountID # Update this with the appropriate variable for the new account ID
										
										# Recreate the modified row and store it
										$modifiedRow = "(" + ($values -join ",") + ")"
										$modifiedRows += $modifiedRow
									}
								}
								
								#remove duplicates
								$modifiedRows = $modifiedRows | Select-Object -Unique
								
								if ($modifiedRows.Count -gt 0) {
									# Join the modified rows into the final SQL query
									$modifiedSqlQuery = "INSERT INTO custom_unlocked_appearances VALUES " + ($modifiedRows -join ",") + ";"
									
									# Output the modified SQL to verify
									# Write-Host "`nModified SQL: $modifiedSqlQuery"
									
									#Execute the query
									Execute-Query -query $modifiedSqlQuery -tablename "custom_unlocked_appearances" -ConnectionName "CharConn"
								}							
							} else {
								Write-Host "Table 'custom_unlocked_appearances' does not exist, skipping restore for this table." -ForegroundColor Red
							}
						}
						#endregion
############################################ END TRANSMOG BRACKET
					}
############################################ 
	
############################################ PROCESS character_equipmentsets - guid[0], setguid[1]
					$sqlFilePath = "$BackupDir\character_equipmentsets.sql"
					
					if (Test-Path -Path $sqlFilePath) {
						if (Table-Exists -TableName "character_equipmentsets" -ConnectionName "CharConn") {
							Write-Host "Importing character equipment sets..." -ForegroundColor Cyan
							
							$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(setguid) AS MaxSetguid FROM character_equipmentsets" 3>$null		#supress warnings when no results found
	
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
							$modifiedSqlQuery = "INSERT INTO character_equipmentsets VALUES " + ($modifiedRows -join ",") + ";"
							
							# Output the modified SQL to verify
							# Write-Host "`nModified SQL: $modifiedSqlQuery"
							
							#Execute the query
							Execute-Query -query "$modifiedSqlQuery" -tablename "character_equipmentsets" -ConnectionName "CharConn"
						} else {
							Write-Host "Table 'character_equipmentsets' does not exist, skipping restore for this table." -ForegroundColor Red
						}
					}
################################################################################
				} else {
					Write-Host "Table 'item_instance' does not exist, skipping restore for this table." -ForegroundColor Red
				}
#################################### END ITEM BRACKET
			}
			#endregion
			Write-Host "Character $($characterName) restored!" -ForegroundColor Green
#################################################
		} else {
			Write-Host "Table 'characters' does not exist, skipping restore for this table." -ForegroundColor Red
			continue	#skip to the next character
		}
#################################################
################## END CHARACTER BRACKET
	} else {
		Write-Host "No character file found. Aborting..." -ForegroundColor Red
	}
#################################################
}
#################################################################
function Restore-Multiple-Character-Tables {
	param (
		[string]$account,
		[int]$accountID,
		[string]$BackupDir
	)
	
	# Store the old and new GUIDs in the array
############################################
	# Write-Host "Restore-Multiple-Character-Tables: Folder is $BackupDir." -ForegroundColor Yellow
	$sqlFilePath = "$BackupDir\character_social.sql"
	if (Test-Path -Path $sqlFilePath) {
		# Write-Host "Restore-Multiple-Character-Tables: Found character_social.sql." -ForegroundColor Yellow
		if (Table-Exists -TableName "character_social" -ConnectionName "CharConn") {
			# Write-Host "Restore-Multiple-Character-Tables: Found character_social table." -ForegroundColor Yellow
			# Read the content of the SQL file as a single string
			$sqlContent = Get-Content -Path $sqlFilePath -Raw
			
			# Extract values inside parentheses
			$pattern = "(?<=\().*?(?=\))"
			$matches = [regex]::Matches($sqlContent, $pattern)
			
			# List to store modified rows
			$modifiedRows = @()
############################################
			# Loop through each match
			for ($i = 0; $i -lt $matches.Count; $i++) {
				$match = $matches[$i].Value
				
				# Split the row into individual values
				$values = $match -split ","
				
				# character GUID
				$oldGuid = $values[0]
				# Find the entry with matching OldGuid 
				$match = $guidMappingCharacters | Where-Object { $_.OldGuid -eq $oldGuid } 
				if ($match) { # Update NewGuid 
					$values[0] = $match.NewGuid
					# Write-Host "Restore-Multiple-Character-Tables: Found index 0 character in database: $($match.CharacterName) (ID: $($match.NewGuid))." -ForegroundColor Green
				} else {
					# Write-Host "Restore-Multiple-Character-Tables: Didn't find index 0 character in database: (ID: $($oldGuid))." -ForegroundColor Yellow
					continue
				}
				
				# friend GUID
				$oldGuid = $values[1]
				$match = $guidMappingCharacters | Where-Object { $_.OldGuid -eq $oldGuid } 
				if ($match) { # Update NewGuid 
					$values[1] = $match.NewGuid
					# Write-Host "Restore-Multiple-Character-Tables: Found index 1 character in database: $($match.CharacterName) (ID: $($match.NewGuid))." -ForegroundColor Green
				} else {
					# Write-Host "Restore-Multiple-Character-Tables: Didn't find index 1 character in database: (ID: $($oldGuid))." -ForegroundColor Yellow
					continue
				}
				
				# Recreate the modified row and store it
				$modifiedRow = "(" + ($values -join ",") + ")"
				$modifiedRows += $modifiedRow
			}
############################################
			if ($modifiedRows.Count -gt 0) {
				# Join the modified rows into the final SQL query
				$modifiedSqlQuery = "INSERT INTO character_social VALUES " + ($modifiedRows -join ",") + ";"
				# Output the modified SQL to verify
				# Write-Output "`nModified SQL: $modifiedSqlQuery"
				# Execute the query
				Execute-Query -query "$modifiedSqlQuery" -tablename "character_social" -ConnectionName "CharConn"
			}
############################################
		}
	}
############################################
}
#################################################################
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
	
	#clear global array list of characters
	$guidMappingCharacters.Clear()
	
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
	Write-Host "`nPlease select a character by typing the corresponding number:`n" -ForegroundColor Cyan
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
		Write-Host "`nYou selected: ($($selectedFolder.Parent.Name)) $($selectedFolder.Name)" -ForegroundColor Cyan
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
			$UsernameID = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id FROM account WHERE username = @userNameToSearch;" -Parameters @{ userNameToSearch = $userNameToSearch } 3>$null		#supress warnings when no results found
	
			if ($UsernameID) {
				$AccountId = $UsernameID.id
				Write-Host "`nID for username '$userNameToSearch': $AccountId" -ForegroundColor Cyan
				#1
				if ($selectedCharacters -eq $true){
				$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
				
				# Write-Host "folder is: $($selectedFolder.Name)"
				Restore-Character -account $userNameToSearch -accountID $AccountId -BackupDir $selectedFolder
				
				$stopwatch.Stop()
				Write-Host "`nImport done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
				}
				#All
				elseif ($selectedCharactersAll -eq $true){
				$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
				Write-Host "`nImporting up all characters from list." -ForegroundColor Cyan
				
				foreach ($folder in $characterFolders) {
					# Write-Host "folder is: $folder.Name"
					Restore-Character -account $userNameToSearch -accountID $AccountId -BackupDir $folder
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
	[console]::beep()
}
#################################################################
function Restore-All-Accounts-Main {
	# Create SimplySql connections
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "AuthConn"
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "CharConn"
####################################################################
	try {
		# Get all backup folders under full_backups
		$backupRoot = "$CharacterBackupDir\full_backups"
		
		if (-not (Test-Path $backupRoot)) {
			Write-Host "`nNo full backups found in '$backupRoot'." -ForegroundColor Red
			return
		}
		
		$backupFolders = Get-ChildItem -Path $backupRoot -Directory
		
		if ($backupFolders.Count -eq 0) {
			Write-Host "`nNo full backups found in '$backupRoot'." -ForegroundColor Red
			return
		}
		
		# Display numbered list of available backup folders
		Write-Host "`nAvailable backup folders:" -ForegroundColor Cyan
		for ($i = 0; $i -lt $backupFolders.Count; $i++) {
			Write-Host "[$i] $($backupFolders[$i].Name)"
		}
		
		# Prompt user to choose one
		$selection = Read-Host "Enter the number of the full backup you want to use"
		
		# Validate input
		if ($selection -notmatch '^\d+$' -or [int]$selection -ge $backupFolders.Count) {
			Write-Host "Invalid selection." -ForegroundColor Red
			return
		}
		
		# Get the chosen folder
		$chosenFolder = $backupFolders[$selection].FullName
		Write-Host "`nYou selected: $($chosenFolder.Name)" -ForegroundColor Green
		
		# Now you can use $chosenFolder as the parent path for account folders
		$accountFolders = Get-ChildItem -Path $chosenFolder -Directory
		if ($accountFolders.Count -eq 0) {
			Write-Host "No account backups found in '$chosenFolder'." -ForegroundColor Red
			return
		}

		Write-Host "Found $($accountFolders.Count) account backups. Starting restore process..." -ForegroundColor Cyan
		$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
		
		#clear global array lists
		$guidMappingAccounts.Clear()
		$guidMappingCharacters.Clear()
		$guidMappingpPets.Clear()
		$guidMappingItems.Clear()
		#List to store character folder paths
		$CharacterFolderList = @()
####################################################################
		Write-Host "`nDeleting existing characters..." -ForegroundColor Blue
		#delete all character data before full restore, needed because of bots that may have similar names as players
		$Query = 'DELETE FROM `acore_characters`.`characters` WHERE `name` != "Ahbot";
		DELETE FROM `acore_characters`.`auctionhouse` WHERE `itemowner` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`arena_team_member` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`arena_team` WHERE `arenaTeamId` NOT IN (SELECT `arenaTeamId` FROM `acore_characters`.`arena_team_member`);
		DELETE FROM `acore_characters`.`character_account_data` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_achievement` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_achievement_progress` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_action` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_aura` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_glyphs` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_homebind` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`item_instance` WHERE `owner_guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`) AND `owner_guid` > 0;
		DELETE FROM `acore_characters`.`character_inventory` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_pet` WHERE `owner` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`pet_aura` WHERE `guid` NOT IN (SELECT `id` FROM `acore_characters`.`character_pet`);
		DELETE FROM `acore_characters`.`pet_spell` WHERE `guid` NOT IN (SELECT `id` FROM `acore_characters`.`character_pet`);
		DELETE FROM `acore_characters`.`pet_spell_cooldown` WHERE `guid` NOT IN (SELECT `id` FROM `acore_characters`.`character_pet`);
		DELETE FROM `acore_characters`.`character_arena_stats` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_banned` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_entry_point` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_instance` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_queststatus` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_queststatus_rewarded` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_reputation` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_settings` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_skills` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_social` WHERE `friend` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_spell` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_spell_cooldown` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_stats` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_talent` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_queststatus` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_queststatus_daily` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_queststatus_monthly` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_queststatus_rewarded` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_queststatus_seasonal` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_queststatus_weekly` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`character_queststatus_daily` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`corpse` WHERE `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`groups` WHERE `leaderGuid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`group_member` WHERE `memberGuid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`mail` WHERE `receiver` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`mail_items` WHERE `receiver` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`guild` WHERE `leaderguid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`guild_bank_eventlog` WHERE `guildid` NOT IN (SELECT `guildid` FROM `acore_characters`.`guild`);
		DELETE FROM `acore_characters`.`guild_member` WHERE `guildid` NOT IN (SELECT `guildid` FROM `acore_characters`.`guild`) OR `guid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`guild_rank` WHERE `guildid` NOT IN (SELECT `guildid` FROM `acore_characters`.`guild`);
		DELETE FROM `acore_characters`.`petition` WHERE `ownerguid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`petition_sign` WHERE `ownerguid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`) OR `playerguid` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`custom_reagent_bank` WHERE `character_id` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`custom_transmogrification` WHERE `Owner` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);
		DELETE FROM `acore_characters`.`custom_transmogrification_sets` WHERE `Owner` NOT IN (SELECT `guid` FROM `acore_characters`.`characters`);'
####################################################################
		Invoke-SqlUpdate -ConnectionName "CharConn" -Query $Query | Out-Null
####################################################################
		foreach ($accountFolder in $accountFolders) {
			$accountName = $accountFolder.Name
			Write-Host "`nRestoring account: $accountName" -ForegroundColor Blue

			# Check if account exists
			$accountResult = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id FROM account WHERE username = @username" -Parameters @{ username = $accountName } 3>$null		#supress warnings when no results found
			$accountId = $null
####################################################################
			if ($accountResult) {
				$accountId = $accountResult.id
				Write-Host "Account '$accountName' already exists with ID $accountId." -ForegroundColor Green
				
				$accountSqlFile = Join-Path $accountFolder.FullName "_account.sql"
				if (Test-Path $accountSqlFile) {
					# Read the content of the SQL file as a single string
					$sqlContent = Get-Content -Path $accountSqlFile -Raw
					# Extract values inside parentheses
					$pattern = "(?<=\().*?(?=\))"
					$matches = [regex]::Matches($sqlContent, $pattern)
					
					$match = $matches[0].Value
					# Split the row into individual values
					$values = $match -split ","
					#get the old ID
					$oldGuid = $values[0]
					
					#add to list
					$guidMappingAccounts.Add([pscustomobject]@{
						AccountName = $accountName
						OldGuid       = $oldGuid
						NewGuid       = $accountId
					}) | Out-Null
				}
####################################################################
			} else {
				Write-Host "Account '$accountName' does not exist. Creating it..." -ForegroundColor Cyan
				$accountSqlFile = Join-Path $accountFolder.FullName "_account.sql"
				if (Test-Path $accountSqlFile) {
					
					# Get the maximum GUID from the characters table
					$maxIDResult = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT MAX(id) AS MaxID FROM account" 3>$null		#supress warnings when no results found
					
					# Extract the numeric value from the DataRow
					if ($maxIDResult -and $maxIDResult.MaxID -ne [DBNull]::Value) {
						$MaxID = $maxIDResult.MaxID
					} else {
						# If no records found, set maxGuid to 0
						$MaxID = 0
					}
					
					# Calculate the new GUID as the next sequential number
					# $newID = $MaxID + 1
					$accountId = $MaxID + 1
####################################################################
					# Read the content of the SQL file as a single string
					$sqlContent = Get-Content -Path $accountSqlFile -Raw
					
					# Remove all occurrences of "_binary " 
					# Edit: required so MySQL stores the exact bytes
					# $sqlContent = $sqlContent -replace "_binary ", ""
					
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
						
						#get the old ID
						$oldGuid = $values[0]
						
						# Modify the first value with the incrementing GUID
						$values[0] = $accountId
						
						# Check there's less than 25 columns add another for the Flags column (column 18)
						if ($values.Count -lt 25) {
							# Insert integer 0 at index 17 (making it the new 18th element)
							$values = $values[0..16] + 0 + $values[17..($values.Count - 1)]
						}
						# Recreate the modified row and store it
						$modifiedRow = "(" + ($values -join ",") + ")"
						$modifiedRows += $modifiedRow
					}
					
					# Join the modified rows into the final SQL query
					$modifiedSqlQuery = "INSERT INTO account VALUES " + ($modifiedRows -join ",") + ";"
					
					#Execute the query
					Execute-Query -query "$modifiedSqlQuery" -tablename "account" -ConnectionName "AuthConn"
					
					#add to list
					$guidMappingAccounts.Add([pscustomobject]@{
						AccountName = $accountName
						OldGuid       = $oldGuid
						NewGuid       = $accountId
					}) | Out-Null
####################################################################
					$accountAccessSqlFile = Join-Path $accountFolder.FullName "_account_access.sql"
					if (Test-Path $accountAccessSqlFile) {
						if ((Get-Item $accountAccessSqlFile).Length -gt 0) {
							# Read the content of the SQL file as a single string
							$sqlContent = Get-Content -Path $accountAccessSqlFile -Raw
							
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
								$values[0] = $accountId
								
								# Recreate the modified row and store it
								$modifiedRow = "(" + ($values -join ",") + ")"
								$modifiedRows += $modifiedRow
							}
							
							# Join the modified rows into the final SQL query
							$modifiedSqlQuery = "INSERT INTO account_access VALUES " + ($modifiedRows -join ",") + ";"
							
							#Execute the query
							Execute-Query -query "$modifiedSqlQuery" -tablename "account_access" -ConnectionName "AuthConn"
						}
					}
					Write-Host "Account '$accountName' created with ID $accountId." -ForegroundColor Green
####################################################################
				} else {
					Write-Host "Could not find '_account.sql' for account '$accountName'. Skipping." -ForegroundColor Red
					continue
				}
				
			}
####################################################################
			$characterFolders = Get-ChildItem -Path $accountFolder.FullName -Directory
			if ($characterFolders.Count -eq 0) {
				Write-Host "No character backups found for account '$accountName'." -ForegroundColor Yellow
				continue
			}

			Write-Host "Found $($characterFolders.Count) character backups for account '$accountName'." -ForegroundColor Green
			foreach ($characterFolder in $characterFolders) {
				$CharacterFolderList += $characterFolder	#add to folder list
				Restore-Character -account $accountName -accountID $accountId -BackupDir $characterFolder
				# Write-Host "`nTotal mappings collected: $($guidMappingCharacters.Count)" -ForegroundColor Green
				# $guidMappingCharacters | Format-Table -AutoSize
			}
		}
####################################################################
		#restore tables with two or more characters e.g. character_social
		# Write-Host "`nRestoring friend lists..." -ForegroundColor Cyan
		# foreach ($characterFolder in $CharacterFolderList) {
			# Restore-Multiple-Character-Tables -account $accountName -accountID $accountId -BackupDir $characterFolder
		# }
		
	    Write-Host "`nRestoring friend lists..." -ForegroundColor Cyan
		$totalChars = $CharacterFolderList.Count
		$charCounter = 0
		
		foreach ($characterFolder in $CharacterFolderList) {
			$charCounter++
			
			$percent = [int](($charCounter / $totalChars) * 100)
			Write-Progress -Activity "Restoring Characters" -Status "Processing $charCounter of $totalChars" -PercentComplete $percent
		
			Restore-Multiple-Character-Tables -account $accountName -accountID $accountId -BackupDir $characterFolder
		
			if ($charCounter % 100 -eq 0) {
				Write-Host "Processed $charCounter characters so far..." -ForegroundColor Cyan
			}
		}
####################################################################
		# Convert mappings to json and dump them
		$Json = $guidMappingAccounts | ConvertTo-Json -Depth 3
		$Json | Out-File "$($chosenFolder)/Accounts.json" -Encoding UTF8 -Force
		
		$Json = $guidMappingCharacters | ConvertTo-Json -Depth 3
		$Json | Out-File "$($chosenFolder)/Characters.json" -Encoding UTF8 -Force
		
		$Json = $guidMappingpPets | ConvertTo-Json -Depth 3
		$Json | Out-File "$($chosenFolder)/Pets.json" -Encoding UTF8 -Force
		
		$Json = $guidMappingItems | ConvertTo-Json -Depth 3
		$Json | Out-File "$($chosenFolder)/Items.json" -Encoding UTF8 -Force
####################################################################
		$stopwatch.Stop()
		Write-Host "`nAll accounts and characters restored in $($stopwatch.Elapsed.TotalSeconds) seconds." -ForegroundColor Green
####################################################################
	} catch {
		Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Close-SqlConnection -ConnectionName "AuthConn"
		Close-SqlConnection -ConnectionName "CharConn"
		[console]::beep()
	}
}
#################################################################
#endregion
#################################################################
