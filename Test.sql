GO
USE master;
EXEC SpCloneDb @sourceDbName = N'source-db-name', @targetDbName = N'target-db-name';
EXEC SpRestoreDb @targetDbName = N'target-db-name', @bakFileName = N'file-name.bak';
