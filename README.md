This currently only supports azerothcore based servers.

# Instructions
1. Install Powershell 7
2. Install SimplySQL and PSSQLite modules:
 ```
Install-Module -Name SimplySql, PSSQLite -Force
 ```
4. Extract the scripts folder somewhere
5. Open "(Config) Backup scripts" with notepad++ or another text editor and check/update the following:
 ```
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
 ```

Source is the database you're exporting the data from.

Target is the database you're importing the data to.

Paths to executables is the path to the mysql executables, which are required to export the .sql files used by the scripts. Those executables are typically included in a repack's mysql/bin folder. If you don't have them, install MySQL server 8.4.


6. If you`re backing up characters/guilds, open the MySQL database that contain those characters/guilds.
7. If you`re restoring characters/guilds, open the MySQL database that you want to transfer them to.
8. Go into the folder you extracted the scripts to, right click > PowerShell 7 > Open Here
9. type the name of the script like this: ./"Backup scripts.ps1"
10. Follow the instructions in the console.


IMPORTANT: Make sure only the mysql database is open when you export/import your characters or guild! Trying to export/import while the auth/world server is running can lead to issues, like several items missing from the character inventory or duplicate entries in the database! 



# WoW-character-autobackup-script

# Configuration
$CharacterList = List of characters that you want to backup. Case sensitive.

$BackupDelay = backup the characters every $BackupDelay seconds.

$7zipCompression = Create a 7z archive and then delete the folder to save space.

$DBFilePath = No need to mess with this.


# Usage
1. Configure "(Config) AutoBackup script.ps1"
2. Open the database your characters are in
3. Run the script: .\"Autobackup script.ps1"

# FAQ
Q: Can i play while this runs?

A: Yes. It was my intention to backup the characters while they are being played.


Q: I set it to backup every X seconds but they only backup several tries later!

A: Worldserver.conf PlayerSaveInterval needs to be edited. Set it to something lower than what you set $BackupDelay.



















