USE master;
GO
CREATE OR ALTER PROCEDURE SpMyDuplicateDb
	@sourceDbName NVARCHAR(MAX),
	@targetDbName NVARCHAR(MAX)
AS
BEGIN
	DECLARE @sourceDB NVARCHAR(MAX) = @sourceDbName;
	DECLARE @dbName NVARCHAR(MAX) = @targetDbName;
	DECLARE @bakFile NVARCHAR(MAX) = '/var/opt/mssql/backup/' + FORMAT(GETDATE(), 'yyyyMMddHHmmssfff') + '.bak';
	DECLARE @dataPath NVARCHAR(MAX) = '/var/opt/mssql/data/';
	DECLARE @sql NVARCHAR(MAX);
	DECLARE @logicalName NVARCHAR(MAX);
	DECLARE @logicalNameLog NVARCHAR(MAX);

	BACKUP DATABASE @sourceDB
	TO DISK = @bakFile
	WITH FORMAT,
	  MEDIANAME = 'SQLServerBackups',
	  NAME = 'Full Backup of testing_rizal';
  
	IF EXISTS (SELECT name FROM sys.databases WHERE name = @dbName)
	BEGIN
		EXEC('DROP DATABASE ' + @dbName);
	END
	EXEC('CREATE DATABASE ' + @dbName);

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
	INSERT INTO #FileList
	EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @bakFile + '''');

	SELECT @logicalName = LogicalName FROM #FileList WHERE Type = 'D';
	SET @logicalNameLog = @logicalName + '_log'


	-- Set database to single user mode
	EXEC('ALTER DATABASE [' + @dbName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE');

	-- Restore database with REPLACE and MOVE
	EXEC('
	RESTORE DATABASE [' + @dbName + ']
	FROM DISK = ''' + @bakFile + '''
	WITH REPLACE,
		MOVE '''+ @logicalName +''' TO ''' + @dataPath + @dbName + '.mdf'',
		MOVE ''' + @logicalNameLog + ''' TO ''' + @dataPath + @dbName + '_log.ldf'',
		RECOVERY;');

	EXEC ('ALTER DATABASE [' + @dbName + '] SET MULTI_USER');
END


GO
CREATE OR ALTER PROCEDURE SpMyRestoreDb
	@targetDbName NVARCHAR(MAX),
	@bakFileName NVARCHAR(MAX)
AS
BEGIN
	DECLARE @dbName NVARCHAR(MAX) = @targetDbName;
	DECLARE @bakFile NVARCHAR(MAX) = '/var/opt/mssql/data/backup/' + @bakFileName;
	DECLARE @dataPath NVARCHAR(MAX) = '/var/opt/mssql/data/';
	DECLARE @sql NVARCHAR(MAX);
	DECLARE @logicalName NVARCHAR(MAX);
	DECLARE @logicalNameLog NVARCHAR(MAX);

	IF EXISTS (SELECT name FROM sys.databases WHERE name = @dbName)
	BEGIN
		EXEC('DROP DATABASE ' + @dbName);
	END
	EXEC('CREATE DATABASE ' + @dbName);

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
	INSERT INTO #FileList
	EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @bakFile + '''');

	SELECT @logicalName = LogicalName FROM #FileList WHERE Type = 'D';
	SET @logicalNameLog = @logicalName + '_log'


	-- Set database to single user mode
	EXEC('ALTER DATABASE [' + @dbName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE');

	-- Restore database with REPLACE and MOVE
	EXEC('
	RESTORE DATABASE [' + @dbName + ']
	FROM DISK = ''' + @bakFile + '''
	WITH REPLACE,
		MOVE '''+ @logicalName +''' TO ''' + @dataPath + @dbName + '.mdf'',
		MOVE ''' + @logicalNameLog + ''' TO ''' + @dataPath + @dbName + '_log.ldf'',
		RECOVERY;');

	EXEC ('ALTER DATABASE [' + @dbName + '] SET MULTI_USER');
END

GO
USE master;
EXEC SpMyDuplicateDb @sourceDbName = N'source-db-name', @targetDbName = N'target-db-name';
EXEC SpMyRestoreDb @targetDbName = N'target-db-name', @bakFileName = N'file-name.bak';
