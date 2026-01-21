
#################################################################
# Initialize the guidMapping as an ArrayList for dynamic addition
$guidMappingAccounts = [System.Collections.ArrayList]::new()
$guidMappingCharacters = [System.Collections.ArrayList]::new()
$guidMappingpPets = [System.Collections.ArrayList]::new()
$guidMappingItems = [System.Collections.ArrayList]::new()
$guidMappingGuilds = [System.Collections.ArrayList]::new()
#################################################################
#region utility-functions
function ConvertToGoldSilverCopper {
	param (
		[int]$MoneyAmount
	)
	
	if ($MoneyAmount -gt 0) {
		$gold = [math]::Floor($MoneyAmount / 10000)
		$remainingAfterGold = $MoneyAmount % 10000
		$silver = [math]::Floor($remainingAfterGold / 100)
		$copper = $remainingAfterGold % 100
		
		$result = ""
		if ($gold -gt 0) { $result += "$($gold)g" }
		if ($silver -gt 0) {
			if ($result -ne "") { $result += ", " }
			$result += "$($silver)s"
		}
		if ($copper -gt 0) {
			if ($result -ne "") {
				if ($silver -gt 0) { $result += " and " }
				else { $result += ", " }
			}
			$result += "$($copper)c"
		}
		return $result
	}
	else { return 0 }
}
#################################################################
function Backup-TableData {
	param (
		[string]$tableName,
		[string]$tableNameFile,
		[string]$columnName,
		[int]$value,
		[string]$SourceDatabase,
		[string]$BackupDir
	)

	# $backupDirFull = "$CharacterBackupDir\$AccountName\$characterName ($CurrentDate) - $Race $Class $Gender LV$Level"
	if (-not (Test-Path $BackupDir)) {
		New-Item -Path $BackupDir -ItemType Directory | Out-Null
	}
	
	$backupFile = "$BackupDir\$tableNameFile.sql"
	# Write-Host "File: $BackupDir\$tableNameFile.sql" -ForegroundColor Yellow
	$whereClause = "$columnName=$value"
	
	$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --hex-blob --where=`"$whereClause`" `"$SourceDatabase`" `"$tableName`" > `"$backupFile`""
	Invoke-Expression $mysqldumpCommand
}
#################################################################
function Backup-TableData-Array {
	param (
		[string]$tableName,
		[string]$tableNameFile,
		[string]$columnName,
		[int[]]$values,
		[string]$SourceDatabase,
		[string]$BackupDir
	)
	
	# Create backup directory
	# $backupDirFull = "$CharacterBackupDir\$AccountName\$characterName ($CurrentDate) - $Race $Class $Gender LV$Level"
	if (-not (Test-Path $BackupDir)) {
		New-Item -Path $BackupDir -ItemType Directory | Out-Null
	}
	
	$backupFile = "$BackupDir\$tableNameFile.sql"
	$valuesList = $values -join ","
	$whereClause = "$columnName IN ($valuesList)"
	
	$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --hex-blob --where=`"$whereClause`" `"$SourceDatabase`" `"$tableName`" > `"$backupFile`""
	Invoke-Expression $mysqldumpCommand

	
}
#################################################################
function ConvertFromUnixTime {
	param (
		[int64]$unixTime
	)

	$epoch = [datetime]'1970-01-01 00:00:00'
	$readableTime = $epoch.AddSeconds($unixTime).ToLocalTime()
	return $readableTime
}
#################################################################
function Execute-Query {
	param (
		[Parameter(Mandatory=$true)]
		[string]$Query,
		
		[Parameter(Mandatory=$true)]
		[string]$TableName,
		
		[Parameter(Mandatory=$true)]
		[string]$ConnectionName
	)

	try {
		# Write-Output "Query: $Query"
		Invoke-SqlUpdate -ConnectionName $ConnectionName -Query $Query | Out-Null
		# Write-Output "Query for $TableName executed successfully." -ForegroundColor Green
	} catch {
		Write-Output "($TableName) An error occurred: $_" -ForegroundColor Red
	}
}
#################################################################
# Function to check if a table exists
function Table-Exists {
	param (
		[Parameter(Mandatory=$true)]
		[string]$TableName,

		[Parameter(Mandatory=$true)]
		[string]$ConnectionName
	)

	try {
		$query = "SHOW TABLES LIKE '$TableName'"
		$result = Invoke-SqlQuery -ConnectionName $ConnectionName -Query $query 3>$null		#supress warnings when no results found
		return ($null -ne $result)
	}
	catch {
		Write-Error "Error checking if table '$TableName' exists: $_"
		return $false
	}
}
#################################################################
function Check-Value-in-DB {
	param (
		[string]$Query,
		[string]$ValueColumn,
		[string]$ConnectionName
	)
	
		$value = $null
		try {
			# Write-Host "Query: $Query" -ForegroundColor Cyan
			$Result = Invoke-SqlQuery -ConnectionName $ConnectionName -Query $Query 3>$null		#supress warnings when no results found
			
			if ($Result) {
				$value = $Result.$ValueColumn
				# Write-Host "ID for username '$characterNameToSearch': $guid" -ForegroundColor Cyan
				return $value
#########################
			#found no value
			} else {
				# Write-Host "`nNo character found with name '$characterNameToSearch'" -ForegroundColor Red
				return $null
			}
			# $reader.Close()
##########################
		} catch {
			Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
		}
##########################
}
#################################################################
function Get-ItemNameById {
	param(
		[int]$ItemId
	)
	
	if ($ItemId -le 0) {
		return $ItemId
	}

	$Query = "SELECT name FROM item_template WHERE entry = @ItemId"
	
	try {
		$Result = Invoke-SqlQuery -ConnectionName "WorldConn" -Query $Query -Parameters @{ ItemId = $ItemId } 3>$null		#supress warnings when no results found
		if ($Result -and $Result.name) {
			# Write-Host "Item ID $ItemId name found: $Result.name."
			return $Result.name
		} else {
			# Write-Host "Item ID $ItemId not found in the database."
			return "Unknown"
		}
	}
	catch {
		# Write-Host "Failed to lookup item ID $ItemId : ${_}"
		return "Unknown"
	}
}
#################################################################
function Get-MapNameById {
	param(
		[int]$MapId
	)
	
	$Query = "SELECT Name FROM Maps WHERE ID = @MapId"
	
	try {
		$result = Invoke-SQLiteQuery -DataSource $MapZoneDBFilePath -Query $Query -SqlParameters @{ MapId = $MapId }
		if ($Result -and $Result.name) {
			return $Result.name
		} else {
			return "Unknown"
		}
	}
	catch {
		return "Unknown"
	}
}
#################################################################
function Get-ZoneNameById {
	param(
		[int]$ZoneId
	)
	
	$Query = "SELECT Name FROM Zones WHERE ID = @ZoneId"
	
	try {
		$result = Invoke-SQLiteQuery -DataSource $MapZoneDBFilePath -Query $Query -SqlParameters @{ ZoneId = $ZoneId }
		if ($Result -and $Result.name) {
			return $Result.name
		} else {
			return "Unknown"
		}
	}
	catch {
		return "Unknown"
	}
}
#################################################################
function CreateCharacterInfoFile {
	param(
		[string]$backupDirFull,
		[int]$CharacterId,
		[int]$CharacterAccountId,
		[string]$CharacterAccountName,
		[string]$CharacterCreationDate,
		[string]$CharacterName,
		[string]$CharacterRaceString,
		[string]$CharacterClassString,
		[string]$CharacterGenderString,
		[int]$CharacterLevel,
		[int]$CharacterHonor,
		[string]$CharacterMoneyConverted,
		[int]$CharacterXP,
		[int]$CharacterHealth,
		[int]$CharacterMana,
		[int]$CharacterSkin,
		[int]$CharacterFace,
		[int]$CharacterHairStyle,
		[int]$CharacterHairColor,
		[int]$CharacterFacialStyle,
		[int]$CharacterBankSlots,
		[int]$CharacterArenapoints,
		[int]$CharacterTotalKills,
		[string]$CharacterEquipmentCache,
		[int]$CharacterAmmoId,
		[int]$CharacterCurMap,
		[int]$CharacterCurZone
	)
		
	# Create the text file path
	$CharacterInfoFilePath = Join-Path -Path $backupDirFull -ChildPath "character_info.txt"
	
	# Create the text file and write the character information
	New-Item -ItemType File -Path $CharacterInfoFilePath -Force | Out-Null
	
	# Step 2: Split the string into an array
	$CharacterEquipmentList = $CharacterEquipmentCache -split ' '
	# Step 3: Remove all items with the value 0
	$FilteredCharacterEquipmentList = $CharacterEquipmentList | Where-Object { $_ -ne 0 }
	
	# Iterate through each ItemID in the list
	foreach ($ItemId in $FilteredCharacterEquipmentList) {
		# Get the Item Name using the function
		$ItemName = Get-ItemNameById -ItemId $ItemId
		
		# Format the result as "ItemName (ItemID)" and add it to the result list
		$FormattedItemList += "$ItemName ($ItemId), "
	}
	
	# Join all items in the list into a single line, separated by commas
	$FormattedItemListLine = $FormattedItemList -join " "
	
	#Ammo Name and ID
	$AmmoItemName = Get-ItemNameById -ItemId $CharacterAmmoId
	$FormattedAmmoItem = "$AmmoItemName ($CharacterAmmoId)"
	
	#Get Map and Zone names
	$CharacterCurMapName = Get-MapNameById -MapId $CharacterCurMap
	$CharacterCurZoneName = Get-ZoneNameById -ZoneId $CharacterCurZone
	
	# Create the text file and write the character information
	$Content = @(
		"Account ID: $CharacterAccountId"
		"Account Name: $CharacterAccountName"
		"Creation Date: $CharacterCreationDate"
		"ID: $CharacterId"
		"Name: $CharacterName"
		"Race: $CharacterRaceString"
		"Class: $CharacterClassString"
		"Gender: $CharacterGenderString"
		"Level: $CharacterLevel"
		"Honor Points: $CharacterHonor"
		"Money: $CharacterMoneyConverted"
		"XP: $CharacterXP"
		"Health: $CharacterHealth"
		"Mana: $CharacterMana"
		"Skin: $CharacterSkin"
		"Face: $CharacterFace"
		"Hair Style: $CharacterHairStyle"
		"Hair Color: $CharacterHairColor"
		"Facial Style: $CharacterFacialStyle"
		"Bank Slots: $CharacterBankSlots"
		"Equipment Cache: $FormattedItemListLine"
		"Ammo ID: $FormattedAmmoItem"
		"Arena Points: $CharacterArenapoints"
		"Total Kills: $CharacterTotalKills"
		"Current Map: $CharacterCurMapName"
		"Current Zone: $CharacterCurZoneName"
	)
	
	$Content | Out-File -FilePath $CharacterInfoFilePath -Append
}
#################################################################
function GetCharacterRaceString {
	param(
		[int]$Race
	)
	
	switch ($Race) {
		1 { $RaceString = "Human" }
		2 { $RaceString = "Orc" }
		3 { $RaceString = "Dwarf" }
		4 { $RaceString = "Night_Elf" }
		5 { $RaceString = "Undead" }
		6 { $RaceString = "Tauren" }
		7 { $RaceString = "Gnome" }
		8 { $RaceString = "Troll" }
		10 { $RaceString = "Blood_Elf" }
		11 { $RaceString = "Draenei" }
		default { $RaceString = "Unknown_Race" }
	}
	
	return $RaceString
}
#################################################################
function GetCharacterClassString {
	param(
		[int]$Class
	)
	
	switch ($Class) {
		1 { $ClassString = "Warrior" }
		2 { $ClassString = "Paladin" }
		3 { $ClassString = "Hunter" }
		4 { $ClassString = "Rogue" }
		5 { $ClassString = "Priest" }
		6 { $ClassString = "Death_Knight" }
		7 { $ClassString = "Shaman" }
		8 { $ClassString = "Mage" }
		9 { $ClassString = "Warlock" }
		11 { $ClassString = "Druid" }
		default { $ClassString = "Unknown_Class" }
	}
	
	return $ClassString
}
#################################################################
function GetCharacterGenderString {
	param(
		[int]$Gender
	)
	
	switch ($Gender) {
		0 { $GenderString = "Male" }
		1 { $GenderString = "Female" }
		default { $GenderString = "Unknown_Gender" }
	}
	
	return $GenderString
}
#################################################################
#endregion
#################################################################
#region Backup-Characters
#################################################################
function Backup-Character {
	param (
		[int]$characterId,
		[string]$characterName,
		[string]$accountID,
		[string]$BackupDir
	)
	
	Write-Host "`nBacking up character $characterName..." -ForegroundColor Cyan
	
########## List of tables to back up
	$tables = @(
		"characters",
		"character_account_data",
		"character_achievement", 	#fixed achivements not being restored
		"character_achievement_progress",
		"character_action",
		"character_aura",
		"character_glyphs",
		"character_homebind",
		"character_queststatus",
		"character_queststatus_rewarded",
		"character_reputation",
		"character_skills",
		"character_spell",
		"character_talent",
		"character_inventory",
		"character_equipmentsets",
		################## new 13-01-2026
		"character_arena_stats",
		"character_banned",
		"character_battleground_random",
		"character_brew_of_the_month",
		"character_entry_point",
		"character_instance",
		"character_queststatus_daily",
		"character_queststatus_weekly",
		"character_queststatus_monthly",
		"character_queststatus_seasonal",
		"character_spell_cooldown",
		"character_stats",
		################## new 14-01-2026
		"character_social",
		"battleground_deserters"
		##################
	)
	
	foreach ($table in $tables) {
		Backup-TableData -tableName $table -tableNameFile $table -columnName "guid" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
	}
	
########## Pet Data
	$petsData = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT id, entry, level, name FROM character_pet WHERE owner = @owner" -Parameters @{ owner = $characterId } 3>$null		#supress warnings when no results found
	
	if ($petsData) {
		foreach ($pet in $petsData) {
			$petEntryName = Invoke-SqlQuery -ConnectionName "WorldConn" -Query "SELECT name FROM creature_template WHERE entry = @PetEntry" -Parameters @{ PetEntry = $pet.entry } 3>$null		#supress warnings when no results found
			Write-Host "Found pet: (ID: $($pet.id)), $($pet.name), $($petEntryName.name), LV $($pet.level)" -ForegroundColor Cyan
		}
		
		Backup-TableData -tableName "character_pet" -tableNameFile "character_pet" -columnName "owner" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
		
		$petIds = $petsData | Select-Object -ExpandProperty id
		
		Backup-TableData-Array -tableName "pet_aura" -tableNameFile "pet_aura" -columnName "guid" -values $petIds -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
		Backup-TableData-Array -tableName "pet_spell" -tableNameFile "pet_spell" -columnName "guid" -values $petIds -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
		Backup-TableData-Array -tableName "pet_spell_cooldown" -tableNameFile "pet_spell_cooldown" -columnName "guid" -values $petIds -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
	}
	
########## Item Data
	Backup-TableData -tableName "item_instance" -tableNameFile "item_instance" -columnName "owner_guid" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
	
########## Mail Data
	Backup-TableData -tableName "mail" -tableNameFile "mail_receiver" -columnName "receiver" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
	
########## Auction House Data #new 14-01-2026
	Backup-TableData -tableName "auctionhouse" -tableNameFile "auctionhouse" -columnName "itemowner" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir

########## Transmog Data
	if (Table-Exists -TableName "custom_transmogrification" -ConnectionName "CharConn") {
		Backup-TableData -tableName "custom_transmogrification" -tableNameFile "custom_transmogrification" -columnName "Owner" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
		Backup-TableData -tableName "custom_transmogrification_sets" -tableNameFile "custom_transmogrification_sets" -columnName "Owner" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
		Backup-TableData -tableName "custom_unlocked_appearances" -tableNameFile "custom_unlocked_appearances" -columnName "account_id" -value $accountID -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
	}
########## Reagent Bank Data
	if (Table-Exists -TableName "custom_reagent_bank" -ConnectionName "CharConn") {
		Backup-TableData -tableName "custom_reagent_bank" -tableNameFile "custom_reagent_bank" -columnName "character_id" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
	}
########## Character Settings data
	if (Table-Exists -TableName "character_settings" -ConnectionName "CharConn") {
		Backup-TableData -tableName "character_settings" -tableNameFile "character_settings" -columnName "guid" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
	}
########## Beast Master 
	if (Table-Exists -TableName "beastmaster_tamed_pets" -ConnectionName "CharConn") {
		Backup-TableData -tableName "beastmaster_tamed_pets" -tableNameFile "beastmaster_tamed_pets" -columnName "owner_guid" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
	}
########## Improved Bank
	if (Table-Exists -TableName "mod_improved_bank" -ConnectionName "CharConn") {
		Backup-TableData -tableName "mod_improved_bank" -tableNameFile "mod_improved_bank" -columnName "owner_guid" -value $characterId -SourceDatabase $SourceDatabaseCharacters -BackupDir $BackupDir
	}
##########
	# Delete empty SQL files
	Get-ChildItem -Path $BackupDir -Filter "*.sql" -Recurse | Where-Object { $_.Length -eq 0 } | Remove-Item
	
}
#################################################################

#################################################################
function Backup-Character-Main {
	# Open database connections
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "AuthConn"
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "CharConn"
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseWorld -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "WorldConn"

	try {
		Write-Host "(Press CTRL + C to exit)" -ForegroundColor Cyan
		$userNameToSearch = Read-Host "`nEnter account name"
		
		$id = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id FROM account WHERE username = @username" -Parameters @{ username = $userNameToSearch } 3>$null		#supress warnings when no results found
########################################
		if ($id) {
			Write-Host "`nID for username '$userNameToSearch': $($id.id)" -ForegroundColor Cyan
			
			$characterData = Invoke-SqlQuery -ConnectionName "CharConn" -Query @"
				SELECT guid, account, name, race, class, gender, level, xp, health, power1, money, skin, face, hairStyle, hairColor, facialStyle, bankSlots, equipmentCache, ammoId, arenapoints, totalHonorPoints, totalKills, creation_date, map, zone
				FROM characters 
				WHERE account = @id
"@ -Parameters @{ id = $id.id } 3>$null		#supress warnings when no results found

			if ($characterData) {
				if (-not ([string]::IsNullOrEmpty($CharacterNameRegexFilter))) {
					$characterData = $characterData | Where-Object { $_.name -match $CharacterNameRegexFilter }
				}

				$exitScript = $false
				while (-not $exitScript) {
					Write-Host "`nFound $($characterData.Count) Characters." -ForegroundColor Green
					Write-Host "`nCharacter List:" -ForegroundColor Green
					$index = 1
########################################
					foreach ($character in $characterData) {
						$characterId = $character.guid
						$characterName = $character.name
						
						$Race = GetCharacterRaceString -Race $character.race
						$Class = GetCharacterClassString -Class $character.class
						$Gender = GetCharacterGenderString -Gender $character.gender
						
						$Level = $character.level
						$Honor = $character.totalHonorPoints
						$CreationDate = $character.creation_date
						#Convert creation date to day/month/year
						$CreationDate = (Get-Date $CreationDate).ToString("dd/MM/yyyy HH:mm:ss")
	
						$MoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $character.money
				
						Write-Host "`n$index. (GUID: $($characterId)) $($characterName) - Race: $($Race), Class: $($Class), Gender: $($Gender), LV$($Level), Honor: $($Honor), Money: $moneyConverted, Creation date: $($CreationDate)" -ForegroundColor Green
						$index++
					}
					
					Write-Host "`n$index. Back up all characters" -ForegroundColor Green
					Write-Host "$($index + 1). Go back" -ForegroundColor Green
					Write-Host "$($index + 2). Exit script" -ForegroundColor Green
					
					$choice = Read-Host "`nType a number (1-$($index + 2))"
###########################################################
					if ($choice -match '^\d+$') {
						$choice = [int]$choice
						
						if ($choice -ge 1 -and $choice -le $characterData.Count) {
							$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
							$selectedCharacter = $characterData[$choice - 1]
							
							$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
#############################################################
							$CurCharMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $selectedCharacter.money
							
							$CurCharRace = GetCharacterRaceString -Race $selectedCharacter.race
							$CurCharClass = GetCharacterClassString -Class $selectedCharacter.class
							$CurCharGender = GetCharacterGenderString -Gender $selectedCharacter.gender
							
							$CurCharName = $selectedCharacter.name
							$CurCharLevel = $selectedCharacter.level
							
							$backupDirFull = "$CharacterBackupDir\single_backups\$userNameToSearch\$CurCharName ($CurrentDate) - $CurCharRace $CurCharClass $CurCharGender LV$CurCharLevel"
							if (-not (Test-Path $backupDirFull)) {
								New-Item -Path $backupDirFull -ItemType Directory | Out-Null
							}
							
							# Using splatting to avoid line continuation issues
							$characterInfoParams = @{
								backupDirFull = $backupDirFull
								CharacterId = $selectedCharacter.guid
								CharacterAccountId = $id.id
								CharacterAccountName = $userNameToSearch
								CharacterCreationDate = $selectedCharacter.creation_date
								CharacterName = $selectedCharacter.name
								CharacterRaceString = $CurCharRace
								CharacterClassString = $CurCharClass
								CharacterGenderString = $CurCharGender
								CharacterLevel = $selectedCharacter.level
								CharacterHonor = $selectedCharacter.totalHonorPoints
								CharacterMoneyConverted = $CurCharMoneyConverted
								CharacterXP = $selectedCharacter.xp
								CharacterHealth = $selectedCharacter.health
								CharacterMana = $selectedCharacter.power1
								CharacterSkin = $selectedCharacter.skin
								CharacterFace = $selectedCharacter.face
								CharacterHairStyle = $selectedCharacter.hairStyle
								CharacterHairColor = $selectedCharacter.hairColor
								CharacterFacialStyle = $selectedCharacter.facialStyle
								CharacterBankSlots = $selectedCharacter.bankSlots
								CharacterArenapoints = $selectedCharacter.arenapoints
								CharacterTotalKills = $selectedCharacter.totalKills
								CharacterEquipmentCache = $selectedCharacter.equipmentCache
								CharacterAmmoId = $selectedCharacter.ammoId
								CharacterCurMap = $selectedCharacter.map
								CharacterCurZone = $selectedCharacter.zone
							}
							CreateCharacterInfoFile @characterInfoParams
#############################################################
							Backup-Character -characterId $selectedCharacter.guid -characterName $selectedCharacter.name -accountID $id.id -BackupDir $backupDirFull
							$stopwatch.Stop()
							Write-Host "Backup done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
						}
#############################################################
						elseif ($choice -eq $index) {
							$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
							foreach ($character in $characterData) {
								$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
#############################################################
								$CurCharMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $character.money
								
								$CurCharRace = GetCharacterRaceString -Race $character.race
								$CurCharClass = GetCharacterClassString -Class $character.class
								$CurCharGender = GetCharacterGenderString -Gender $character.gender
								
								$CurCharName = $character.name
								$CurCharLevel = $character.level
								
								$backupDirFull = "$CharacterBackupDir\single_backups\$userNameToSearch\$CurCharName ($CurrentDate) - $CurCharRace $CurCharClass $CurCharGender LV$CurCharLevel"
								if (-not (Test-Path $backupDirFull)) {
									New-Item -Path $backupDirFull -ItemType Directory | Out-Null
								}
								
								# Using splatting to avoid line continuation issues
								$characterInfoParams = @{
									backupDirFull = $backupDirFull
									CharacterId = $character.guid
									CharacterAccountId = $id.id
									CharacterAccountName = $userNameToSearch
									CharacterCreationDate = $character.creation_date
									CharacterName = $character.name
									CharacterRaceString = $CurCharRace
									CharacterClassString = $CurCharClass
									CharacterGenderString = $CurCharGender
									CharacterLevel = $character.level
									CharacterHonor = $character.totalHonorPoints
									CharacterMoneyConverted = $CurCharMoneyConverted
									CharacterXP = $character.xp
									CharacterHealth = $character.health
									CharacterMana = $character.power1
									CharacterSkin = $character.skin
									CharacterFace = $character.face
									CharacterHairStyle = $character.hairStyle
									CharacterHairColor = $character.hairColor
									CharacterFacialStyle = $character.facialStyle
									CharacterBankSlots = $character.bankSlots
									CharacterArenapoints = $character.arenapoints
									CharacterTotalKills = $character.totalKills
									CharacterEquipmentCache = $character.equipmentCache
									CharacterAmmoId = $character.ammoId
									CharacterCurMap = $character.map
									CharacterCurZone = $character.zone
								}
								CreateCharacterInfoFile @characterInfoParams
#############################################################
								Backup-Character -characterId $character.guid -characterName $character.name -accountID $id.id -Race -BackupDir $backupDirFull
							}
							$stopwatch.Stop()
							Write-Host "All characters backed up in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
						}
########################################
						elseif ($choice -eq ($index + 1)) {
							Write-Host "Going back..." -ForegroundColor Yellow
							break
						}
########################################
						elseif ($choice -eq ($index + 2)) {
							Write-Host "Exiting script..." -ForegroundColor Yellow
							$exitScript = $true
						}
########################################
						else {
							Write-Host "Invalid selection. Please try again." -ForegroundColor Red
						}
					}
########################################
					else {
						Write-Host "Invalid selection. Please try again." -ForegroundColor Red
					}
				}
			}
########################################
			else {
				Write-Host "No characters found for account ID '$($id.id)'" -ForegroundColor Red
			}
########################################
		}
		else {
			Write-Host "`nNo account found with username '$userNameToSearch'" -ForegroundColor Red
		}
########################################
	} catch {
		Write-Host "An error occurred (line $($_.InvocationInfo.ScriptLineNumber)): $($_.Exception.Message)" -ForegroundColor Red
		$exitScript = $true
	}
	# Close all connections
	Close-SqlConnection -ConnectionName "AuthConn"
	Close-SqlConnection -ConnectionName "CharConn"
	Close-SqlConnection -ConnectionName "WorldConn"
}
#################################################################
#endregion
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
		Invoke-Expression $mysqldumpCommand
		
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
				Invoke-Expression $mysqldumpCommand
								
				if ($LASTEXITCODE -eq 0) {
					# Write-Host "Successfully backed up item_instance table to $backupFile" -ForegroundColor Green
				} else {
					Write-Host "Error backing up guild_house table." -ForegroundColor Red
				}
			}
		}
	}
########### Handle creature_respawn table

	$backupFile = "$BackupDir\creature.sql"
	
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
					$BackupDir = "$GuildBackupDir\full_backups\$SourceServerName ($($CurrentDate))\$GuildName ($CurrentDate) - $LeaderName"
					
					Backup-Guild -GuildID $guild.guildid `
								-GuildName $guild.name `
								-BackupDir $BackupDir
				}
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
}
#################################################################
#endregion
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
			$Query = "SELECT guid FROM characters WHERE name = $characterName;"
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
							$guidMappingpPets.Add([pscustomobject]@{
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
						
						# Modify the third value with the new GUID
						$values[2] = $newGuid
						
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
								$matchingGuid = $guidMappingItems | Where-Object { $_.OldGuid -eq $currentValue }
								
								# If a match is found, replace the old GUID with the new GUID
								if ($matchingGuid) {
									$values[3] = $matchingGuid.NewGuid
								}
############################################ THIS IS FOR BAG GUID
								# Get the current value in the target column (adjust for 0-based index)
								$currentValue = $values[1]
								
								# Check if the current value matches an old GUID in the mapping
								$matchingGuid = $guidMappingItems | Where-Object { $_.OldGuid -eq $currentValue }
								
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
								$currentValue = $values[2]
								
								# Check if the current value matches an old GUID in the mapping
								$matchingGuid = $guidMappingItems | Where-Object { $_.OldGuid -eq $currentValue }
								
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
								$matchingGuid = $guidMappingItems | Where-Object { $_.OldGuid -eq $currentValue }
								
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
			# $guidMappingCharacters += [pscustomobject]@{CharacterName = $characterName; OldGuid = $oldGuid; NewGuid = $newGuid}
			# if (-not $guidMappingCharacters -or $guidMappingCharacters.Count -eq 0) {
				# Write-Host "guidMappingCharacters is empty!" -ForegroundColor Red
			# } else {
				# Write-Host "guidMappingCharacters has $($guidMappingCharacters.Count) entries." -ForegroundColor Green
				# $guidMappingCharacters | Format-Table -AutoSize
			# }

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
}
#################################################################
#endregion
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
############################
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
############################ Process guild_members.json
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
#############################
		$pattern = "(?<=\().*?(?=\))"
############################# Process guild.sql
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
		$guidMappingItems.Add([pscustomobject]@{
			OldGuildGuid       = $oldGuid
			NewGuildGuid       = $newGuildID
			GuildLeaderID       = $characterID
		}) | Out-Null
					
		$parts[0] = $newGuildID
		$parts[2] = $characterID
		
		# 3. Reconstruct the row
		$modifiedRow = "(" + ($parts -join ",") + ")"
		$modifiedSqlQuery = "INSERT INTO `guild` VALUES $modifiedRow;"
		
		# Execute
		Execute-Query -query $modifiedSqlQuery -tablename "guild" -ConnectionName "CharConn"
############################## Process guild_rank, guild_bank_right, guild_bank_tab
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
############################### Process guild_member.sql
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
############################# Process guild_bank_eventlog.sql
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
############################# Process guild_eventlog.sql
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
		
############################# Process guild_member_withdraw.sql
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
################################################
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
############################################
				} else {
					Write-Host "Table 'item_instance' does not exist, skipping restore for this table." -ForegroundColor Red
				}
			}
################################################################################


######################################## PROCESS GUILD_HOUSE - alter id[0] taking into account existing items and guild[1]
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
############################################ PROCESS CREATURE (this is for guild house NPCs) - alter guid[0] taking into account existing creatures
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
############################################
			} else {
				Write-Host "Table 'guild_house' does not exist, skipping restore for this table." -ForegroundColor Red
			}
		}
########################################
		$stopwatch.Stop()
		Write-Host "Successfully imported guild $GuildName in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
	} else {
		Write-Host "No guild file found. Aborting..." -ForegroundColor Red
	}
########################################
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
################################################
	# Close all connections
	Close-SqlConnection -ConnectionName "AuthConn"
	Close-SqlConnection -ConnectionName "CharConn"
	Close-SqlConnection -ConnectionName "WorldConn"
}
#################################################################
#endregion
#################################################################
function Backup-FusionGEN {
	param (
		[string]$BackupDir
	)
	
	Write-Host "`nBacking up FusionGEN website data..." -ForegroundColor Cyan
#################################################################
	$tables = @(
		"access_trade_items",
		"account_data",
		"acl_account_groups",
		"acl_account_permissions",
		"acl_account_roles",
		"acl_group_roles",
		"acl_groups",
		"acl_roles",
		"acl_roles_permissions",
		"article_tag",
		"articles",
		"avatars",
		"backup",
		"changelog",
		"changelog_type",
		
		"character_tools_free",
		"character_trade",
		"ci_sessions",
		"comments",
		"cta_logs",
		
		"daily_signups",
		"data_wotlk_itemdisplayinfo",
		"dpta_logs",
		"email_change_key",
		"email_log",
		"email_templates",
		
		"emblemitems",
		"failed_logins",
		"gift_cards",
		"giftcard",
		"giftcard_attempts",
		
		"image_slider",
		"item_icons",
		
		"levelup_items",
		"log_emblem_transfer",
		"log_item_eoe",
		"log_skills",
		"logs",
		"member_admin_logs",
		"member_features",
		
		"member_id",
		"member_id_accounts",
		"member_id_feature_items",
		"member_id_features",
		"member_id_login_attempts",
		"member_id_purchases",
		
		"menu",
		"mod_logs",
		"monthly_income",
		"monthly_votes",
		
		"mysterybox_chance_options",
		"mysterybox_cooldowns",
		"mysterybox_history",
		"mysterybox_logs",
		"mysterybox_rewards",
		"notifications",
		
		"order_log",
		"pages",
		"password_recovery_key",
		"paygol_logs",
		
		"paypal_donate",
		"paypal_logs",
		"ranks",
		"realms",
		
		"sideboxes",
		"sideboxes_custom",
		"sideboxes_poll_answers",
		"sideboxes_poll_questions",
		"sideboxes_poll_votes",
		
		"skills",
		"spell_recipes",
		"spelltext_en",
		
		"store_groups",
		"store_items",
		"tag",
		
		"teleport_locations",
		"visitor_log",
		"vote_log",
		
		"vote_sites",
		"wheel_logs",
		"wheel_rewards_items",
		"wheel_upgrade_options"
	)
#################################################################
	foreach ($table in $tables) {
		$backupFile = "$BackupDir\$table.sql"
		
		$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-locks --skip-comments --compact --hex-blob `"$SourceDatabaseFusionGEN`" `"$table`" > `"$backupFile`""
		
		Invoke-Expression $mysqldumpCommand
		if ($LASTEXITCODE -eq 0) {
			Write-Host "Backed up data from $table to $backupFile" -ForegroundColor Green
		} else {
			Write-Host "Error backing up data from $tableName" -ForegroundColor Red
		}
	}
#################################################################
	#remove empty sqls
	Get-ChildItem -Path $BackupDir -Filter "*.sql" -Recurse | Where-Object { $_.Length -eq 0 } | Remove-Item
}
#################################################################
function Restore-FusionGEN {
	param (
		[string]$FusionGENBackupDir,
		[string]$AccountCharacterBackupDir
	)
	
	Write-Host "`nRestoring FusionGEN website data..." -ForegroundColor Cyan
#################################################################
	$tables = @(
		@("guild_bank_right", 0, $newGuildID),
		@("guild_bank_tab", 0, $newGuildID),
		@("guild_rank", 0, $newGuildID)
	)
#################################################################
	# Loop through each table in the array
	foreach ($entry in $tables) {
		# Extract the table name and the column number
		$table = $entry[0]
		# Path to the .sql file
		$sqlFilePath = "$BackupDir\$table.sql"
#################################################################
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
#################################################################
}
#################################################################
function Backup-FusionGen-Main {
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseFusionGEN -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "FusionGENConn"
	try {
		$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
		$BackupDir = "$FusionGENBackupDir\full_backups\$SourceServerName ($($CurrentDate))"
		Backup-FusionGEN -BackupDir $BackupDir
	} catch {
		Write-Host "An error occurred (line $($_.InvocationInfo.ScriptLineNumber)): $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Close-SqlConnection -ConnectionName "FusionGENConn"
	}
}
#################################################################
function Restore-FusionGen-Main {
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseFusionGEN -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "FusionGENConn"
	try {
#################################################################
		# Get all backup folders under full_backups
		$backupRoot = "$FusionGENBackupDir\full_backups"
		
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
		$chosenFusionGENBackupFolder = $backupFolders[$selection].FullName
		Write-Host "`nYou selected: $($chosenFusionGENBackupFolder.Name)" -ForegroundColor Green
#################################################################
		Write-Host "Now choose the full account and character backup to use to fetch ID lists" -ForegroundColor Cyan

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
		$chosenAccountCharacterBackupFolder = $backupFolders[$selection].FullName
		Write-Host "`nYou selected: $($chosenAccountCharacterBackupFolder.Name)" -ForegroundColor Green
#################################################################
		Restore-FusionGEN -FusionGENBackupDir $chosenFusionGENBackupFolder -AccountCharacterBackupDir $chosenAccountCharacterBackupFolder
#################################################################
	} catch {
		Write-Host "An error occurred (line $($_.InvocationInfo.ScriptLineNumber)): $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Close-SqlConnection -ConnectionName "FusionGENConn"
	}
}
#################################################################
#region All-Accounts
#################################################################
function Backup-All-Accounts-Main {
	# Open database connections
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "AuthConn"
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "CharConn"
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseWorld -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "WorldConn"
################################################################################
	try {
		$accounts = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id, username FROM account" 3>$null		#supress warnings when no results found
		if ($accounts) {
			if (-not ([string]::IsNullOrEmpty($AccountNameRegexFilter))) {
				$accounts = $accounts | Where-Object { $_.username -match $AccountNameRegexFilter }
			}
			
			if ($accounts.Count -eq 0) {
				Write-Host "Found 0 accounts after regex filter." -ForegroundColor Red
				return
			}
			
			Write-Host "Found $($accounts.Count) accounts. Starting backup process..." -ForegroundColor Green
			$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
################################################################################
			$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
			foreach ($account in $accounts) {
				$accountId = $account.id
				$accountName = $account.username
				Write-Host "`nBacking up account: $accountName (ID: $accountId)" -ForegroundColor Cyan
				
				# $backupDirFullAccount = "$CharacterBackupDir\$accountName"
				$backupDirFullAccount = "$CharacterBackupDir\full_backups\$SourceServerName ($($CurrentDate))\$accountName"
				if (-not (Test-Path $backupDirFullAccount)) {
					New-Item -Path $backupDirFullAccount -ItemType Directory | Out-Null
				}
################################################################################
				# Backup account details
				$backupFile = "$backupDirFullAccount\_account.sql"
				$whereClause = "id=$accountId"
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --hex-blob --where=`"$whereClause`" `"$SourceDatabaseAuth`" `"account`" > `"$backupFile`""
				Invoke-Expression $mysqldumpCommand
				
				# Backup account access details
				$backupFile = "$backupDirFullAccount\_account_access.sql"
				$whereClause = "id=$accountId"
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --hex-blob --where=`"$whereClause`" `"$SourceDatabaseAuth`" `"account_access`" > `"$backupFile`""
				Invoke-Expression $mysqldumpCommand
				
				#remove empty sqls
				Get-ChildItem -Path $backupDirFullAccount -Filter "*.sql" -Recurse | Where-Object { $_.Length -eq 0 } | Remove-Item
################################################################################
				$characterData = Invoke-SqlQuery -ConnectionName "CharConn" -Query @"
					SELECT guid, account, name, race, class, gender, level, xp, health, power1, money, skin, face, hairStyle, hairColor, facialStyle, bankSlots, equipmentCache, ammoId, arenapoints, totalHonorPoints, totalKills, creation_date, map, zone
					FROM characters 
					WHERE account = @id
"@ -Parameters @{ id = $accountId } 3>$null		#supress warnings when no results found

				if ($characterData) {
					if (-not ([string]::IsNullOrEmpty($CharacterNameRegexFilter))) {
						$characterData = $characterData | Where-Object { $_.name -match $CharacterNameRegexFilter }
					}
					Write-Host "Found $($characterData.Count) characters for account $accountName." -ForegroundColor Green
					foreach ($character in $characterData) {
						$CurCharMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $character.money
						$CurCharRace = GetCharacterRaceString -Race $character.race
						$CurCharClass = GetCharacterClassString -Class $character.class
						$CurCharGender = GetCharacterGenderString -Gender $character.gender
						$CurCharName = $character.name
						$CurCharLevel = $character.level

						# $backupDirFull = "$CharacterBackupDir\$accountName\$CurCharName ($CurrentDate) - $CurCharRace $CurCharClass $CurCharGender LV$CurCharLevel"
						$backupDirFull = Join-Path $backupDirFullAccount "$CurCharName ($CurrentDate) - $CurCharRace $CurCharClass $CurCharGender LV$CurCharLevel"
						if (-not (Test-Path $backupDirFull)) {
							New-Item -Path $backupDirFull -ItemType Directory | Out-Null
						}
################################################################################
						$characterInfoParams = @{
							backupDirFull = $backupDirFull
							CharacterId = $character.guid
							CharacterAccountId = $accountId
							CharacterAccountName = $accountName
							CharacterCreationDate = $character.creation_date
							CharacterName = $character.name
							CharacterRaceString = $CurCharRace
							CharacterClassString = $CurCharClass
							CharacterGenderString = $CurCharGender
							CharacterLevel = $character.level
							CharacterHonor = $character.totalHonorPoints
							CharacterMoneyConverted = $CurCharMoneyConverted
							CharacterXP = $character.xp
							CharacterHealth = $character.health
							CharacterMana = $character.power1
							CharacterSkin = $character.skin
							CharacterFace = $character.face
							CharacterHairStyle = $character.hairStyle
							CharacterHairColor = $character.hairColor
							CharacterFacialStyle = $character.facialStyle
							CharacterBankSlots = $character.bankSlots
							CharacterArenapoints = $character.arenapoints
							CharacterTotalKills = $character.totalKills
							CharacterEquipmentCache = $character.equipmentCache
							CharacterAmmoId = $character.ammoId
							CharacterCurMap = $character.map
							CharacterCurZone = $character.zone
						}
						CreateCharacterInfoFile @characterInfoParams
################################################################################
						Backup-Character -characterId $character.guid -characterName $character.name -accountID $accountId -BackupDir $backupDirFull
					}
################################################################################
				} else {
					Write-Host "No characters found for account '$accountName'" -ForegroundColor Yellow
				}
			}
################################################################################
			$stopwatch.Stop()
			Write-Host "`nAll accounts and characters backed up in $($stopwatch.Elapsed.TotalSeconds) seconds." -ForegroundColor Green
################################################################################
		} else {
			Write-Host "No accounts found in the database." -ForegroundColor Red
		}
################################################################################
	} catch {
		Write-Host "An error occurred (line $($_.InvocationInfo.ScriptLineNumber)): $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Close-SqlConnection -ConnectionName "AuthConn"
		Close-SqlConnection -ConnectionName "CharConn"
		Close-SqlConnection -ConnectionName "WorldConn"
		[console]::beep()
	}
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
		$guidMappingGuilds.Clear()
		#List to store character folder paths
		$CharacterFolderList = @()
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
		$totalChars = $CharacterFolderList.Count
		$charCounter = 0
		
		foreach ($characterFolder in $CharacterFolderList) {
			$charCounter++
			
			$percent = [int](($charCounter / $totalChars) * 100)
			Write-Progress -Activity "Restoring Characters" -Status "Processing $charCounter of $totalChars" -PercentComplete $percent
		
			Restore-Multiple-Character-Tables -account $accountName -accountID $accountId -BackupDir $characterFolder
		
			if ($charCounter % 50 -eq 0) {
				Write-Host "Processed $charCounter characters so far..." -ForegroundColor Cyan
			}
		}
			
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
#region All-Guilds
#################################################################
function Backup-All-Guilds-Main-Wrapper {
	Backup-Guild-Main -AllGuilds
	[console]::beep()
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