# Define source connection details
# source = database from which you will backup the characters/guilds from
$SourceServerName = "127.0.0.1"
$SourcePort = 3306
$SourceUsername = "acore"
$SourcePassword = "acore"
$SourceDatabaseAuth = "acore_auth"
$SourceDatabaseCharacters = "acore_characters"
$SourceDatabaseWorld = "acore_world"
$SourceDatabaseFusionGEN = "website"

# Define target connection details
# target = database from which you will restore the characters/guilds to
$TargetServerName = "127.0.0.1"
$TargetPort = 3306
$TargetUsername = "acore"
$TargetPassword = "acore"
$TargetDatabaseAuth = "acore_auth"
$TargetDatabaseCharacters = "acore_characters"
$TargetDatabaseWorld = "acore_world"
$TargetDatabaseFusionGEN = "website"


# Paths to executables
$mysqldumpPath = "E:\Games\WoW Server Files\My Repack\mysql\bin\mysqldump.exe"
$mysqlPath = "E:\Games\WoW Server Files\My Repack\mysql\bin\mysql.exe"

# Backup directory for character sqls
$CharacterBackupDir = "$PSScriptRoot/data_character"
# Backup directory for guild sqls
$GuildBackupDir = "$PSScriptRoot/data_guild"
# Backup directory for FusionGEN sqls
$FusionGENBackupDir = "$PSScriptRoot/data_fusiongen"

#Map and zone names
$MapZoneDBFilePath = "$PSScriptRoot/Map_Zone_Names.sqlite3"

# Regex filters
$AccountNameRegexFilter = "^(?!.*(RNDBOT|AHBOT)).*$"    #excludes both RNDBOT and AHBOT accounts
$CharacterNameRegexFilter = ""
$GuildNameRegexFilter = ""





