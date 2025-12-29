# Define source connection details
# source = database from which you will backup the characters/guilds from
$SourceServerName = "127.0.0.1"
$SourcePort = 3306
$SourceUsername = "root"
$SourcePassword = "test"
$SourceDatabaseAuth = "acore_auth"
$SourceDatabaseCharacters = "acore_characters"
$SourceDatabaseWorld = "acore_world"

# Define target connection details
# target = database from which you will restore the characters/guilds to
$TargetServerName = "127.0.0.1"
$TargetPort = 3306
$TargetUsername = "root"
$TargetPassword = "test"
$TargetDatabaseAuth = "acore_auth"
$TargetDatabaseCharacters = "acore_characters"
$TargetDatabaseWorld = "acore_world"


# Paths to executables
$mysqldumpPath = "E:\Games\WoW Server Files\My Repack\mysql\bin\mysqldump.exe"
$mysqlPath = "E:\Games\WoW Server Files\My Repack\mysql\bin\mysql.exe"

# Backup directory for character sqls
$CharacterBackupDir = "$PSScriptRoot/character_data"
# Backup directory for guild sqls
$GuildBackupDir = "$PSScriptRoot/guild_data"

#Map and zone names
$MapZoneDBFilePath = "$PSScriptRoot/Map_Zone_Names.sqlite3"

# Regex filters
$AccountNameRegexFilter = ""
$CharacterNameRegexFilter = ""
$GuildNameRegexFilter = ""
