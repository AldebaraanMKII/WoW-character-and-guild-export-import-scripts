#List of characters to backup
$CharacterList = @(
	"Character1",
	"Character2",
	"Character3"
)

#backup characters every X seconds
$BackupDelay = 300

#if set to $true, will use 7zip to create a archive with the character data after backup to save space. 7zip needs to be on PATH.
$7zipCompression = $false

#this file is used to compare data and ensure that a character only gets saved when there was a change in them
$DBFilePath = "$PSScriptRoot/CharacterLastSavedStats.sqlite3"


