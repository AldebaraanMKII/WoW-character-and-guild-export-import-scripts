

# Define connection details
$serverName = "127.0.0.1"
$port = 3306
$username = "root"
$password = "ascent"
$database_auth = "acore_auth"
$database_characters = "acore_characters"
$database_world = "acore_world"

# Paths to executables
$mysqldumpPath = "H:\My Repack\mysql\bin\mysqldump.exe"  # path to mysqldump executable
$mysqlPath = "H:\My Repack\mysql\bin\mysql.exe"   # path to mysql executable

#backup directory for sqls
$backupDir = "./character_data"

# Load MySQL assembly
# this version of MySql.Data needs to be 8.x.x and net 8.0 to work with powershell 7.4.x
#try {
#   Add-Type -Path "./MySql.Data.dll" 2>$null
#} catch {
#
#}

# Create a connection string for the acore_auth database
$connectionStringAuth = "Server=$serverName;Port=$port;Database=$database_auth;User ID=$username;Password=$password;"
		
# Create and open a MySQL connection to acore_auth
$connectionAuth = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionStringAuth)

# Create a connection string for the acore_world database
$connectionStringWorld = "Server=$serverName;Port=$port;Database=$database_world;User ID=$username;Password=$password;"

# Create and open a MySQL connection to acore_world
$connectionWorld = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionStringWorld)

# Create a connection string for the acore_characters database
$connectionStringCharacters = "Server=$serverName;Port=$port;Database=$database_characters;User ID=$username;Password=$password;"
				
# Create and open a MySQL connection to acore_characters
$connectionCharacters = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionStringCharacters)
				
				
############# UTILITY FUNCTIONS
function ConvertToGoldSilverCopper {
    param (
        [int]$MoneyAmount
    )
		
		if ($MoneyAmount -gt 0) {
				# Calculate gold, silver, and copper
				$gold = [math]::Floor($MoneyAmount / 10000)
				$remainingAfterGold = $MoneyAmount % 10000
		
				$silver = [math]::Floor($remainingAfterGold / 100)
				$copper = $remainingAfterGold % 100
		
				# Build the result string
				$result = ""
		
				if ($gold -gt 0) {
						$result += "$($gold)g"
				}
		
				if ($silver -gt 0) {
						if ($result -ne "") {
								$result += ", "
						}
						$result += "$($silver)s"
				}
		
				if ($copper -gt 0) {
						if ($result -ne "") {
								if ($silver -gt 0) {
										$result += " and "
								} else {
										$result += ", "
								}
						}
						$result += "$($copper)c"
				}
		
				# Return the result
				return $result
		}
		else {
				return 0
		}
}
########################################
########### BACKUP FUNCTIONS
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
        [string]$Level
    )
################ Assign strings to things like race and class
		switch ($Race) {
				1 { $Race = "Human" }
				2 { $Race = "Orc" }
				3 { $Race = "Dwarf" }
				4 { $Race = "Night_Elf" }
				5 { $Race = "Undead" }
				6 { $Race = "Tauren" }
				7 { $Race = "Gnome" }
				8 { $Race = "Troll" }
				10 { $Race = "Blood_Elf" }
				11 { $Race = "Draenei" }
				default { $Race = "Unknown_Race" }
		}
		
		switch ($Class) {
				1 { $Class = "Warrior" }
				2 { $Class = "Paladin" }
				3 { $Class = "Hunter" }
				4 { $Class = "Rogue" }
				5 { $Class = "Priest" }
				6 { $Class = "Death_Knight" }
				7 { $Class = "Shaman" }
				8 { $Class = "Mage" }
				9 { $Class = "Warlock" }
				11 { $Class = "Druid" }
				default { $Class = "Unknown_Class" }
		}
		
		switch ($Gender) {
				0 { $Gender = "Male" }
				1 { $Gender = "Female" }
				default { $Gender = "Unknown_Gender" }
		}
################################
    # Create a backup filename
		# e.g. Boya - Orc Rogue Female LV1
    $backupDirFull = "$backupDir\$userNameToSearch\$characterName - $Race $Class $Gender LV$Level"
		# Create folders if they do not exist
		if (-not (Test-Path $backupDirFull)) {
				New-Item -Path $backupDirFull -ItemType Directory | Out-Null
		}
		
		$backupFile = "$backupDirFull\$tableNameFile.sql"

    # Define the mysqldump command
    $mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$serverName`" --port=`"$port`" --user=`"$username`" --password=`"$password`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$columnName=$value`" `"$database_characters`" `"$tableName`" > `"$backupFile`""

    # Debug: Output the command for inspection
    # Write-Host "Command: $mysqldumpCommand"

    # Run the mysqldump command
    Invoke-Expression $mysqldumpCommand

    if ($LASTEXITCODE -eq 0) {
        # Write-Host "Successfully backed up $tableName"
    } else {
        Write-Host "Error backing up data from $tableName"
    }
}


##############################################################################
function Backup-TableData-Array {
    param (
        [string]$tableName,
        [string]$tableNameFile,
        [string]$columnName,
        [int[]]$values,  # Array of values
        [string]$characterName,
        [string]$Race,
        [string]$Class,
        [string]$Gender,
        [string]$Level
    )
################ Assign strings to things like race and class
		switch ($Race) {
				1 { $Race = "Human" }
				2 { $Race = "Orc" }
				3 { $Race = "Dwarf" }
				4 { $Race = "Night_Elf" }
				5 { $Race = "Undead" }
				6 { $Race = "Tauren" }
				7 { $Race = "Gnome" }
				8 { $Race = "Troll" }
				10 { $Race = "Blood_Elf" }
				11 { $Race = "Draenei" }
				default { $Race = "Unknown_Race" }
		}
		
		switch ($Class) {
				1 { $Class = "Warrior" }
				2 { $Class = "Paladin" }
				3 { $Class = "Hunter" }
				4 { $Class = "Rogue" }
				5 { $Class = "Priest" }
				6 { $Class = "Death_Knight" }
				7 { $Class = "Shaman" }
				8 { $Class = "Mage" }
				9 { $Class = "Warlock" }
				11 { $Class = "Druid" }
				default { $Class = "Unknown_Class" }
		}
		
		switch ($Gender) {
				0 { $Gender = "Male" }
				1 { $Gender = "Female" }
				default { $Gender = "Unknown_Gender" }
		}
################################
    # Create a backup filename
		# e.g. Boya - Orc Rogue Female LV1
    $backupDirFull = "$backupDir\$userNameToSearch\$characterName - $Race $Class $Gender LV$Level"
		# Create folders if they do not exist
		if (-not (Test-Path $backupDirFull)) {
				New-Item -Path $backupDirFull -ItemType Directory | Out-Null
		}
		
    $backupFile = "$backupDirFull\$tableNameFile.sql"
		
		# Generate the WHERE clause
    $valuesList = $values -join ","
    $whereClause = "$columnName IN ($valuesList)"

    # Command to run mysqldump with a WHERE clause
		$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$serverName`" --port=`"$port`" --user=`"$username`" --password=`"$password`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$database_characters`" `"$tableName`" > `"$backupFile`""

    Invoke-Expression $mysqldumpCommand
		
    if ($LASTEXITCODE -eq 0) {
        # Write-Host "Backed up data from $tableName to $sqlFilePath"
    } else {
        Write-Host "Error backing up data from $tableName"
    }
		
}


##############################################################################
function Backup-Character {
    param (
        [int]$characterId,
        [string]$characterName,
        [string]$accountID,
        [string]$Race,
        [string]$Class,
        [string]$Gender,
        [string]$Level
    )
		

########################## GENERAL (for those tables that only use a GUID as identifier to a character)
		Write-Host "Backing up character $characterName..."
		
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
				"character_equipmentsets"				#new
		)
		
		foreach ($table in $tables) {
				# Write-Host "Dumping table $table"
				Backup-TableData -tableName $table -tableNameFile $table -columnName "guid" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
		}
		
		

		
########################## PET DATA						
		# Define the query to find pets owned by the specified ID
		$queryPets = "SELECT id, entry, level, name FROM character_pet WHERE owner = @owner;"
		
		$petsData = @()
		try {
				# Create a command object
				$commandPets = $connectionCharacters.CreateCommand()
				$commandPets.CommandText = $queryPets
				#MySqlParameter: This is the name of the parameter as it will be referred to in your SQL query (in this case @owner). It should match the placeholder in your SQL command (e.g., WHERE owner = @owner).
				$commandPets.Parameters.Add((New-Object MySql.Data.MySqlClient.MySqlParameter("@owner", [MySql.Data.MySqlClient.MySqlDbType]::Int32))).Value = $characterId
					
				# Execute the query and read the results
				$readerPets = $commandPets.ExecuteReader()
		
				while ($readerPets.Read()) {
						$petsData += [PSCustomObject]@{
								PetId = $readerPets["id"]
								PetLevel = $readerPets["level"]
								PetName = $readerPets["name"]
								PetEntry = $readerPets["entry"]
						}
				}
				$readerPets.Close()
				

				# Check if $petsData contains any data
				if ($petsData.Count -gt 0) {
						# open connection to world database
						$connectionWorld.Open()
		
						# Query to find creature name
						$queryWorld = "SELECT name FROM creature_template WHERE entry = @PetEntry;"

						foreach ($pet in $petsData) {
								$petID = $pet.petID
								$PetLevel = $pet.PetLevel
								$PetName = $pet.PetName
								$PetEntry = $pet.PetEntry
								
								# Create a command
								$commandWorld = $connectionWorld.CreateCommand()
								$commandWorld.CommandText = $queryWorld
								$commandWorld.Parameters.Add((New-Object MySql.Data.MySqlClient.MySqlParameter("@PetEntry", [MySql.Data.MySqlClient.MySqlDbType]::Int32))).Value = $PetEntry
						
								$readerWorld = $commandWorld.ExecuteReader()
						
								while ($readerWorld.Read()) {
									$PetEntryName = $readerWorld["name"]
								}
								$readerWorld.Close()
								
								Write-Host "Found pet: (ID: $petID), $PetName, $PetEntryName, LV $Level"
						}
				
						# Close the connection
						$connectionWorld.Close()
		
						# acore_world / creature_template / find "entry" column and get value in "name" column
						# Backup pet data
						Backup-TableData -tableName "character_pet" -tableNameFile "character_pet" -columnName "owner" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
						
						#add pet ids to list
						$petIds = @()
						foreach ($pet in $petsData) {
								$petIds += $pet.petID
						}
						
						# Backup data related to pets
						Backup-TableData-Array -tableName "pet_aura" -tableNameFile "pet_aura" -columnName "guid" -values $petIds -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
						Backup-TableData-Array -tableName "pet_spell" -tableNameFile "pet_spell" -columnName "guid" -values $petIds -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
						Backup-TableData-Array -tableName "pet_spell_cooldown" -tableNameFile "pet_spell_cooldown" -columnName "guid" -values $petIds -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
				}
		else {
				Write-Host "No pets found for character '$characterName'"
		}
		} catch {
				Write-Host "Error during execution: $($_.Exception.Message)"
		}

########################## ITEM DATA (this one was far easier than i initially thought)
		Backup-TableData -tableName "item_instance" -tableNameFile "item_instance" -columnName "owner_guid" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level

########################## MAIL DATA (have to create one file for sender and other for receiver)
		#this was causing duplicate errors in the database when importing so for now  only receiver is backed up
		# Backup-TableData -tableName "mail" -tableNameFile "mail_sender" -columnName "sender" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
		Backup-TableData -tableName "mail" -tableNameFile "mail_receiver" -columnName "receiver" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
##########################
		# arena_team_member               #arenaTeamId, guid        also need to backup arenaTeamId (arena_team table) associated with character guid
###################### TRANSMOG DATA
		Backup-TableData -tableName "custom_transmogrification" -tableNameFile "custom_transmogrification" -columnName "Owner" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
		Backup-TableData -tableName "custom_transmogrification_sets" -tableNameFile "custom_transmogrification_sets" -columnName "Owner" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
		Backup-TableData -tableName "custom_unlocked_appearances" -tableNameFile "custom_unlocked_appearances" -columnName "account_id" -value $accountID -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
###################### REAGENT BANK DATA
		Backup-TableData -tableName "custom_reagent_bank" -tableNameFile "custom_reagent_bank" -columnName "character_id" -value $characterId -characterName $characterName -Race $Race -Class $Class -Gender $Gender -Level $Level
#################################
		
###################### DELETE ALL EMPTY SQL FILES
		Get-ChildItem -Path $backupDir -Filter "*.sql" -Recurse | Where-Object { $_.Length -eq 0 } | Remove-Item
#################################
}
########################################

do {
    # Prompt for account name
    Write-Host "(Press CTRL + C to exit)"
    $userNameToSearch = Read-Host "`nEnter account name"


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
        } else {
            Write-Host "`nNo account found with username '$userNameToSearch'"
        }

        $readerAuth.Close()
    } catch {
        Write-Host "Error: $($_.Exception.Message)"
    } finally {
        $connectionAuth.Close()
    }

    if ($id -ne $null) {
        # Query to find characters based on account ID
        $queryCharacters = "SELECT guid, name, race, class, gender, level, money, totalHonorPoints, creation_date FROM characters WHERE account = @id;"

        try {
            $connectionCharacters.Open()

            # Create a command object for characters database
            $commandCharacters = $connectionCharacters.CreateCommand()
            $commandCharacters.CommandText = $queryCharacters
            $commandCharacters.Parameters.Add((New-Object MySql.Data.MySqlClient.MySqlParameter("@id", [MySql.Data.MySqlClient.MySqlDbType]::Int32))).Value = $id

            # Execute the query and read the results into a collection
            $characterData = @()
            $readerCharacters = $commandCharacters.ExecuteReader()

            while ($readerCharacters.Read()) {
                $characterData += [PSCustomObject]@{
                    CharacterId   = $readerCharacters["guid"]
                    CharacterName = $readerCharacters["name"]
                    Race          = $readerCharacters["race"]
                    Class         = $readerCharacters["class"]
                    Gender        = $readerCharacters["gender"]
                    Level         = $readerCharacters["level"]
                    Money         = $readerCharacters["money"]
                    MoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $readerCharacters["money"]
                    Honor         = $readerCharacters["totalHonorPoints"]
                    CreationDate         = $readerCharacters["creation_date"]
                }
            }

            $readerCharacters.Close()

            # Now process the character data from the collection
            if ($characterData.Count -gt 0) {
                $exitScript = $false
                $foundCharacters = $true
                while (-not $exitScript) {
                    Write-Host "`nFound $($characterData.Count) Characters."
                    Write-Host "`nCharacter List:"
                    $index = 1
                    foreach ($character in $characterData) {
												$characterId = $character.CharacterId
												$characterName = $character.CharacterName
												$Race = $character.Race
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
												
												$Class = $character.Class
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
												
												$Gender = $character.Gender
												switch ($Gender) {
														0 { $Gender = "Male" }
														1 { $Gender = "Female" }
														default { $Gender = "Unknown Gender" }
												}
												
												$Level = $character.Level
												$MoneyConverted = $character.MoneyConverted
												$Honor = $character.Honor
												$CreationDate = $character.CreationDate
										
                        Write-Host "`n$index. (GUID: $CharacterId) $CharacterName - $Race, $Class, $Gender, LV$Level, Honor: $Honor, Money: $MoneyConverted, Creation date: $CreationDate"
                        $index++
                    }
                    Write-Host "`n$index. Back up all characters"
                    Write-Host "$($index + 1). Go back"
                    Write-Host "$($index + 2). Exit script"

                    $choice = Read-Host "`nType a number (1-$($index + 2))"

                    if ($choice -match '^\d+$') {
                        $choice = [int]$choice
												#backup 1
                        if ($choice -ge 1 -and $choice -le $characterData.Count) {
														$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                            $selectedCharacter = $characterData[$choice - 1]
                            Backup-Character -characterId $selectedCharacter.CharacterId `
                                             -characterName $selectedCharacter.CharacterName `
                                             -accountID $id `
                                             -Race $selectedCharacter.Race `
                                             -Class $selectedCharacter.Class `
                                             -Gender $selectedCharacter.Gender `
                                             -Level $selectedCharacter.Level
														$stopwatch.Stop()
                            Write-Host "Backup done in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..."
												#backup all
                        } elseif ($choice -eq $index) {
														$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                            foreach ($character in $characterData) {
                                Backup-Character -characterId $character.CharacterId `
                                                 -characterName $character.CharacterName `
																								 -accountID $id `
                                                 -Race $character.Race `
                                                 -Class $character.Class `
                                                 -Gender $character.Gender `
                                                 -Level $character.Level
                            }
														$stopwatch.Stop()
                            Write-Host "All characters backed up in $($stopwatch.Elapsed.TotalSeconds) seconds. Returning to menu..."
												#go back
                        } elseif ($choice -eq ($index + 1)) {
                            Write-Host "Going back..."
                            break # This will restart the loop and prompt for a new account name
												#exit
                        } elseif ($choice -eq ($index + 2)) {
                            Write-Host "Exiting script..."
                            $exitScript = $true
												#invalid selection for character list
                        } else {
                            Write-Host "Invalid selection. Please try again."
                        }
                    } else {
                        Write-Host "Invalid selection. Please try again."
                    }
                }
            } else {
                Write-Host "No characters found for account ID '$id'"
            }
        } catch {
            Write-Host "Error: $($_.Exception.Message)"
        } finally {
            $connectionCharacters.Close()
        }
    }

} while (-not $exitScript)
###################################################






