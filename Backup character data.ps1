
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
        [string]$AccountName
    )
    
    Write-Host "`nBacking up character $characterName..." -ForegroundColor Yellow
    
	$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
	
    # List of tables to back up
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
        Backup-TableData -tableName $table -tableNameFile $table -columnName "guid" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
    }
    
    # Pet Data
    $petsData = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT id, entry, level, name FROM character_pet WHERE owner = @owner" -Parameters @{ owner = $characterId }
    
    if ($petsData) {
        foreach ($pet in $petsData) {
            $petEntryName = Invoke-SqlQuery -ConnectionName "WorldConn" -Query "SELECT name FROM creature_template WHERE entry = @PetEntry" -Parameters @{ PetEntry = $pet.entry }
            Write-Host "Found pet: (ID: $($pet.id)), $($pet.name), $($petEntryName.name), LV $($pet.level)" -ForegroundColor Yellow
        }
        
        Backup-TableData -tableName "character_pet" -tableNameFile "character_pet" -columnName "owner" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
        
        $petIds = $petsData | Select-Object -ExpandProperty id
        
        Backup-TableData-Array -tableName "pet_aura" -tableNameFile "pet_aura" -columnName "guid" -values $petIds -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
        Backup-TableData-Array -tableName "pet_spell" -tableNameFile "pet_spell" -columnName "guid" -values $petIds -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
        Backup-TableData-Array -tableName "pet_spell_cooldown" -tableNameFile "pet_spell_cooldown" -columnName "guid" -values $petIds -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
    }
    
    # Item Data
    Backup-TableData -tableName "item_instance" -tableNameFile "item_instance" -columnName "owner_guid" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
    
    # Mail Data
    Backup-TableData -tableName "mail" -tableNameFile "mail_receiver" -columnName "receiver" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
    
    # Transmog Data
    Backup-TableData -tableName "custom_transmogrification" -tableNameFile "custom_transmogrification" -columnName "Owner" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
    Backup-TableData -tableName "custom_transmogrification_sets" -tableNameFile "custom_transmogrification_sets" -columnName "Owner" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
    Backup-TableData -tableName "custom_unlocked_appearances" -tableNameFile "custom_unlocked_appearances" -columnName "account_id" -value $accountID -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
    
    # Reagent Bank Data
    Backup-TableData -tableName "custom_reagent_bank" -tableNameFile "custom_reagent_bank" -columnName "character_id" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level -AccountName $AccountName -CurrentDate $CurrentDate
    
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

    Write-Host "(Press CTRL + C to exit)" -ForegroundColor Yellow
    $userNameToSearch = Read-Host "`nEnter account name"
    
    $id = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id FROM account WHERE username = @username" -Parameters @{ username = $userNameToSearch }
    # $id = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT id FROM account WHERE username = @username" -SqlParameterCollection @{ username = $userNameToSearch }
    
    if ($id) {
        Write-Host "`nID for username '$userNameToSearch': $($id.id)" -ForegroundColor Yellow
        
        $characterData = Invoke-SqlQuery -ConnectionName "CharConn" -Query @"
            SELECT guid, name, race, class, gender, level, money, totalHonorPoints, creation_date 
            FROM characters 
            WHERE account = @id
"@ -Parameters @{ id = $id.id }
        
        if ($characterData) {
            $exitScript = $false
            while (-not $exitScript) {
                Write-Host "`nFound $($characterData.Count) Characters." -ForegroundColor Green
                Write-Host "`nCharacter List:" -ForegroundColor Green
                $index = 1
                
                foreach ($character in $characterData) {
			
			$characterId = $character.guid
			$characterName = $character.name
			$Race = $character.race
			switch ($Race) {
				1 { $Race = "Human" }
				2 { $Race = "Orc" }
				3 { $Race = "Dwarf" }
				4 { $Race = "Night Elf" }
				5 { $Race = "Undead" }
				6 { $Race = "Tauren" }
				7 { $Race = "Gnome" }
				8 { $Race = "Troll" }
				10 { $Race = "Blood Elf" }
				11 { $Race = "Draenei" }
				default { $Race = "Unknown Race" }
			}
			
			$Class = $character.class
			switch ($Class) {
				1 { $Class = "Warrior" }
				2 { $Class = "Paladin" }
				3 { $Class = "Hunter" }
				4 { $Class = "Rogue" }
				5 { $Class = "Priest" }
				6 { $Class = "Death Knight" }
				7 { $Class = "Shaman" }
				8 { $Class = "Mage" }
				9 { $Class = "Warlock" }
				11 { $Class = "Druid" }
				default { $Class = "Unknown Class" }
			}
			
			$Gender = $character.gender
			switch ($Gender) {
				0 { $Gender = "Male" }
				1 { $Gender = "Female" }
				default { $Gender = "Unknown Gender" }
			}
			
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
                
                if ($choice -match '^\d+$') {
                    $choice = [int]$choice
                    
                    if ($choice -ge 1 -and $choice -le $characterData.Count) {
                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        $selectedCharacter = $characterData[$choice - 1]
                        Backup-Character -characterId $selectedCharacter.guid `
                                       -characterName $selectedCharacter.name `
                                       -accountID $id.id `
                                       -Race $selectedCharacter.race `
                                       -Class $selectedCharacter.class `
                                       -Gender $selectedCharacter.gender `
                                       -Level $selectedCharacter.level `
                                       -AccountName $userNameToSearch
                        $stopwatch.Stop()
                        Write-Host "Backup done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
                    }
                    elseif ($choice -eq $index) {
                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        foreach ($character in $characterData) {
                            Backup-Character -characterId $character.guid `
                                           -characterName $character.name `
                                           -accountID $id.id `
                                           -Race $character.race `
                                           -Class $character.class `
                                           -Gender $character.gender `
                                           -Level $character.level `
										   -AccountName $userNameToSearch
                        }
                        $stopwatch.Stop()
                        Write-Host "All characters backed up in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..." -ForegroundColor Green
                    }
                    elseif ($choice -eq ($index + 1)) {
                        Write-Host "Going back..." -ForegroundColor Yellow
                        break
                    }
                    elseif ($choice -eq ($index + 2)) {
                        Write-Host "Exiting script..." -ForegroundColor Yellow
                        $exitScript = $true
                    }
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
	# Close all connections
	Close-SqlConnection -ConnectionName "AuthConn"
	Close-SqlConnection -ConnectionName "CharConn"
	Close-SqlConnection -ConnectionName "WorldConn"
}
########################################
########################################
