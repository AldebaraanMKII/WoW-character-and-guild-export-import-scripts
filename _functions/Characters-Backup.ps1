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
	[console]::beep()
}
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
				Invoke-Expression $mysqldumpCommand 2>$null
				
				# Backup account access details
				$backupFile = "$backupDirFullAccount\_account_access.sql"
				$whereClause = "id=$accountId"
				$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --hex-blob --where=`"$whereClause`" `"$SourceDatabaseAuth`" `"account_access`" > `"$backupFile`""
				Invoke-Expression $mysqldumpCommand 2>$null
				
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
			# Backup creature data
			$TableName = "creature"
			$backupFile = "$backupDirFullAccount\$TableName.sql"
			$whereClause = "id1 IN (601026, 190010, 300000, 290011, 601015, 200001, 200002, 190000, 601016, 93080, 199999, 55333, 100000, 500030, 98888)"
			$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --hex-blob --where=`"$whereClause`" `"$SourceDatabaseWorld`" `"$TableName`" > `"$backupFile`""
			Invoke-Expression $mysqldumpCommand 2>$null
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
#endregion
#################################################################