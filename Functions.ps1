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
#######################################
function Backup-TableData {
    param (
        [string]$tableName,
        [string]$tableNameFile,
        [string]$columnName,
        [int]$value,
        [string]$characterName,
        [string]$Race,
        [string]$Class,
        [string]$Gender,
        [string]$Level,
        [int]$XP,
        [int]$Money,
        [int]$Honor,
        [string]$AccountName,
        [string]$CurrentDate
    )
    
    # Convert race/class/gender
	$Race = GetCharacterRaceString -Race $Race
	$Class = GetCharacterClassString -Class $Class
	$Gender = GetCharacterGenderString -Gender $Gender

    $backupDirFull = "$CharacterBackupDir\$AccountName\$characterName ($CurrentDate) - $Race $Class $Gender LV$Level"
    if (-not (Test-Path $backupDirFull)) {
        New-Item -Path $backupDirFull -ItemType Directory | Out-Null
    }
    
    $backupFile = "$backupDirFull\$tableNameFile.sql"
	# Write-Host "File: $backupDirFull\$tableNameFile.sql" -ForegroundColor Yellow
    $whereClause = "$columnName=$value"
	

    $mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --hex-blob --where=`"$whereClause`" `"$SourceDatabaseCharacters`" `"$tableName`" > `"$backupFile`""
    Invoke-Expression $mysqldumpCommand
}
#######################################
function Backup-TableData-Array {
    param (
        [string]$tableName,
        [string]$tableNameFile,
        [string]$columnName,
        [int[]]$values,
        [string]$characterName,
        [string]$Race,
        [string]$Class,
        [string]$Gender,
        [string]$Level,
        [int]$XP,
        [int]$Money,
        [int]$Honor,
        [string]$AccountName,
        [string]$CurrentDate
    )
    
    # Convert race/class/gender
	$Race = GetCharacterRaceString -Race $Race
	$Class = GetCharacterClassString -Class $Class
	$Gender = GetCharacterGenderString -Gender $Gender

    # Create backup directory
    $backupDirFull = "$CharacterBackupDir\$AccountName\$characterName ($CurrentDate) - $Race $Class $Gender LV$Level"
    if (-not (Test-Path $backupDirFull)) {
        New-Item -Path $backupDirFull -ItemType Directory | Out-Null
    }
    
    $backupFile = "$backupDirFull\$tableNameFile.sql"
    $valuesList = $values -join ","
    $whereClause = "$columnName IN ($valuesList)"
    
    $mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --hex-blob --where=`"$whereClause`" `"$SourceDatabaseCharacters`" `"$tableName`" > `"$backupFile`""
    Invoke-Expression $mysqldumpCommand

	
}
########################################
function GetCharacterData {
    param (
        [int]$CharacterID,
        [string]$TableName,
        [string]$ColumnNameToGetValue,
        [string]$ColumnNameToSearchForID
    )

    try {
        $query = "SELECT $ColumnNameToGetValue FROM $TableName WHERE $ColumnNameToSearchForID = @CharacterID"
        $result = Invoke-SqlQuery -ConnectionName "CharConn" -Query $query -Parameters @{CharacterID = $CharacterID}
        return $result
    }
    catch {
        Write-Host "Error fetching character data: $_" -ForegroundColor Red
        return $null
    }
}
########################################
function ConvertFromUnixTime {
    param (
        [int64]$unixTime
    )

    $epoch = [datetime]'1970-01-01 00:00:00'
    $readableTime = $epoch.AddSeconds($unixTime).ToLocalTime()
    return $readableTime
}
########################################
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
########################################
# Function to check if a row already exists in a table (custom-unlocked-appearances)
function Row-Exists-custom-unlocked-appearances {
    param (
        [Parameter(Mandatory=$true)]
        [int]$AccountID,
        
        [Parameter(Mandatory=$true)]
        [int]$ItemTemplateID,
        
        [Parameter(Mandatory=$true)]
        [string]$ConnectionName
    )
    
    try {
        $query = "SELECT COUNT(*) as count FROM custom_unlocked_appearances WHERE account_id = @AccountID AND item_template_id = @ItemTemplateID;"
        
        $result = Invoke-SqlQuery -ConnectionName $ConnectionName `
                                 -Query $query `
                                 -Parameters @{
                                     AccountID = $AccountID
                                     ItemTemplateID = $ItemTemplateID
                                 }
        
        # Return true if count is greater than 0
        return ($result.count -gt 0)
    }
    catch {
        Write-Error "Error checking row existence: $_" -ForegroundColor Red
        return $false
    }
}
########################################
# Function to check if a row already exists in a table
function Row-Exists {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TableName,
        
        [Parameter(Mandatory=$true)]
        [string]$RowName,
        
        [Parameter(Mandatory=$true)]
        [string]$RowValue,
        
        [Parameter(Mandatory=$true)]
        [string]$ConnectionName
    )
    
    try {
        $query = "SELECT COUNT(*) as count FROM $TableName WHERE $RowName = $RowValue;"
        
        $result = Invoke-SqlQuery -ConnectionName $ConnectionName -Query $query
        
        # Return true if count is greater than 0
        return ($result.count -gt 0)
    }
    catch {
        Write-Error "Error checking row existence: $_" -ForegroundColor Red
        return $false
    }
}
########################################
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
        $result = Invoke-SqlQuery -ConnectionName $ConnectionName -Query $query
        return ($null -ne $result)
    }
    catch {
        Write-Error "Error checking if table '$TableName' exists: $_"
        return $false
    }
}
########################################
function Check-Character {
    param (
        [string]$characterNameToSearch
    )
		# Query to find guid based on username
		$query = "SELECT guid FROM characters WHERE name = @characterNameToSearch;"
		
		$guid = $null
		try {
			# Get the maximum GUID from the characters table
			$GuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query $query -Parameters @{characterNameToSearch = $characterNameToSearch}
			
			if ($GuidResult) {
				$guid = $GuidResult.guid
				Write-Host "ID for username '$characterNameToSearch': $guid" -ForegroundColor Cyan
				return $guid
#########################
			#found no character with that name
			} else {
				Write-Host "`nNo character found with name '$characterNameToSearch'" -ForegroundColor Red
				return $null
			}
			$reader.Close()
##########################
		} catch {
			Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
		}
##########################
}
################################
function Get-ItemNameById {
    param(
        [int]$ItemId
    )
    
    if ($ItemId -le 0) {
        return $ItemId
    }

    $Query = "SELECT name FROM item_template WHERE entry = @ItemId"
    
    try {
        $Result = Invoke-SqlQuery -ConnectionName "WorldConn" -Query $Query -Parameters @{ ItemId = $ItemId }
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
################################
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
################################
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
################################ Create character_info txt file
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
################################
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
################################
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
################################
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
################################
#endregion
########################################
#region Backup-Characters
########################################
function Backup-Character {
    param (
        [int]$characterId,
        [string]$characterName,
        [string]$accountID,
        [string]$Race,
        [string]$Class,
        [string]$Gender,
        [string]$Level,
        [int]$XP,
        [int]$Money,
        [int]$Honor,
        [string]$AccountName,
        [string]$CurrentDate
    )
    
    Write-Host "`nBacking up character $characterName..." -ForegroundColor Cyan
    
########## List of tables to back up
    $tables = @(
        "characters",
        "character_account_data",
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
        "character_equipmentsets"
    )
    
    foreach ($table in $tables) {
        Backup-TableData -tableName $table -tableNameFile $table -columnName "guid" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
    }
    
########## Pet Data
    $petsData = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT id, entry, level, name FROM character_pet WHERE owner = @owner" -Parameters @{ owner = $characterId }
    
    if ($petsData) {
        foreach ($pet in $petsData) {
            $petEntryName = Invoke-SqlQuery -ConnectionName "WorldConn" -Query "SELECT name FROM creature_template WHERE entry = @PetEntry" -Parameters @{ PetEntry = $pet.entry }
            Write-Host "Found pet: (ID: $($pet.id)), $($pet.name), $($petEntryName.name), LV $($pet.level)" -ForegroundColor Cyan
        }
        
        Backup-TableData -tableName "character_pet" -tableNameFile "character_pet" -columnName "owner" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
        
        $petIds = $petsData | Select-Object -ExpandProperty id
        
        Backup-TableData-Array -tableName "pet_aura" -tableNameFile "pet_aura" -columnName "guid" -values $petIds -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
        Backup-TableData-Array -tableName "pet_spell" -tableNameFile "pet_spell" -columnName "guid" -values $petIds -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
        Backup-TableData-Array -tableName "pet_spell_cooldown" -tableNameFile "pet_spell_cooldown" -columnName "guid" -values $petIds -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
    }
    
########## Item Data
    Backup-TableData -tableName "item_instance" -tableNameFile "item_instance" -columnName "owner_guid" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
    
########## Mail Data
    Backup-TableData -tableName "mail" -tableNameFile "mail_receiver" -columnName "receiver" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
    
########## Transmog Data
	if (Table-Exists -TableName "custom_transmogrification" -ConnectionName "CharConn") {
		Backup-TableData -tableName "custom_transmogrification" -tableNameFile "custom_transmogrification" -columnName "Owner" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
		Backup-TableData -tableName "custom_transmogrification_sets" -tableNameFile "custom_transmogrification_sets" -columnName "Owner" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
		Backup-TableData -tableName "custom_unlocked_appearances" -tableNameFile "custom_unlocked_appearances" -columnName "account_id" -value $accountID -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
	}
########## Reagent Bank Data
	if (Table-Exists -TableName "custom_reagent_bank" -ConnectionName "CharConn") {
		Backup-TableData -tableName "custom_reagent_bank" -tableNameFile "custom_reagent_bank" -columnName "character_id" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
	}
########## Character Settings data
	if (Table-Exists -TableName "character_settings" -ConnectionName "CharConn") {
		Backup-TableData -tableName "character_settings" -tableNameFile "character_settings" -columnName "guid" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -XP $XP -Money $Money -Honor $Honor -AccountName $AccountName -CurrentDate $CurrentDate
	}
##########
    # Delete empty SQL files
    Get-ChildItem -Path $CharacterBackupDir -Filter "*.sql" -Recurse | Where-Object { $_.Length -eq 0 } | Remove-Item
	
}
########################################

########################################
function Backup-Character-Main {
	# Open database connections
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "AuthConn"
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "CharConn"
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseWorld -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "WorldConn"

    try {
		Write-Host "(Press CTRL + C to exit)" -ForegroundColor Cyan
		$userNameToSearch = Read-Host "`nEnter account name"
		
		$id = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id FROM account WHERE username = @username" -Parameters @{ username = $userNameToSearch }
########################################
		if ($id) {
			Write-Host "`nID for username '$userNameToSearch': $($id.id)" -ForegroundColor Cyan
			
			$characterData = Invoke-SqlQuery -ConnectionName "CharConn" -Query @"
				SELECT guid, account, name, race, class, gender, level, xp, health, power1, money, skin, face, hairStyle, hairColor, facialStyle, bankSlots, equipmentCache, ammoId, arenapoints, totalHonorPoints, totalKills, creation_date, map, zone
				FROM characters 
				WHERE account = @id
"@ -Parameters @{ id = $id.id }

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
							
							$backupDirFull = "$CharacterBackupDir\$userNameToSearch\$CurCharName ($CurrentDate) - $CurCharRace $CurCharClass $CurCharGender LV$CurCharLevel"
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
							Backup-Character -characterId $selectedCharacter.guid -characterName $selectedCharacter.name -accountID $id.id -Race $selectedCharacter.race -Class $selectedCharacter.class -Gender $selectedCharacter.gender -Level $selectedCharacter.level -XP $selectedCharacter.xp -Money $selectedCharacter.money -Honor $selectedCharacter.totalHonorPoints -AccountName $userNameToSearch -CurrentDate $CurrentDate
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
								
								$backupDirFull = "$CharacterBackupDir\$userNameToSearch\$CurCharName ($CurrentDate) - $CurCharRace $CurCharClass $CurCharGender LV$CurCharLevel"
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
								Backup-Character -characterId $character.guid -characterName $character.name -accountID $id.id -Race $character.race -Class $character.class -Gender $character.gender -Level $character.level -XP $character.xp -Money $character.money -Honor $character.totalHonorPoints -AccountName $userNameToSearch -CurrentDate $CurrentDate
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
########################################
#endregion
########################################
#region Backup-Guilds
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
        [string]$BankMoneyConverted,
        [string]$CurrentDate
    )

    Write-Host "`nBacking up guild $GuildName..." -ForegroundColor Cyan
    $backupDirFull = "$GuildBackupDir\$GuildName ($CurrentDate) - $LeaderName"
		
########### Create guild_members.json
    $memberGuids = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT guid FROM guild_member WHERE guildid = @GuildID" -Parameters @{GuildID = $GuildID}
    $memberMapping = @{}
    if ($memberGuids) {
        foreach ($member in $memberGuids) {
            $memberName = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT name FROM characters WHERE guid = @guid" -Parameters @{guid = $member.guid}
            if ($memberName) {
                $memberMapping[($member.guid).ToString()] = $memberName.name
            }
        }
    }
    $memberMappingJson = $memberMapping | ConvertTo-Json
    $memberMappingJson | Out-File -FilePath "$backupDirFull\guild_members.json" -Encoding utf8
	
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
	if (Table-Exists -TableName "guild_house" -ConnectionName "CharConn") {
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
    param (
        [switch]$AllGuilds
    )
	# Open database connections
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "CharConn"

    $query = "SELECT g.*, c.name as leader_name 
              FROM guild g 
              LEFT JOIN characters c ON g.leaderguid = c.guid"
    try {
        $guildData = Invoke-SqlQuery -ConnectionName "CharConn" -Query $query
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
                foreach ($guild in $guildData) {
                    $CreateDateConverted = (Get-Date (ConvertFromUnixTime -unixTime $guild.createdate)).ToString("dd/MM/yyyy HH:mm:ss")
                    $BankMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $guild.BankMoney
                    $CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
                    Backup-Guild -GuildID $guild.guildid `
                                -GuildName $guild.name `
                                -LeaderGUID $guild.leaderguid `
                                -CreateDate $guild.createdate `
                                -BankMoney $guild.BankMoney `
                                -LeaderName $guild.leader_name `
                                -CreateDateConverted $CreateDateConverted `
                                -BankMoneyConverted $BankMoneyConverted `
                                -CurrentDate $CurrentDate
                }
                $stopwatch.Stop()
                Write-Host "All Guilds backed up in $($stopwatch.Elapsed.TotalSeconds) seconds." -ForegroundColor Green
                return
            }
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
                        Backup-Guild -GuildID $selectedGuild.guildid `
                                    -GuildName $selectedGuild.name `
                                    -LeaderGUID $selectedGuild.leaderguid `
                                    -CreateDate $selectedGuild.createdate `
                                    -BankMoney $selectedGuild.BankMoney `
                                    -LeaderName $selectedGuild.leader_name `
                                    -CreateDateConverted $CreateDateConverted `
                                    -BankMoneyConverted $BankMoneyConverted `
                                    -CurrentDate $CurrentDate

                        $stopwatch.Stop()
                        Write-Host "Backup done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
########################################
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
########################################
#endregion
########################################
#region Restore-Characters
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
		if (Table-Exists -TableName "characters" -ConnectionName "CharConn") {
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
			
			Write-Host "`nRestoring character $($characterName)..." -ForegroundColor Cyan
	
			#Execute the query
			Execute-Query -query "$modifiedSqlQuery" -tablename "characters" -ConnectionName "CharConn"
############################################ PROCESS TABLES IN $TABLES ARRAY
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
				@("custom_reagent_bank", 0),          #new
				@("character_settings", 0)          #new 27-12-2025
			)
			
			Write-Host "Importing character data..." -ForegroundColor Cyan
			# Loop through each table in the array
			foreach ($entry in $tables) {
				# Extract the table name and the column number
				$table = $entry[0]
				$columnIndex = $entry[1]
	
				# Path to the .sql file
				$sqlFilePath = "$CharacterBackupDir\*\$folder\$table.sql"
				
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
							
							# Replace the value at the target column index
							$values[$columnIndex] = $newGuid
							
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
				$sqlFilePath = "$CharacterBackupDir\*\$folder\character_homebind.sql"
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
						$modifiedSqlQuery = "INSERT INTO `character_homebind` VALUES " + ($modifiedRows -join ",") + ";"
						
						#Execute the query
						Execute-Query -query "$modifiedSqlQuery" -tablename "character_homebind" -ConnectionName "CharConn"
					} else {
						Write-Host "Table 'character_homebind' does not exist, skipping restore for this table." -ForegroundColor Red
					}
				}
############################################ PROCESS PET TABLES
				$sqlFilePath = "$CharacterBackupDir\*\$folder\character_pet.sql"
				
				if (Test-Path -Path $sqlFilePath) {
					if (Table-Exists -TableName "character_pet" -ConnectionName "CharConn") {
						Write-Host "Importing pet data..." -ForegroundColor Cyan
						
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
							
							$sqlFilePath = "$CharacterBackupDir\*\$folder\$table.sql"
							
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
############################################ PROCESS ITEM_INSTANCE - guid[0], owner_guid[2]
			$sqlFilePath = "$CharacterBackupDir\*\$folder\item_instance.sql"
			
			if (Test-Path -Path $sqlFilePath) {
				if (Table-Exists -TableName "item_instance" -ConnectionName "CharConn") {
					Write-Host "Importing character items..." -ForegroundColor Cyan
					
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
					
############################################ PROCESS CHARACTER_INVENTORY - guid[0], bag[1], item[3]
					$sqlFilePath = "$CharacterBackupDir\*\$folder\character_inventory.sql"
					
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
								$matchingGuid = $guidMappingpItems | Where-Object { $_.OldGuid -eq $currentValue }
								
								# If a match is found, replace the old GUID with the new GUID
								if ($matchingGuid) {
									$values[3] = $matchingGuid.NewGuid
								}
############################################ THIS IS FOR BAG GUID
								# Get the current value in the target column (adjust for 0-based index)
								$currentValue = $values[1]
								
								# Check if the current value matches an old GUID in the mapping
								$matchingGuid = $guidMappingpItems | Where-Object { $_.OldGuid -eq $currentValue }
								
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
							$modifiedSqlQuery = "INSERT INTO `character_inventory` VALUES " + ($modifiedRows -join ",") + ";"
						
							# Output the modified SQL to verify
							# Write-Host "`nModified SQL: $modifiedSqlQuery"
							
							#Execute the query
							Execute-Query -query "$modifiedSqlQuery" -tablename "character_inventory" -ConnectionName "CharConn"
						} else {
							Write-Host "Table 'character_inventory' does not exist, skipping restore for this table." -ForegroundColor Red
						}
					}
############################################ 
	
############################################ PROCESS CUSTOM_TRANSMOGRIFICATION - GUID[0], Owner[2]
					$sqlFilePath = "$CharacterBackupDir\*\$folder\custom_transmogrification.sql"
					
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
								$matchingGuid = $guidMappingpItems | Where-Object { $_.OldGuid -eq $currentValue }
								
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
							$modifiedSqlQuery = "INSERT INTO `custom_transmogrification` VALUES " + ($modifiedRows -join ",") + ";"
						
							# Output the modified SQL to verify
							# Write-Host "`nModified SQL: $modifiedSqlQuery"
							
							#Execute the query
							Execute-Query -query "$modifiedSqlQuery" -tablename "custom_transmogrification" -ConnectionName "CharConn"
						} else {
							Write-Host "Table 'custom_transmogrification' does not exist, skipping restore for this table." -ForegroundColor Red
						}
						
						
############################################ PROCESS CUSTOM_TRANSMOGRIFICATION_SETS - Owner[0], PresetID[1]
						$sqlFilePath = "$CharacterBackupDir\*\$folder\custom_transmogrification_sets.sql"
						
						if (Test-Path -Path $sqlFilePath) {
							if (Table-Exists -TableName "custom_transmogrification_sets" -ConnectionName "CharConn") {
								Write-Host "Importing transmog sets..." -ForegroundColor Cyan
								
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
							} else {
								Write-Host "Table 'custom_transmogrification_sets' does not exist, skipping restore for this table." -ForegroundColor Red
							}
						}
	
############################################ PROCESS CUSTOM_UNLOCKED_APPEARANCES - account_id[0], item_template_id[1]
						$sqlFilePath = "$CharacterBackupDir\*\$folder\custom_unlocked_appearances.sql"
						
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
							} else {
								Write-Host "Table 'custom_unlocked_appearances' does not exist, skipping restore for this table." -ForegroundColor Red
							}
						}
############################################ END TRANSMOG BRACKET
					}
############################################ 
	
############################################ PROCESS character_equipmentsets - guid[0], setguid[1]
					$sqlFilePath = "$CharacterBackupDir\*\$folder\character_equipmentsets.sql"
					
					if (Test-Path -Path $sqlFilePath) {
						if (Table-Exists -TableName "character_equipmentsets" -ConnectionName "CharConn") {
							Write-Host "Importing character equipment sets..." -ForegroundColor Cyan
							
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
			$UsernameID = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id FROM account WHERE username = @userNameToSearch;" -Parameters @{ userNameToSearch = $userNameToSearch }
	
			if ($UsernameID) {
				$AccountId = $UsernameID.id
				Write-Host "`nID for username '$userNameToSearch': $AccountId" -ForegroundColor Cyan
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
				Write-Host "`nImporting up all characters from list." -ForegroundColor Cyan
				
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
#endregion
########################################
#region Restore-Guilds
########################################
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
		
		Write-Host "Restoring guild $GuildName..." -ForegroundColor Cyan
		# Write-Host "The file exists: $sqlFilePath"
############################
		# Get the maximum guildid from the characters table
		$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(guildid) AS MaxGuildID FROM guild"
		
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
		$guidMapping = @{}
        $guildMembersFile = "$GuildBackupDir\$folder\guild_members.json"
        if (Test-Path $guildMembersFile) {
            $guildMembersJson = Get-Content $guildMembersFile | ConvertFrom-Json
            foreach ($property in $guildMembersJson.psobject.Properties) {
                $oldGuid = $property.Name
                $characterName = $property.Value
                $newCharGuid = Check-Character -characterNameToSearch $characterName
                if ($newCharGuid) {
                    $guidMapping[$oldGuid] = $newCharGuid
                } else {
                    Write-Host "Character '$characterName' not found on the target server. Skipping member." -ForegroundColor Yellow
                }
            }
        }
#############################
        $pattern = "(?<=\().*?(?=\))"
############################# Process guild.sql
		# guild = guildid[0], PlayerGuid[2]
        $sqlContent = Get-Content -Path $sqlFilePath -Raw
        $matches = [regex]::Matches($sqlContent, $pattern)
        $modifiedRows = @()
        foreach ($match in $matches) {
            $values = $match.Value -split ","
            $values[0] = $newGuildID
            $values[2] = $characterID # Set leader
            $modifiedRows += "(" + ($values -join ",") + ")"
        }
        $modifiedSqlQuery = "INSERT INTO `guild` VALUES " + ($modifiedRows -join ",") + ";"
		# Output the modified SQL to verify
		# Write-Host "`nModified SQL: $modifiedSqlQuery"
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
			
			$sqlFilePath = "$GuildBackupDir\$folder\$table.sql"
			if (Test-Path $sqlFilePath) {
				$sqlContent = Get-Content -Path $sqlFilePath -Raw
				$matches = [regex]::Matches($sqlContent, $pattern)
				$modifiedRows = @()
				foreach ($match in $matches) {
					$values = $match.Value -split ","
					$values[$columnIndex] = $columnIndexValue
					$modifiedRows += "(" + ($values -join ",") + ")"
				}
				$modifiedSqlQuery = "INSERT INTO $table VALUES " + ($modifiedRows -join ",") + ";"
				# Output the modified SQL to verify
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				Execute-Query -query $modifiedSqlQuery -tablename $table -ConnectionName "CharConn"
			}
		}
############################### Process guild_member.sql
        $sqlFilePath = "$GuildBackupDir\$folder\guild_member.sql"
        if (Test-Path $sqlFilePath) {
            $sqlContent = Get-Content -Path $sqlFilePath -Raw
            $matches = [regex]::Matches($sqlContent, $pattern)
            $modifiedRows = @()
            foreach ($match in $matches) {
                $values = $match.Value -split ","
                $oldMemberGuid = $values[1]
                if ($guidMapping.ContainsKey($oldMemberGuid)) {
                    $values[0] = $newGuildID
                    $values[1] = $guidMapping[$oldMemberGuid]
                    $modifiedRows += "(" + ($values -join ",") + ")"
				#else set it as guild leader ID
                } else {
                    $values[0] = $newGuildID
                    $values[1] = $characterID
                    $modifiedRows += "(" + ($values -join ",") + ")"
				}
            }
            if ($modifiedRows.Count -gt 0) {
                $modifiedSqlQuery = "INSERT INTO `guild_member` VALUES " + ($modifiedRows -join ",") + ";"
                Execute-Query -query $modifiedSqlQuery -tablename "guild_member" -ConnectionName "CharConn"
            }
        }
############################# Process guild_bank_eventlog.sql
		# guild_eventlog = guildid[0], PlayerGuid[3]
        $sqlFilePath = "$GuildBackupDir\$folder\guild_bank_eventlog.sql"
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
            if ($modifiedRows.Count -gt 0) {
                $modifiedSqlQuery = "INSERT INTO `guild_bank_eventlog` VALUES " + ($modifiedRows -join ",") + ";"
                Execute-Query -query $modifiedSqlQuery -tablename "guild_bank_eventlog" -ConnectionName "CharConn"
            }
        }
############################# Process guild_eventlog.sql
		# guild_bank_eventlog - guildid[0], PlayerGuid[3], PlayerGuid[4]
        $sqlFilePath = "$GuildBackupDir\$folder\guild_eventlog.sql"
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
            if ($modifiedRows.Count -gt 0) {
                $modifiedSqlQuery = "INSERT INTO `guild_eventlog` VALUES " + ($modifiedRows -join ",") + ";"
                Execute-Query -query $modifiedSqlQuery -tablename "guild_eventlog" -ConnectionName "CharConn"
            }
        }
		
############################# Process guild_member_withdraw.sql
		$sqlFilePath = "$GuildBackupDir\$folder\guild_member_withdraw.sql"
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
					
					if ($modifiedRows.Count -gt 0) {
						$modifiedSqlQuery = "INSERT INTO `guild_member_withdraw` VALUES " + ($modifiedRows -join ",") + ";"
						Execute-Query -query $modifiedSqlQuery -tablename "guild_member_withdraw" -ConnectionName "CharConn"
					}
				#else set it as guild leader ID
				} else {
					$values[0] = $characterID
					$modifiedRows += "(" + ($values -join ",") + ")"
					
					if ($modifiedRows.Count -gt 0) {
						$modifiedSqlQuery = "INSERT INTO `guild_member_withdraw` VALUES " + ($modifiedRows -join ",") + ";"
						Execute-Query -query $modifiedSqlQuery -tablename "guild_member_withdraw" -ConnectionName "CharConn"
					}
				}
			}
		}
############################ PROCESS ITEM_INSTANCE - alter guid[0] taking into account existing items
		$sqlFilePath = "$GuildBackupDir\$folder\item_instance.sql"
		
		if (Test-Path -Path $sqlFilePath) {
			if (Table-Exists -TableName "item_instance" -ConnectionName "CharConn") {
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
					$values[2] = $newGuildID
					
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
				Execute-Query -query $modifiedSqlQuery -tablename "item_instance" -ConnectionName "CharConn"
				
################################ PROCESS GUILD_BANK_ITEM - alter guidid[0] and item_guid[3]
				$sqlFilePath = "$GuildBackupDir\$folder\guild_bank_item.sql"
				
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
							$matchingGuid = $guidMappingpItems | Where-Object { $_.OldGuid -eq $currentValue }
							
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
						$modifiedSqlQuery = "INSERT INTO `guild_bank_item` VALUES " + ($modifiedRows -join ",") + ";"
				
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
		$sqlFilePath = "$GuildBackupDir\$folder\guild_house.sql"
		
		if (Test-Path -Path $sqlFilePath) {
			if (Table-Exists -TableName "guild_house" -ConnectionName "CharConn") {
				# Get the maximum GUID from the characters table
				$maxGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT MAX(id) AS MaxGuid FROM guild_house"
				
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
				$modifiedSqlQuery = "INSERT INTO `guild_house` VALUES " + ($modifiedRows -join ",") + ";"
				
				# Output the modified SQL to verify
				# Write-Host "`nModified SQL: $modifiedSqlQuery"
				
				#Execute the query
				Execute-Query -query $modifiedSqlQuery -tablename "guild_house" -ConnectionName "CharConn"
############################################ PROCESS CREATURE (this is for guild house NPCs) - alter guid[0] taking into account existing creatures
				$sqlFilePath = "$GuildBackupDir\$folder\creature.sql"
				
				if (Test-Path -Path $sqlFilePath) {
					if (Table-Exists -TableName "creature" -ConnectionName "WorldConn") {
						# Get the maximum GUID from the characters table
						$maxGuidResult = Invoke-SqlQuery -ConnectionName "WorldConn" -Query "SELECT MAX(guid) AS MaxGuid FROM creature"
						
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
						$modifiedSqlQuery = "INSERT INTO `creature` VALUES " + ($modifiedRows -join ",") + ";"
						
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
########################################
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
		
		$GuildName = ($selectedFolder -split " - ")[0]
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
			
			$characterGuid = Check-Character -characterNameToSearch $characterNameToSearch
			
			if ($characterGuid){
				#check if character already is a member of a guild
				$FoundRow = Row-Exists -TableName "guild_member" -RowName "guid" -RowValue $characterGuid -ConnectionName "CharConn"
				if ($FoundRow){
					Write-Host "Character $characterNameToSearch already is a member of a guild. Try again." -ForegroundColor Red
				} else {
					Restore-Guild -folder $selectedFolder -character $characterNameToSearch -characterID $characterGuid -GuildName $GuildName
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
	Close-SqlConnection -ConnectionName "WorldConn"
}
###################################################
#endregion
########################################
function Backup-All-Accounts-Main {
    # Open database connections
    Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "AuthConn"
    Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "CharConn"
    Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseWorld -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "WorldConn"

    try {
        $accounts = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id, username FROM account"
        if ($accounts) {
			if (-not ([string]::IsNullOrEmpty($AccountNameRegexFilter))) {
				$accounts = $accounts | Where-Object { $_.username -match $AccountNameRegexFilter }
			}
            Write-Host "Found $($accounts.Count) accounts. Starting backup process..." -ForegroundColor Green
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            foreach ($account in $accounts) {
                $accountId = $account.id
                $accountName = $account.username
                Write-Host "`nBacking up account: $accountName (ID: $accountId)" -ForegroundColor Cyan
                
                $backupDirFullAccount = "$CharacterBackupDir\$accountName"
                if (-not (Test-Path $backupDirFullAccount)) {
                    New-Item -Path $backupDirFullAccount -ItemType Directory | Out-Null
                }

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

                $characterData = Invoke-SqlQuery -ConnectionName "CharConn" -Query @"
                    SELECT guid, account, name, race, class, gender, level, xp, health, power1, money, skin, face, hairStyle, hairColor, facialStyle, bankSlots, equipmentCache, ammoId, arenapoints, totalHonorPoints, totalKills, creation_date, map, zone
                    FROM characters 
                    WHERE account = @id
"@ -Parameters @{ id = $accountId }

                if ($characterData) {
					if (-not ([string]::IsNullOrEmpty($CharacterNameRegexFilter))) {
						$characterData = $characterData | Where-Object { $_.name -match $CharacterNameRegexFilter }
					}
                    Write-Host "Found $($characterData.Count) characters for account $accountName." -ForegroundColor Green
                    foreach ($character in $characterData) {
                        $CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
                        $CurCharMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $character.money
                        $CurCharRace = GetCharacterRaceString -Race $character.race
                        $CurCharClass = GetCharacterClassString -Class $character.class
                        $CurCharGender = GetCharacterGenderString -Gender $character.gender
                        $CurCharName = $character.name
                        $CurCharLevel = $character.level

                        $backupDirFull = "$CharacterBackupDir\$accountName\$CurCharName ($CurrentDate) - $CurCharRace $CurCharClass $CurCharGender LV$CurCharLevel"
                        if (-not (Test-Path $backupDirFull)) {
                            New-Item -Path $backupDirFull -ItemType Directory | Out-Null
                        }

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
                        Backup-Character -characterId $character.guid -characterName $character.name -accountID $accountId -Race $character.race -Class $character.class -Gender $character.gender -Level $character.level -XP $character.xp -Money $character.money -Honor $character.totalHonorPoints -AccountName $accountName -CurrentDate $CurrentDate
                    }
                } else {
                    Write-Host "No characters found for account '$accountName'" -ForegroundColor Yellow
                }
            }
            $stopwatch.Stop()
            Write-Host "`nAll accounts and characters backed up in $($stopwatch.Elapsed.TotalSeconds) seconds." -ForegroundColor Green
        } else {
            Write-Host "No accounts found in the database." -ForegroundColor Red
        }
    } catch {
        Write-Host "An error occurred (line $($_.InvocationInfo.ScriptLineNumber)): $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Close-SqlConnection -ConnectionName "AuthConn"
        Close-SqlConnection -ConnectionName "CharConn"
        Close-SqlConnection -ConnectionName "WorldConn"
    }
}
############################################################
function Restore-All-Accounts-Main {
    # Create SimplySql connections
    Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "AuthConn"
    Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "CharConn"
####################################################################
    try {
        $accountFolders = Get-ChildItem -Path $CharacterBackupDir -Directory
        if ($accountFolders.Count -eq 0) {
            Write-Host "No account backups found in '$CharacterBackupDir'." -ForegroundColor Red
            return
        }

        Write-Host "Found $($accountFolders.Count) account backups. Starting restore process..." -ForegroundColor Cyan
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
####################################################################
        foreach ($accountFolder in $accountFolders) {
            $accountName = $accountFolder.Name
            Write-Host "`nRestoring account: $accountName" -ForegroundColor Cyan

            # Check if account exists
            $accountResult = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id FROM account WHERE username = @username" -Parameters @{ username = $accountName } -WarningAction SilentlyContinue
            $accountId = $null
####################################################################
            if ($accountResult) {
                $accountId = $accountResult.id
                Write-Host "Account '$accountName' already exists with ID $accountId." -ForegroundColor Green
####################################################################
            } else {
                Write-Host "Account '$accountName' does not exist. Creating it..." -ForegroundColor Cyan
                $accountSqlFile = Join-Path $accountFolder.FullName "_account.sql"
                if (Test-Path $accountSqlFile) {
					
					# Get the maximum GUID from the characters table
					$maxIDResult = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT MAX(id) AS MaxID FROM account"
					
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
####################################################################
					$accountAccessSqlFile = Join-Path $accountFolder.FullName "_account_access.sql"
					if (Test-Path $accountAccessSqlFile) {
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

            Write-Host "Found $($characterFolders.Count) character backups for account '$accountName'." -ForegroundColor Cyan
            foreach ($characterFolder in $characterFolders) {
                Restore-Character -folder $characterFolder.Name -account $accountName -accountID $accountId
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
    }
}
####################################################################
function Backup-All-Guilds-Main-Wrapper {
    Backup-Guild-Main -AllGuilds
}
####################################################################
function Restore-All-Guilds-Main {
    Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "CharConn"
    Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database $TargetDatabaseWorld -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "WorldConn"
####################################################################
    try {
        $guildFolders = Get-ChildItem -Path $GuildBackupDir -Directory
        if ($guildFolders.Count -eq 0) {
            Write-Host "No guild backups found in '$GuildBackupDir'." -ForegroundColor Yellow
            return
        }

        Write-Host "Found $($guildFolders.Count) guild backups. Starting restore process..." -ForegroundColor Cyan
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
####################################################################
        foreach ($folder in $guildFolders) {
            $folderName = $folder.Name
            $guildName = ($folderName -split " - ")[0]
            $leaderName = ($folderName -split " - ")[1]

            Write-Host "`nStarting restoring guild: $guildName, Leader: $leaderName" -ForegroundColor Cyan

            $characterGuidResult = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT guid FROM characters WHERE name = @name" -Parameters @{ name = $leaderName } -WarningAction SilentlyContinue
            if ($characterGuidResult) {
				Write-Host "Found guild leader in database: $leaderName" -ForegroundColor Green
                $characterGuid = $characterGuidResult.guid
                $isGuildMember = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT guid FROM guild_member WHERE guid = @guid" -Parameters @{ guid = $characterGuid } -WarningAction SilentlyContinue
                if ($isGuildMember) {
                    Write-Host "Character '$leaderName' is already in a guild. Skipping restore for guild '$guildName'." -ForegroundColor Yellow
                    continue
                }
                Restore-Guild -folder $folderName -character $leaderName -characterID $characterGuid -GuildName $guildName
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
    }
}
###################################################