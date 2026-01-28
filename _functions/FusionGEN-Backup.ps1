#################################################################
#region FusionGEN-Backups
#################################################################
function Backup-FusionGEN {
	param (
		[string]$BackupDir
	)
	
	Write-Host "`nBacking up FusionGEN website data..." -ForegroundColor Cyan
	
	# Ensure backup directory exists 
	if (-not (Test-Path $BackupDir)) { 
		New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null 
	}
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
		# "ci_sessions",
		"changelog",
		"changelog_type",
		
		"character_tools_free",
		"character_trade",
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
		# "visitor_log",
		"vote_log",
		
		"vote_sites",
		"wheel_logs",
		"wheel_rewards_items",
		"wheel_upgrade_options"
	)
	
	#if this is set to true, backup the log tables as well
	if ($FusionGENProcessLogTables) {
		$tables += "ci_sessions"
		$tables += "visitor_log"
	}
#################################################################
	foreach ($table in $tables) {
		$backupFile = "$BackupDir\$table.sql"
		
		$mysqldumpCommand = "& `"$mysqldumpPath`" --host=`"$SourceServerName`" --port=`"$SourcePort`" --user=`"$SourceUsername`" --password=`"$SourcePassword`" --skip-add-locks --skip-comments --hex-blob `"$SourceDatabaseFusionGEN`" `"$table`" > `"$backupFile`""
		
		Invoke-Expression $mysqldumpCommand 2>$null

		if ($LASTEXITCODE -eq 0) {
			# Write-Host "Backed up data from $table to $backupFile" -ForegroundColor Green
			Write-Host "Backed up data from $table." -ForegroundColor Green
		} else {
			Write-Host "Error backing up data from $tableName to $backupFile." -ForegroundColor Red
		}
	}
#################################################################
	#remove empty sqls
	Get-ChildItem -Path $BackupDir -Filter "*.sql" -Recurse | Where-Object { $_.Length -eq 0 } | Remove-Item
}
#################################################################
function Backup-FusionGen-Main {
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseFusionGEN -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "FusionGENConn"
	try {
		$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
		$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
		$BackupDir = "$FusionGENBackupDir\full_backups\$SourceServerName ($($CurrentDate))"
		Backup-FusionGEN -BackupDir $BackupDir
	} catch {
		$stopwatch.Stop()
		Write-Host "An error occurred (line $($_.InvocationInfo.ScriptLineNumber)): $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Close-SqlConnection -ConnectionName "FusionGENConn"
		$stopwatch.Stop()
		Write-Host "`nFusionGEN data backed up in $($stopwatch.Elapsed.TotalSeconds) seconds." -ForegroundColor Green
		[console]::beep()
	}
}
#################################################################
#endregion
#################################################################