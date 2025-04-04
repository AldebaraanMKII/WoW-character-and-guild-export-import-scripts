
############# UTILITY FUNCTIONS
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
    
    # Convert race/class/gender (same as before)
    $Race = switch ($Race) {
        1 { "Human" }; 2 { "Orc" }; 3 { "Dwarf" }
        4 { "Night_Elf" }; 5 { "Undead" }; 6 { "Tauren" }
        7 { "Gnome" }; 8 { "Troll" }; 10 { "Blood_Elf" }
        11 { "Draenei" }; default { "Unknown_Race" }
    }
    
    $Class = switch ($Class) {
        1 { "Warrior" }; 2 { "Paladin" }; 3 { "Hunter" }
        4 { "Rogue" }; 5 { "Priest" }; 6 { "Death_Knight" }
        7 { "Shaman" }; 8 { "Mage" }; 9 { "Warlock" }
        11 { "Druid" }; default { "Unknown_Class" }
    }
    
    $Gender = switch ($Gender) {
        0 { "Male" }; 1 { "Female" }
        default { "Unknown_Gender" }
    }

    $backupDirFull = "$CharacterBackupDir\$AccountName\$characterName ($CurrentDate) - $Race $Class $Gender LV$Level"
    if (-not (Test-Path $backupDirFull)) {
        New-Item -Path $backupDirFull -ItemType Directory | Out-Null
    }
    
    $backupFile = "$backupDirFull\$tableNameFile.sql"
	# Write-Host "File: $backupDirFull\$tableNameFile.sql" -ForegroundColor Yellow
    $whereClause = "$columnName=$value"
	

    $mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$SourceDatabaseCharacters`" `"$tableName`" > `"$backupFile`""
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
    
    # Convert race/class/gender (same as above)
    $Race = switch ($Race) {
        1 { "Human" }; 2 { "Orc" }; 3 { "Dwarf" }
        4 { "Night_Elf" }; 5 { "Undead" }; 6 { "Tauren" }
        7 { "Gnome" }; 8 { "Troll" }; 10 { "Blood_Elf" }
        11 { "Draenei" }; default { "Unknown_Race" }
    }
    
    $Class = switch ($Class) {
        1 { "Warrior" }; 2 { "Paladin" }; 3 { "Hunter" }
        4 { "Rogue" }; 5 { "Priest" }; 6 { "Death_Knight" }
        7 { "Shaman" }; 8 { "Mage" }; 9 { "Warlock" }
        11 { "Druid" }; default { "Unknown_Class" }
    }
    
    $Gender = switch ($Gender) {
        0 { "Male" }; 1 { "Female" }
        default { "Unknown_Gender" }
    }

    # Create backup directory
    $backupDirFull = "$CharacterBackupDir\$AccountName\$characterName ($CurrentDate) - $Race $Class $Gender LV$Level"
    if (-not (Test-Path $backupDirFull)) {
        New-Item -Path $backupDirFull -ItemType Directory | Out-Null
    }
    
    $backupFile = "$backupDirFull\$tableNameFile.sql"
    $valuesList = $values -join ","
    $whereClause = "$columnName IN ($valuesList)"
    
    $mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-drop-table --skip-add-locks --skip-comments --no-create-info --compact --where=`"$whereClause`" `"$SourceDatabaseCharacters`" `"$tableName`" > `"$backupFile`""
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
        Invoke-SqlUpdate -ConnectionName $ConnectionName -Query $Query
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
				Write-Host "`nID for username '$characterNameToSearch': $guid" -ForegroundColor Yellow
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
