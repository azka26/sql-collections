USE master;
GO
CREATE OR ALTER PROCEDURE SpCloneDb
	@sourceDbName NVARCHAR(MAX),
	@targetDbName NVARCHAR(MAX)
AS
BEGIN
	DECLARE @sourceDB NVARCHAR(MAX) = @sourceDbName;
	DECLARE @dbName NVARCHAR(MAX) = @targetDbName;
	DECLARE @fileName NVARCHAR(MAX) = @sourceDbName + '_' + FORMAT(GETDATE(), 'yyyyMMddHHmmssfff');
	DECLARE @bakFile NVARCHAR(MAX) = '/var/opt/mssql/backup/' + @fileName + '.bak';
	DECLARE @bakTargetFile NVARCHAR(MAX) = '/var/opt/mssql/backup/' + @fileName + '_clone.bak';
	DECLARE @bakTargetFileOriginal NVARCHAR(MAX) = '/var/opt/mssql/backup/' + @fileName + '_clone_original.bak';
	DECLARE @dataPath NVARCHAR(MAX) = '/var/opt/mssql/data/';
	DECLARE @sql NVARCHAR(MAX);
	DECLARE @logicalName NVARCHAR(MAX);
	DECLARE @logicalNameLog NVARCHAR(MAX);
	DECLARE @logicalNameTarget NVARCHAR(MAX);
	DECLARE @logicalNameLogTarget NVARCHAR(MAX);

	-- BACKUP SORUCE DB
	BACKUP DATABASE @sourceDB
	TO DISK = @bakFile
	WITH FORMAT,
	  MEDIANAME = 'SQLServerBackups',
	  NAME = 'Full Backup Source';
  
	-- CREATE TARGET DB
	IF EXISTS (SELECT name FROM sys.databases WHERE name = @dbName)
	BEGIN
		-- BACKUP TARGET DB
		BACKUP DATABASE @dbName
		TO DISK = @bakTargetFileOriginal
		WITH FORMAT,
		  MEDIANAME = 'SQLServerBackups',
		  NAME = 'Full Backup Target Original';

		EXEC('ALTER DATABASE [' + @dbName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE');
		EXEC('DROP DATABASE ' + @dbName);
	END

	EXEC('CREATE DATABASE ' + @dbName);

	-- BACKUP TARGET DB
	BACKUP DATABASE @dbName
	TO DISK = @bakTargetFile
	WITH FORMAT,
	  MEDIANAME = 'SQLServerBackups',
	  NAME = 'Full Backup Target';

	DROP TABLE IF EXISTS #FileList;
	CREATE TABLE #FileList (
		LogicalName NVARCHAR(128),
		PhysicalName NVARCHAR(260),
		Type CHAR(1),
		FileGroupName NVARCHAR(128),
		Size NUMERIC(20,0),
		MaxSize NUMERIC(20,0),
		FileId INT,
		CreateLSN NUMERIC(25,0),
		DropLSN NUMERIC(25,0),
		UniqueId UNIQUEIDENTIFIER,
		ReadOnlyLSN NUMERIC(25,0),
		ReadWriteLSN NUMERIC(25,0),
		BackupSizeInBytes BIGINT,
		SourceBlockSize INT,
		FileGroupId INT,
		LogGroupGuid UNIQUEIDENTIFIER,
		DifferentialBaseLSN NUMERIC(25,0),
		DifferentialBaseGUID UNIQUEIDENTIFIER,
		IsReadOnly BIT,
		IsPresent BIT,
		TDEThumbprint VARBINARY(32),
		SnapshotUrl NVARCHAR(MAX)
	);

	-- Insert the file list into the temporary table
	-- READ ORIGINAL LOGICAL NAME
	DELETE FROM #FileList;
	INSERT INTO #FileList
	EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @bakFile + '''');

	SELECT @logicalName = LogicalName FROM #FileList WHERE Type = 'D';
	SELECT @logicalNameLog = LogicalName FROM #FileList WHERE Type = 'L';

	-- READ TARGET LOGICAL NAME
	DELETE FROM #FileList;
	INSERT INTO #FileList
	EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @bakTargetFile + '''');
	SELECT @logicalNameTarget = LogicalName FROM #FileList WHERE Type = 'D';
	SELECT @logicalNameLogTarget = LogicalName FROM #FileList WHERE Type = 'L';

	-- Set database to single user mode
	EXEC('ALTER DATABASE [' + @dbName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE');

	-- Restore database with REPLACE and MOVE
	EXEC('
	RESTORE DATABASE [' + @dbName + ']
	FROM DISK = ''' + @bakFile + '''
	WITH REPLACE,
		MOVE '''+ @logicalName +''' TO ''' + @dataPath + @logicalNameTarget + '.mdf'',
		MOVE ''' + @logicalNameLog + ''' TO ''' + @dataPath + @logicalNameLogTarget + '.ldf'',
		RECOVERY;');

	EXEC ('ALTER DATABASE [' + @dbName + '] SET MULTI_USER');
END
