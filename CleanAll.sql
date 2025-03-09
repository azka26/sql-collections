GO
DECLARE @TableName NVARCHAR(1000), @sql NVARCHAR(MAX);
DECLARE TableList SCROLL CURSOR FOR 
	SELECT t.name AS TableName 
	FROM sys.tables t
		JOIN sys.schemas s ON t.schema_id = s.schema_id
	WHERE s.name != 'HangFire';

OPEN TableList;

FETCH FIRST FROM TableList INTO @TableName;
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @sql = 'ALTER TABLE [' + @TableName + '] NOCHECK CONSTRAINT ALL'
	EXEC sp_executesql @sql;
	FETCH NEXT FROM TableList INTO @TableName;
END

FETCH FIRST FROM TableList INTO @TableName;
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @sql = 'DELETE FROM [' + @TableName + ']'
	EXEC sp_executesql @sql;
	FETCH NEXT FROM TableList INTO @TableName;
END

FETCH FIRST FROM TableList INTO @TableName;
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @sql = 'ALTER TABLE [' + @TableName + '] WITH CHECK CHECK CONSTRAINT ALL'
	EXEC sp_executesql @sql;
	FETCH NEXT FROM TableList INTO @TableName;
END

CLOSE TableList;
DEALLOCATE TableList;

