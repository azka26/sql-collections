DECLARE @TableName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);
DECLARE @PKCols NVARCHAR(MAX);
DECLARE TableCursor CURSOR FOR 
    SELECT name FROM sys.tables WHERE name LIKE 'IQ_%';

OPEN TableCursor;
FETCH NEXT FROM TableCursor INTO @TableName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'CREATE TABLE [' + @TableName + '] (' + CHAR(13)

    -- Build column definitions
    SELECT @SQL += '    [' + COLUMN_NAME + '] ' + 
                   DATA_TYPE +
                   CASE 
                       WHEN DATA_TYPE IN ('nvarchar', 'varchar', 'char', 'nchar', 'varbinary') THEN 
                           CASE 
                               WHEN CHARACTER_MAXIMUM_LENGTH = -1 THEN '(MAX)' 
                               ELSE '(' + CAST(CHARACTER_MAXIMUM_LENGTH AS VARCHAR) + ')' 
                           END 
                       ELSE '' 
                   END +
                   CASE 
                       WHEN COLUMNPROPERTY(OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME), COLUMN_NAME, 'IsIdentity') = 1 
                           THEN ' IDENTITY(1,1)' 
                       ELSE '' 
                   END +
                   CASE WHEN IS_NULLABLE = 'NO' THEN ' NOT NULL' ELSE ' NULL' END + ',' + CHAR(13)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @TableName
    ORDER BY ORDINAL_POSITION;

    -- Get Primary Key columns (comma-separated)
    SELECT @PKCols = STRING_AGG('[' + kcu.COLUMN_NAME + ']', ', ')
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
    JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
        ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    WHERE tc.TABLE_NAME = @TableName AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY';

    -- Append PK constraint if exists
    IF @PKCols IS NOT NULL
        SET @SQL += '    CONSTRAINT [PK_' + @TableName + '] PRIMARY KEY (' + @PKCols + ')' + CHAR(13)

    -- Finalize
    SET @SQL = LEFT(@SQL, LEN(@SQL) - 1) + CHAR(13) +');' + CHAR(13);
    PRINT @SQL;

    FETCH NEXT FROM TableCursor INTO @TableName;
END

CLOSE TableCursor;
DEALLOCATE TableCursor;
