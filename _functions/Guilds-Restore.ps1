#################################################################
#region Restore-Guilds
#################################################################
function Restore-Guild {
	param (
		[string]$character,
		[int]$characterID,
		[string]$GuildName,
		[string]$BackupDir
	)
	
	#Check if guild exists
	$Query = "SELECT guildid FROM guild WHERE name = '$GuildName';"
	$ValueColumn = "guildid"
	$ConnectionName = "CharConn"
	$result = Check-Value-in-DB -Query $Query -ValueColumn $ValueColumn -ConnectionName $ConnectionName
	if ($result) {
		Write-Host "Guild $GuildName already exists in database. Skipping..." -ForegroundColor Yellow
		return
	}
############## PROCESS GUILD.SQL - alter guildid[0] and leaderguid[2]
	# Write-Host "folder is $BackupDir"
	$sqlFilePath = "$BackupDir\guild.sql"
	if (Test-Path -Path $sqlFilePath) {
		$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
		
		Write-Host "Restoring guild $GuildName..." -ForegroundColor Cyan
		# Write-Host "The file exists: $sqlFilePath"
#################################################################
		# Get the maximum guildid from the characters table
		$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(guildid) AS MaxGuildID FROM guild" 3>$null		#supress warnings when no results found
		
		# Extract the numeric value from the DataRow and check for DBNull
		if ($maxGuidResult -and $maxGuidResult.MaxGuildID -ne [DBNull]::Value) {
			$maxGuid = $maxGuidResult.MaxGuildID
		} else {
			# If no records found or value is DBNull, set maxGuid to 0
			$maxGuid = 0
		}
					
		#assign new guid to highest value in column guid + 1,
		$newGuildID = $maxGuid + 1
############################ PROCESS GUILD_MEMBERS.JSON
		Write-Host "Processing guild member data..." -ForegroundColor Cyan
		$guidMapping = @{}
		$guildMembersFile = "$BackupDir\guild_members.json"
		if (Test-Path $guildMembersFile) {
			$guildMembersJson = Get-Content $guildMembersFile | ConvertFrom-Json
			foreach ($property in $guildMembersJson.psobject.Properties) {
				$oldGuid = $property.Name
				$characterName = $property.Value
				
				# check if character exists first
				$Query = "SELECT guid FROM characters WHERE name = '$characterName';"
				$ValueColumn = "guid"
				$ConnectionName = "CharConn"
				$newCharGuid = Check-Value-in-DB -Query $Query -ValueColumn $ValueColumn -ConnectionName $ConnectionName
				if ($newCharGuid) {
					$guidMapping[$oldGuid] = $newCharGuid
					Write-Host "Character '$characterName' (old ID: $($oldGuid), new ID: $($newCharGuid)) found on the target server database. Adding member..." -ForegroundColor Green
				} else {
					Write-Host "Character '$characterName' (old ID: $($oldGuid)) not found on the target server database. Skipping member..." -ForegroundColor Yellow
				}
			}
		}
#################################################################
		$pattern = "(?<=\().*?(?=\))"
############################# PROCESS GUILD.SQL
		# guild = guildid[0], PlayerGuid[2]
		$sqlContent = Get-Content -Path $sqlFilePath -Raw
		
		# 1. Clean the SQL content to remove the 'INSERT INTO...' header and the final ');'
		# This handles the case where there are parentheses inside the text
		$innerValues = $sqlContent.Trim()
		$innerValues = [regex]::Replace($innerValues, "(?i)INSERT INTO `?guild`? VALUES \s*\(", "")
		$innerValues = [regex]::Replace($innerValues, "\);$", "")
		
		# 2. Since we only need to change the first few IDs, we don't need to split the whole thing.
		# We split by the first few commas only to preserve the message text.
		$parts = $innerValues -split ",", 4  # Split into: 0:guildid, 1:name, 2:leaderguid, 3:the_rest
		
		#get the old ID
		$oldGuid = $parts[0]
		#add to list
		$guidMappingGuilds.Add([pscustomobject]@{
			GuildName	= $GuildName
			OldGuildGuid	= $oldGuid
			NewGuildGuid	= $newGuildID
			GuildLeaderID	= $characterID
		}) | Out-Null
					
		$parts[0] = $newGuildID
		$parts[2] = $characterID
		
		# 3. Reconstruct the row
		$modifiedRow = "(" + ($parts -join ",") + ")"
		$modifiedSqlQuery = "INSERT INTO `guild` VALUES $modifiedRow;"
		
		# Execute
		Execute-Query -query $modifiedSqlQuery -tablename "guild" -ConnectionName "CharConn"
############################## PROCESS GUILD_RANK, GUILD_BANK_RIGHT, GUILD_BANK_TAB
		# guild_bank_right, guild_bank_tab, guild_rank = guildid[0]
		$tables = @(
			@("guild_bank_right", 0, $newGuildID),
			@("guild_bank_tab", 0, $newGuildID),
			@("guild_rank", 0, $newGuildID)
		)
		foreach ($entry in $tables) {
			# Extract the table name and the column number
			$table = $entry[0]
			$columnIndex = $entry[1]
			$columnIndexValue = $entry[2]
			
			$sqlFilePath = "$BackupDir\$table.sql"
			if (Test-Path $sqlFilePath) {
				$sqlContent = Get-Content -Path $sqlFilePath -Raw
				$matches = [regex]::Matches($sqlContent, $pattern)
				$modifiedRows = @()
				foreach ($match in $matches) {
					$values = $match.Value -split ","
					$values[$columnIndex] = $columnIndexValue
					$modifiedRows += "(" + ($values -join ",") + ")"
				}
				$modifiedSqlQuery = "INSERT IGNORE INTO $table VALUES " + ($modifiedRows -join ",") + ";"
				# Output the modified SQL to verify
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				Execute-Query -query $modifiedSqlQuery -tablename $table -ConnectionName "CharConn"
			}
		}
############################### PROCESS GUILD_MEMBER.SQL
		$sqlFilePath = "$BackupDir\guild_member.sql"
		if (Test-Path $sqlFilePath) {
			$sqlContent = Get-Content -Path $sqlFilePath -Raw
			
			# 1. Strip SQL header and trailing characters
			$justValues = [regex]::Replace($sqlContent.Trim(), "(?i)INSERT INTO `?guild_member`? VALUES \s*\(", "")
			$justValues = $justValues.TrimEnd(";").TrimEnd(")")
		
			# 2. Split by the actual row separator "),(" to avoid breaking on commas inside notes
			$rows = [regex]::Split($justValues, "\)\s*,\s*\(")
		
			$modifiedRows = @()
			foreach ($row in $rows) {
				# 3. ONLY split the first 3 columns (guildid, guid, rank)
				# The 4th part will contain ALL the remaining text (PNote and OffNote)
				$parts = $row -split ",", 4
		
				if ($parts.Count -ge 2) {
					$oldMemberGuid = $parts[1].Trim()
		
					if ($guidMapping.ContainsKey($oldMemberGuid)) {
						$parts[0] = $newGuildID
						$parts[1] = $guidMapping[$oldMemberGuid]
						
						# Re-wrap this specific row and add it to our list
						$modifiedRows += "(" + ($parts -join ",") + ")"
					}
				}
			}
		
			if ($modifiedRows.Count -gt 0) {
				# Clean up target table for this guild
				Invoke-SqlUpdate -ConnectionName "CharConn" -Query "DELETE FROM guild_member WHERE guildid = $newGuildID"
		
				# Construct and execute final query
				$finalQuery = "INSERT INTO `guild_member` VALUES " + ($modifiedRows -join ",") + ";"
				
				# FINAL SAFETY: If the original file had escaped quotes like \', 
				# MySQL might need them. But usually, just sending the string works.
				Execute-Query -query $finalQuery -tablename "guild_member" -ConnectionName "CharConn"
			}
		}
############################# PROCESS GUILD_BANK_EVENTLOG.SQL
		# guild_eventlog = guildid[0], PlayerGuid[3]
		$sqlFilePath = "$BackupDir\guild_bank_eventlog.sql"
		if (Test-Path $sqlFilePath) {
			$sqlContent = Get-Content -Path $sqlFilePath -Raw
			$matches = [regex]::Matches($sqlContent, $pattern)
			$modifiedRows = @()
			foreach ($match in $matches) {
				$values = $match.Value -split ","
				$oldPlayerGuid = $values[4]
				if ($guidMapping.ContainsKey($oldPlayerGuid)) {
					$values[0] = $newGuildID
					$values[4] = $guidMapping[$oldPlayerGuid]
					$modifiedRows += "(" + ($values -join ",") + ")"
				#else set it as guild leader ID
				} else {
					$values[0] = $newGuildID
					$values[4] = $characterID
					$modifiedRows += "(" + ($values -join ",") + ")"
				}
			}
			# if ($modifiedRows.Count -gt 0) {
			$modifiedSqlQuery = "INSERT IGNORE INTO guild_bank_eventlog VALUES " + ($modifiedRows -join ",") + ";"
			# Output the modified SQL to verify
			# Write-Host "`nModified SQL: $modifiedSqlQuery"
			Execute-Query -query $modifiedSqlQuery -tablename "guild_bank_eventlog" -ConnectionName "CharConn"
			# }
		}
############################# PROCESS GUILD_EVENTLOG.SQL
		# guild_bank_eventlog - guildid[0], PlayerGuid[3], PlayerGuid[4]
		$sqlFilePath = "$BackupDir\guild_eventlog.sql"
		if (Test-Path $sqlFilePath) {
			$sqlContent = Get-Content -Path $sqlFilePath -Raw
			$matches = [regex]::Matches($sqlContent, $pattern)
			$modifiedRows = @()
			foreach ($match in $matches) {
				$values = $match.Value -split ","
				$oldPlayerGuid1 = $values[3]
				$oldPlayerGuid2 = $values[4]
				$guid1Exists = $guidMapping.ContainsKey($oldPlayerGuid1)
				$guid2Exists = $guidMapping.ContainsKey($oldPlayerGuid2)

				if ($guid1Exists -or $guid2Exists) {
					$values[0] = $newGuildID
					if ($guid1Exists) {
						$values[3] = $guidMapping[$oldPlayerGuid1]
					#else set it as guild leader ID
					} else {
						$values[3] = $characterID
					}
					
					if ($guid2Exists) {
						$values[4] = $guidMapping[$oldPlayerGuid2]
					#else set it as guild leader ID
					} else {
						$values[4] = $characterID
					}
					
					$modifiedRows += "(" + ($values -join ",") + ")"
				}
			}
			# if ($modifiedRows.Count -gt 0) {
			$modifiedSqlQuery = "INSERT IGNORE INTO guild_eventlog VALUES " + ($modifiedRows -join ",") + ";"
			# Output the modified SQL to verify
			# Write-Host "`nModified SQL: $modifiedSqlQuery"
			Execute-Query -query $modifiedSqlQuery -tablename "guild_eventlog" -ConnectionName "CharConn"
			# }
		}
		
############################# PROCESS GUILD_MEMBER_WITHDRAW.SQL
		$sqlFilePath = "$BackupDir\guild_member_withdraw.sql"
		if (Test-Path $sqlFilePath) {
			$sqlContent = Get-Content -Path $sqlFilePath -Raw
			$matches = [regex]::Matches($sqlContent, $pattern)
			$modifiedRows = @()
			foreach ($match in $matches) {
				$values = $match.Value -split ","
				$oldMemberGuid = $values[0]
				if ($guidMapping.ContainsKey($oldMemberGuid)) {
					$values[0] = $guidMapping[$oldMemberGuid]
					$modifiedRows += "(" + ($values -join ",") + ")"
					
					# if ($modifiedRows.Count -gt 0) {
					$modifiedSqlQuery = "INSERT IGNORE INTO guild_member_withdraw VALUES " + ($modifiedRows -join ",") + ";"
					# Output the modified SQL to verify
					# Write-Host "`nModified SQL: $modifiedSqlQuery"
					Execute-Query -query $modifiedSqlQuery -tablename "guild_member_withdraw" -ConnectionName "CharConn"
					# }
				#else set it as guild leader ID
				} else {
					$values[0] = $characterID
					$modifiedRows += "(" + ($values -join ",") + ")"
					
					# if ($modifiedRows.Count -gt 0) {
					$modifiedSqlQuery = "INSERT IGNORE INTO guild_member_withdraw VALUES " + ($modifiedRows -join ",") + ";"
					# Output the modified SQL to verify
					# Write-Host "`nModified SQL: $modifiedSqlQuery"
					Execute-Query -query $modifiedSqlQuery -tablename "guild_member_withdraw" -ConnectionName "CharConn"
					# }
				}
			}
		}
############################ PROCESS ITEM_INSTANCE - alter guid[0] taking into account existing items
		$sqlFilePath = "$BackupDir\item_instance.sql"
		
		if (Test-Path -Path $sqlFilePath) {
			if (Table-Exists -TableName "item_instance" -ConnectionName "CharConn") {
				Write-Host "Processing guild bank items..." -ForegroundColor Cyan
				# Get the maximum GUID from the characters table
				$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(guid) AS MaxGuid FROM item_instance" 3>$null		#supress warnings when no results found
				
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
					$guidMappingItems.Add([pscustomobject]@{
						OldGuid       = $oldGuid
						NewGuid       = $newItemGuidValue
					}) | Out-Null
					
					# Modify the third value with the new GUID
					$values[2] = $newGuildID
					
					# Recreate the modified row and store it
					$modifiedRow = "(" + ($values -join ",") + ")"
					$modifiedRows += $modifiedRow
				}
			
				# Join the modified rows into the final SQL query
				$modifiedSqlQuery = "INSERT INTO item_instance VALUES " + ($modifiedRows -join ",") + ";"
				
				# Output the array to verify
				# Write-Host $guidMappingItems
				
				# Output the modified SQL to verify
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				
				#Execute the query
				Execute-Query -query $modifiedSqlQuery -tablename "item_instance" -ConnectionName "CharConn"
				
################################ PROCESS GUILD_BANK_ITEM - alter guidid[0] and item_guid[3]
				$sqlFilePath = "$BackupDir\guild_bank_item.sql"
				
				if (Test-Path -Path $sqlFilePath) {
					if (Table-Exists -TableName "guild_bank_item" -ConnectionName "CharConn") {
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
							
############################## THIS IS FOR ITEM_GUID
							# Get the current value in the target column (adjust for 0-based index)
							$currentValue = $values[3]
							
							# Check if the current value matches an old GUID in the mapping
							$matchingGuid = $guidMappingItems | Where-Object { $_.OldGuid -eq $currentValue }
							
							# If a match is found, replace the old GUID with the new GUID
							if ($matchingGuid) {
								$values[3] = $matchingGuid.NewGuid
							}
############################## THIS IS FOR GUILD GUID
							$values[0] = $newGuildID
#################################################################
							# Recreate the modified row and store it
							$modifiedRow = "(" + ($values -join ",") + ")"
							$modifiedRows += $modifiedRow
						}
					
						# Join the modified rows into the final SQL query
						$modifiedSqlQuery = "INSERT INTO guild_bank_item VALUES " + ($modifiedRows -join ",") + ";"
				
						# Output the modified SQL to verify
						# Write-Host "`nModified SQL: $modifiedSqlQuery"
						
						#Execute the query
						Execute-Query -query $modifiedSqlQuery -tablename "guild_bank_item" -ConnectionName "CharConn"
					} else {
						Write-Host "Table 'guild_bank_item' does not exist, skipping restore for this table." -ForegroundColor Red
					}
				}
#################################################################
				} else {
					Write-Host "Table 'item_instance' does not exist, skipping restore for this table." -ForegroundColor Red
				}
			}
############################## PROCESS GUILD_HOUSE - alter id[0] taking into account existing items and guild[1]
		$sqlFilePath = "$BackupDir\guild_house.sql"
		
		if (Test-Path -Path $sqlFilePath) {
			if (Table-Exists -TableName "guild_house" -ConnectionName "CharConn") {
				Write-Host "Processing guild house data..." -ForegroundColor Cyan
				# Get the maximum GUID from the characters table
				$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(id) AS MaxGuid FROM guild_house" 3>$null		#supress warnings when no results found
				
				# Extract the numeric value from the DataRow and check for DBNull
				if ($maxGuidResult -and $maxGuidResult.MaxGuid -ne [DBNull]::Value) {
					$maxGuid = $maxGuidResult.MaxGuid
				} else {
					# If no records found or value is DBNull, set maxGuid to 23
					$maxGuid = 23
				}
				
				#assign new guid to highest value in column guid + 24
				$newRowID = $maxGuid + 1
				
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
					
					# Modify the first value with the incrementing GUID
					$newRowIDValue = $newRowID + $i
					$values[0] = $newRowIDValue
					
					# Modify the second row value with the new GUID
					$values[1] = $newGuildID
					
					# Recreate the modified row and store it
					$modifiedRow = "(" + ($values -join ",") + ")"
					$modifiedRows += $modifiedRow
				}
			
				# Join the modified rows into the final SQL query
				$modifiedSqlQuery = "INSERT INTO guild_house VALUES " + ($modifiedRows -join ",") + ";"
				
				# Output the modified SQL to verify
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				
				#Execute the query
				Execute-Query -query $modifiedSqlQuery -tablename "guild_house" -ConnectionName "CharConn"
############################## PROCESS CREATURE (this is for guild house NPCs) - alter guid[0] taking into account existing creatures
				$sqlFilePath = "$BackupDir\creature.sql"
				
				if (Test-Path -Path $sqlFilePath) {
					if (Table-Exists -TableName "creature" -ConnectionName "WorldConn") {
						# Get the maximum GUID from the characters table
						$maxGuidResult = Invoke-SqlQuery -ConnectionName "WorldConn" -Query "SELECT MAX(guid) AS MaxGuid FROM creature" 3>$null		#supress warnings when no results found
						
						# Extract the numeric value from the DataRow and check for DBNull
						if ($maxGuidResult -and $maxGuidResult.MaxGuid -ne [DBNull]::Value) {
							$maxGuid = $maxGuidResult.MaxGuid
						} else {
							# If no records found or value is DBNull, set maxGuid to 0
							$maxGuid = 0
						}
						
						#assign new guid to highest value in column guid + 1
						$newCreatureGuid = $maxGuid + 1
						
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
							
							# Modify the first value with the incrementing GUID
							$newCreatureGuidValue = $newCreatureGuid + $i
							$values[0] = $newCreatureGuidValue
						
							# Recreate the modified row and store it
							$modifiedRow = "(" + ($values -join ",") + ")"
							$modifiedRows += $modifiedRow
						}
					
						# Join the modified rows into the final SQL query
						$modifiedSqlQuery = "INSERT INTO creature VALUES " + ($modifiedRows -join ",") + ";"
						
						# Output the modified SQL to verify
						# Write-Host "`nModified SQL: $modifiedSqlQuery"
						
						#Execute the query
						Execute-Query -query $modifiedSqlQuery -tablename "creature" -ConnectionName "WorldConn"
					} else {
						Write-Host "Table 'creature' does not exist, skipping restore for this table." -ForegroundColor Red
					}
				}
#################################################################
			} else {
				Write-Host "Table 'guild_house' does not exist, skipping restore for this table." -ForegroundColor Red
			}
		}
#################################################################
		$stopwatch.Stop()
		Write-Host "Successfully imported guild $GuildName in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
	} else {
		Write-Host "No guild file found. Aborting..." -ForegroundColor Red
	}
#################################################################
}
#################################################################
function Restore-Guild-Main {
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "AuthConn"
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "CharConn"
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseWorld -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "WorldConn"

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
	Write-Host "`nPlease select a guild by typing the corresponding number:`n" -ForegroundColor Cyan
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
		
		# $GuildName = ($selectedFolder -split " - ")[0]
		$GuildName = ($selectedFolder -split " - ")[0] -replace '\s*\(.*?\)', '' 
		Write-Host "`nYou selected: $GuildName" -ForegroundColor Cyan
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
			Write-Host "`nThe script requires a character name to transfer the guild $GuildName to (case sensitive)." -ForegroundColor Cyan
			# Prompt for account name
			$characterNameToSearch = Read-Host "Enter character name"
			
			# check if character exists first
			$Query = "SELECT guid FROM characters WHERE name = $characterNameToSearch;"
			$ValueColumn = "guid"
			$ConnectionName = "CharConn"
			$characterGuid = Check-Value-in-DB -Query $Query -ValueColumn $ValueColumn -ConnectionName $ConnectionName
			if ($characterGuid){
				#check if character already is a member of a guild
				$Query = "SELECT COUNT(*) as count FROM guild_member WHERE guid = $characterGuid;"
				$ValueColumn = "count"
				$ConnectionName = "CharConn"
				$FoundRow = Check-Value-in-DB -Query $Query -ValueColumn $ValueColumn -ConnectionName $ConnectionName
				if ($FoundRow){
					Write-Host "Character $characterNameToSearch already is a member of a guild. Try again." -ForegroundColor Red
				} else {
					Restore-Guild -character $characterNameToSearch -characterID $characterGuid -GuildName $GuildName -BackupDir $selectedFolder 
				}
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
				
				Write-Host "`nThe script requires a character name to transfer the guild $GuildName to." -ForegroundColor Cyan
				# Prompt for account name
				$characterNameToSearch = Read-Host "Enter character name"
				
				# check if character exists first
				$Query = "SELECT guid FROM characters WHERE name = $characterNameToSearch;"
				$ValueColumn = "guid"
				$ConnectionName = "CharConn"
				$characterGuid = Check-Value-in-DB -Query $Query -ValueColumn $ValueColumn -ConnectionName $ConnectionName
				if ($characterGuid){
					Restore-Guild -character $characterNameToSearch -characterID $characterGuid -GuildName $GuildName -BackupDir $folder
				} else {
					Write-Host "Character name not found in database. Try again." -ForegroundColor Red
				}
			}
		}
#################################################################
	# Close all connections
	Close-SqlConnection -ConnectionName "AuthConn"
	Close-SqlConnection -ConnectionName "CharConn"
	Close-SqlConnection -ConnectionName "WorldConn"
}
#################################################################
function Restore-All-Guilds-Main {
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "CharConn"
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseWorld -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "WorldConn"
####################################################################
	try {
		# Get all backup folders under full_backups
		$backupRoot = "$GuildBackupDir\full_backups"
		
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
		
		$guildFolders = Get-ChildItem -Path $chosenFolder -Directory
		if ($guildFolders.Count -eq 0) {
			Write-Host "No guild backups found in '$GuildBackupDir'." -ForegroundColor Yellow
			return
		}

		Write-Host "Found $($guildFolders.Count) guild backups. Starting restore process..." -ForegroundColor Cyan
		$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
####################################################################
		#clear lists
		$guidMappingItems.Clear()
		$guidMappingGuilds.Clear()
####################################################################
		foreach ($folder in $guildFolders) {
			$folderName = $folder.Name
			$guildName = ($folderName -split " - ")[0] -replace '\s*\(.*?\)', '' 
			$leaderName = ($folderName -split " - ")[1]

			Write-Host "`nStarting restoring guild: $guildName, Leader: $leaderName" -ForegroundColor Cyan

			$characterGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT guid FROM characters WHERE name = @name" -Parameters @{ name = $leaderName } 3>$null		#supress warnings when no results found
			if ($characterGuidResult) {
				Write-Host "Found guild leader in database: $leaderName" -ForegroundColor Green
				$characterGuid = $characterGuidResult.guid
				$isGuildMember = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT guid FROM guild_member WHERE guid = @guid" -Parameters @{ guid = $characterGuid } 3>$null		#supress warnings when no results found
				if ($isGuildMember) {
					Write-Host "Character '$leaderName' is already in a guild. Skipping restore for guild '$guildName'." -ForegroundColor Yellow
					continue
				}
				Restore-Guild -character $leaderName -characterID $characterGuid -GuildName $guildName -BackupDir $folder
			} else {
				Write-Host "Leader character '$leaderName' not found for guild '$guildName'. Skipping restore." -ForegroundColor Red
			}
		}
#################################################################### 
		# Convert mappings to json and dump them
		$Json = $guidMappingItems | ConvertTo-Json -Depth 3
		$Json | Out-File "$($chosenFolder)/Items.json" -Encoding UTF8
		
		$Json = $guidMappingGuilds | ConvertTo-Json -Depth 3
		$Json | Out-File "$($chosenFolder)/Guilds.json" -Encoding UTF8
####################################################################
		$stopwatch.Stop()
		Write-Host "`nAll guilds restored in $($stopwatch.Elapsed.TotalSeconds) seconds." -ForegroundColor Green
	} catch {
		Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Close-SqlConnection -ConnectionName "CharConn"
		Close-SqlConnection -ConnectionName "WorldConn"
		[console]::beep()
	}
}
#################################################################
#endregion
#################################################################