
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
	$sqlFilePath = "$GuildBackupDir\$folder\guild.sql"
	if (Test-Path -Path $sqlFilePath) {
		$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
		
		Write-Host "`nRestoring guild $GuildName..." -ForegroundColor Yellow
		# Write-Host "The file exists: $sqlFilePath"
		
		# Get the maximum GUID from the characters table
		$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(guildid) AS MaxGuildID FROM guild"
		
		# Extract the numeric value from the DataRow and check for DBNull
		if ($maxGuidResult -and $maxGuidResult.MaxGuildID -ne [DBNull]::Value) {
			$maxGuid = $maxGuidResult.MaxGuildID
		} else {
			# If no records found or value is DBNull, set maxGuid to 0
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
		Execute-Query -query $modifiedSqlQuery -tablename "guild_member" -ConnectionName "CharConn"
		
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
			$sqlFilePath = "$GuildBackupDir\$folder\$table.sql"
			
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
				Execute-Query -query $modifiedSqlQuery -tablename $table -ConnectionName "CharConn"
			}
		}	
############################ PROCESS ITEM_INSTANCE - alter guid[0] taking into account existing items
			$sqlFilePath = "$GuildBackupDir\$folder\item_instance.sql"
			
			if (Test-Path -Path $sqlFilePath) {
				# Get the maximum GUID from the characters table
				$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(guid) AS MaxGuid FROM item_instance"
				
				# Extract the numeric value from the DataRow and check for DBNull
				if ($maxGuidResult -and $maxGuidResult.MaxGuid -ne [DBNull]::Value) {
					$maxGuid = $maxGuidResult.MaxGuid
				} else {
					# If no records found or value is DBNull, set maxGuid to 0
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
				Execute-Query -query $modifiedSqlQuery -tablename "item_instance" -ConnectionName "CharConn"
				
############################ PROCESS GUILD_BANK_ITEM - alter guidid[0] and item_guid[3]
				$sqlFilePath = "$GuildBackupDir\$folder\guild_bank_item.sql"
				
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
					Execute-Query -query $modifiedSqlQuery -tablename "guild_bank_item" -ConnectionName "CharConn"
				}
########################################################
			}
############################
			$stopwatch.Stop()
			Write-Host "`nSuccessfully imported guild $GuildName in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
		} else {
			Write-Host "No guild file found. Aborting..." -ForegroundColor Red
		}
#################################################
	}
#################################################



################################
function Restore-Guild-Main {
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "AuthConn"
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "CharConn"

################ MENU
	$selectedGuild = $false
	$selectedGuildAll = $false
	# Get the account folders (like rndbot3 and test1)
	$accountFolders = Get-ChildItem -Path $GuildBackupDir -Directory
	
	# Initialize an array to hold all subfolders
	$guildFolders = @()
	
	# Loop through each account folder to get its subfolders
	foreach ($accountFolder in $accountFolders) {
		$guildFolders += $accountFolder
	}
	
	# Check if any folders were found
	if ($guildFolders.Count -eq 0) {
		Write-Host "No guilds found in the directory '$GuildBackupDir'." -ForegroundColor Red
		exit
	}
	
	# Display the menu with formatted output
	Write-Host "`nPlease select a guild by typing the corresponding number:`n" -ForegroundColor Yellow
	for ($i = 0; $i -lt $guildFolders.Count; $i++) {
		# $accountFolder = $guildFolders[$i].Parent.Name
		$folderName = $guildFolders[$i].Name
		Write-Host "$($i + 1). $folderName" -ForegroundColor Green
	}
	Write-Host "$($guildFolders.Count + 1). All guilds in list" -ForegroundColor Green
	Write-Host "$($guildFolders.Count + 2). Exit" -ForegroundColor Green
	
	# Prompt the user to select a folder or exit
	$selection = Read-Host "`nEnter your choice (1-$($guildFolders.Count + 2))"
	
	# 1
	if ($selection -ge 1 -and $selection -lt ($guildFolders.Count + 1).ToString()) {
		$selectedGuild = $true
		
		$selectedFolder = $guildFolders[$selection - 1].Name
		
		$GuildName = ($selectedFolder -split " - ")[0]
		Write-Host "`nYou selected: $GuildName" -ForegroundColor Yellow
	}
	# All
	elseif ($selection -eq ($guildFolders.Count + 1).ToString()) {
		$selectedGuildAll = $true
	}
	# Validate the input and handle the exit option
	elseif ($selection -eq ($guildFolders.Count + 2).ToString()) {
		Write-Host "Exiting the script." -ForegroundColor Yellow
		exit
	}
	#invalid
	else {
		Write-Host "`nInvalid selection." -ForegroundColor Red
	}
################################################
################ 	CHARACTER(S) SELECTED		
########################## 1
		if ($selectedGuild -eq $true) {
			Write-Host "`nThe script requires a character name to transfer the guild $GuildName to (case sensitive)." -ForegroundColor Yellow
			# Prompt for account name
			$characterNameToSearch = Read-Host "Enter character name"
			
			$characterGuid = Check-Character -characterNameToSearch $characterNameToSearch
			
			if ($characterGuid){
				Restore-Guild -folder $selectedFolder -character $characterNameToSearch -characterID $characterGuid -GuildName $GuildName
			} else {
				Write-Host "Character name not found in database. Try again." -ForegroundColor Red
			}
		}
########################### All
		elseif ($selectedGuildAll -eq $true) {
			Write-Host "`nImporting up all guilds from list."
			
			foreach ($folder in $guildFolders) {
			$selectedFolder = $folder.Name
			$GuildName = ($selectedFolder -split " - ")[0]
			
			Write-Host "`nThe script requires a character name to transfer the guild $GuildName to." -ForegroundColor Yellow
			# Prompt for account name
			$characterNameToSearch = Read-Host "Enter character name"
			
			$characterGuid = Check-Character -characterNameToSearch $characterNameToSearch
	
			if ($characterGuid){
				Restore-Guild -folder $folder.Name -character $characterNameToSearch -characterID $characterGuid -GuildName $GuildName
			} else {
				Write-Host "Character name not found in database. Try again." -ForegroundColor Red
			}
			}
		}
################################################
	# Close all connections
	Close-SqlConnection -ConnectionName "AuthConn"
	Close-SqlConnection -ConnectionName "CharConn"
	# Close-SqlConnection -ConnectionName "WorldConn"
}
###################################################


#########################################################
#########################################################

