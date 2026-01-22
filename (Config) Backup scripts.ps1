###################################################################
# Define source connection details
# Source = database from which you will backup the characters/guilds from
$SourceServerName = "127.0.0.1"
$SourcePort = 3306
$SourceUsername = "acore"
$SourcePassword = "acore"
$SourceDatabaseAuth = "acore_auth"
$SourceDatabaseCharacters = "acore_characters"
$SourceDatabaseWorld = "acore_world"
$SourceDatabaseFusionGEN = "website"
###################################################################
# Define target connection details
# Target = database from which you will restore the characters/guilds to
$TargetServerName = "127.0.0.1"
$TargetPort = 3306
$TargetUsername = "acore"
$TargetPassword = "acore"
$TargetDatabaseAuth = "acore_auth"
$TargetDatabaseCharacters = "acore_characters"
$TargetDatabaseWorld = "acore_world"
$TargetDatabaseFusionGEN = "website"
###################################################################
# if set to true, backup these log tables (which are over 80% of the size of the FusionGEN website database):
# ci_sessions = 
# visitor_log = contains a list of all the times someone visited the website.
# set this to $false if you want a much quicker backup/restore.
$FusionGENProcessLogTables = $true
###################################################################
# Paths to executables
$mysqldumpPath = "E:\Games\WoW Server Files\My Repack\mysql\bin\mysqldump.exe"
$mysqlPath = "E:\Games\WoW Server Files\My Repack\mysql\bin\mysql.exe"
###################################################################
# Backup directory for sqls
# $CharacterBackupDir = "$PSScriptRoot/data_character"
$CharacterBackupDir = "C:\Users\Antares\Desktop\New folder\data_character"
# Backup directory for guild sqls
# $GuildBackupDir = "$PSScriptRoot/data_guild"
$GuildBackupDir = "C:\Users\Antares\Desktop\New folder\data_guild"
# Backup directory for FusionGEN sqls
# $FusionGENBackupDir = "$PSScriptRoot/data_fusiongen"
$FusionGENBackupDir = "C:\Users\Antares\Desktop\New folder\data_fusiongen"
###################################################################
# Map and zone names
$MapZoneDBFilePath = "$PSScriptRoot/Map_Zone_Names.sqlite3"
###################################################################
# Regex filters
$AccountNameRegexFilter = "^(?!.*(RNDBOT|AHBOT)).*$"    #excludes both RNDBOT and AHBOT accounts
$CharacterNameRegexFilter = ""
$GuildNameRegexFilter = ""
###################################################################




