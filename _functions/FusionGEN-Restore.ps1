#################################################################
#region FusionGEN-Restore
#################################################################
function Restore-FusionGEN {
	param (
		[string]$FusionGENBackupDir,
		[string]$AccountCharacterBackupDir
	)
#################################################################
	# Load JSON lists
	$JsonList = @(
		@("Accounts",	$guidMappingAccounts),
		@("Characters", $guidMappingCharacters),
		@("Pets",	$guidMappingpPets),
		@("Items",	$guidMappingItems)
	)
	foreach ($entry in $JsonList) {
		$JsonName    = $entry[0]
		$guidMapping = $entry[1]
		$JsonFilePath = "$AccountCharacterBackupDir\$JsonName.json"
		if (Test-Path -Path $JsonFilePath) {
			# Read JSON file and convert to objects
			$jsonData = Get-Content $JsonFilePath -Raw | ConvertFrom-Json
			# Clear current ArrayList if you want to replace contents
			$guidMapping.Clear()
			# Add each object back into the ArrayList
			foreach ($obj in $jsonData) {
				$guidMapping.Add($obj) | Out-Null
			}
		}
	}
	
#################################################################
	Write-Host "`nRestoring FusionGEN website data..." -ForegroundColor Cyan
#################################################################
	$tables = @(
		@("account_data",	0, $guidMappingAccounts),
		@("acl_account_groups",	0, $guidMappingAccounts),
		@("acl_account_permissions", 0, $guidMappingAccounts),
		@("acl_account_roles",	0, $guidMappingAccounts, 1, $guidMappingCharacters)
		@("articles", 2, $guidMappingAccounts),
		@("comments", 2, $guidMappingAccounts),
		@("changelog", 2, $guidMappingAccounts),
		@("character_trade", 2, $guidMappingAccounts, 3, $guidMappingCharacters, 5, $guidMappingAccounts),
		@("cta_logs", 1, $guidMappingAccounts, 3, $guidMappingCharacters, 5, $guidMappingAccounts),
		@("dpta_logs", 1, $guidMappingAccounts, 3, $guidMappingAccounts),
		@("gift_cards", 7, $guidMappingAccounts),
		@("giftcard", 7, $guidMappingAccounts),
		@("giftcard_attempts", 1, $guidMappingAccounts),
		@("log_emblem_transfer", 1, $guidMappingAccounts, 3, $guidMappingCharacters, 6, $guidMappingCharacters),
		@("log_item_eoe", 1, $guidMappingAccounts, 3, $guidMappingCharacters, 5, $guidMappingCharacters, 14, $guidMappingItems),
		@("log_skills", 1, $guidMappingAccounts, 4, $guidMappingCharacters),
		@("logs", 2, $guidMappingAccounts),
		@("member_admin_logs", 1, $guidMappingAccounts),
		@("member_id_accounts", 3, $guidMappingAccounts),
		@("mod_logs", 2, $guidMappingAccounts, 3, $guidMappingCharacters),
		@("mysterybox_cooldowns", 1, $guidMappingAccounts),
		@("mysterybox_history", 1, $guidMappingAccounts, 10, $guidMappingCharacters),
		@("mysterybox_logs", 1, $guidMappingAccounts),
		@("order_log", 2, $guidMappingAccounts),
		@("paypal_logs", 1, $guidMappingAccounts),
		@("sideboxes_poll_votes", 2, $guidMappingAccounts),
		@("vote_log", 2, $guidMappingAccounts),
		@("wheel_logs", 1, $guidMappingAccounts, 3, $guidMappingCharacters)
	)
#################################################################
	foreach ($entry in $tables) {
		$table       = $entry[0]
		$sqlFilePath = "$FusionGENBackupDir\$table.sql"
	
		if (Test-Path -Path $sqlFilePath) {
			# if (Table-Exists -TableName $table -ConnectionName "FusionGENConn") {
				# Read the full SQL file
				$sqlContent = Get-Content -Path $sqlFilePath -Raw
				
				# Regex pattern to match INSERT statements with values
				$insertPattern = "(INSERT INTO.*?VALUES\s*\(.*?\);)"
				
				# Replace only inside INSERT statements
				# Before the regex replacement, extract the mapping pairs
				$mappings = $entry[1..($entry.Count - 1)]

				$modifiedSqlContent = [regex]::Replace($sqlContent, $insertPattern, {
					param($match)
					$stmt = $match.Value
				
					$stmt = [regex]::Replace($stmt, "(?<=\().*?(?=\))", {
						param($innerMatch)
						$values = $innerMatch.Value -split ","
				
						# Loop through mapping pairs
						for ($i = 0; $i -lt $mappings.Count; $i += 2) {
							$colIndex   = $mappings[$i]
							$mappingSet = $mappings[$i + 1]
				
							if ($colIndex -ge 0 -and $mappingSet) {
								$oldValue = $values[$colIndex].Trim()
								$map = $mappingSet | Where-Object { $_.OldGuid -eq $oldValue }
								if ($map) { $values[$colIndex] = $map.NewGuid }
							}
						}
						return ($values -join ",")
					})
					return $stmt
				})

				Write-Host "`nRestoring data for table $($table)..." -ForegroundColor Cyan
				Write-Host "Modified SQL for table $($table): $modifiedSqlContent"
				
				Execute-Query -query "$modifiedSqlContent" -tablename $table -ConnectionName "FusionGENConn"
#################################################################
			# } else {
				# Write-Host "Table '$table' does not exist, skipping restore for this table." -ForegroundColor Yellow
			# }
#################################################################
		}
#################################################################
	}
#################################################################
	# this is for tables that do not need any ID replacement
	$tables = @(
		"access_trade_items",
		"levelup_items",
		"member_id_features",
		"acl_group_roles",
		"acl_groups",
		"acl_roles",
		"acl_roles_permissions",
		"article_tag",
		"avatars",
		"backup",
		"changelog_type",
		"character_tools_free",
		# "ci_sessions",
		"daily_signups",
		"data_wotlk_itemdisplayinfo",
		"email_change_key",
		"email_log",
		"email_templates",
		"emblemitems",
		"failed_logins",
		"image_slider",
		"item_icons",
		"member_features",
		"member_id",
		"member_id_feature_items",
		"member_id_login_attempts",
		"member_id_purchases",
		"menu",
		"monthly_income",
		"monthly_votes",
		"mysterybox_chance_options",
		"mysterybox_rewards",
		"notifications",
		"pages",
		"password_recovery_key",
		"paygol_logs",
		"paypal_donate",
		"ranks",
		"realms",
		"sideboxes",
		"sideboxes_custom",
		"sideboxes_poll_answers",
		"sideboxes_poll_questions",
		"skills",
		"spell_recipes",
		"spelltext_en",
		"store_groups",
		"store_items",
		"tag",
		"teleport_locations",
		# "visitor_log",
		"vote_sites",
		"wheel_rewards_items",
		"wheel_upgrade_options"
	)
	
	#if this is set to true, restore the log tables as well
	if ($FusionGENProcessLogTables) {
		$tables += "ci_sessions"
		$tables += "visitor_log"
	}
#################################################################
	foreach ($entry in $tables) {
		$table       = $entry[0]
		$sqlFilePath = "$FusionGENBackupDir\$table.sql"
	
		if (Test-Path -Path $sqlFilePath) {
			$sqlContent = Get-Content -Path $sqlFilePath -Raw
			Write-Host "`nRestoring data for table $($table)..." -ForegroundColor Cyan
			# Output the modified SQL to verify
			# Write-Host "SQL for table $($table): $sqlContent" -ForegroundColor White
			
			Execute-Query -query "$sqlContent" -tablename $table -ConnectionName "FusionGENConn"
		}
#################################################################
	}
#################################################################
}
#################################################################
function Restore-FusionGen-Main {
	# DROP DATABASE IF EXISTS `website`;
	# CREATE DATABASE IF NOT EXISTS `website` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
	# USE `website`;
	$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
	
	Open-MySqlConnection -Server $TargetServerName -Port $TargetPort -Database "mysql" -Credential (New-Object System.Management.Automation.PSCredential($TargetUsername, (ConvertTo-SecureString $TargetPassword -AsPlainText -Force))) -ConnectionName "MysqlConn"

	$databaseName = "website"
	
	$query = "SELECT SCHEMA_NAME 
			FROM INFORMATION_SCHEMA.SCHEMATA 
			WHERE SCHEMA_NAME = '$databaseName';"
	
	$result = Invoke-SqlQuery -ConnectionName "MysqlConn" -Query $query
	
	if ($result) {
		Write-Host "Database $databaseName exists." -ForegroundColor Cyan
	} else {
		Write-Host "Database $databaseName does not exist. Creating it..." -ForegroundColor Yellow
		Invoke-SqlQuery -ConnectionName "MysqlConn" -Query "CREATE DATABASE IF NOT EXISTS '$databaseName';"
	}

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
		Write-Host "`nYou selected: $($backupFolders[$selection].Name)" -ForegroundColor Green
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
		Write-Host "`nYou selected: $($backupFolders[$selection].Name)" -ForegroundColor Green
#################################################################
		Restore-FusionGEN -FusionGENBackupDir $chosenFusionGENBackupFolder -AccountCharacterBackupDir $chosenAccountCharacterBackupFolder
#################################################################
	} catch {
		Write-Host "An error occurred (line $($_.InvocationInfo.ScriptLineNumber)): $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Close-SqlConnection -ConnectionName "MysqlConn"
		Close-SqlConnection -ConnectionName "FusionGENConn"
		$stopwatch.Stop()
		Write-Host "`nFusionGEN data backed up in $($stopwatch.Elapsed.TotalSeconds) seconds." -ForegroundColor Green
		[console]::beep()
	}
}
#################################################################
#endregion
#################################################################