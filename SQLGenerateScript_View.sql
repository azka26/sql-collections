DROP TABLE IF EXISTS #SQLScripts;
SELECT CAST('' as NVARCHAR(MAX)) as SqlScript INTO #SQLScripts;
DELETE FROM #SQLScripts;

DECLARE @ViewName NVARCHAR(128);
DECLARE @SQL NVARCHAR(MAX);
DECLARE @SQLCreateView NVARCHAR(MAX);
DECLARE ViewCursor CURSOR FOR 
    SELECT name FROM sys.views WHERE name LIKE 'IQ_%';

OPEN ViewCursor;
FETCH NEXT FROM ViewCursor INTO @ViewName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = 'CREATE TABLE [' + @ViewName + '_Snapshot] (' + CHAR(13)
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
                   CASE WHEN IS_NULLABLE = 'NO' THEN ' NOT NULL' ELSE ' NULL' END + ',' + CHAR(13) 
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @ViewName
    ORDER BY ORDINAL_POSITION

    -- Finalize the statement
    SET @SQL = LEFT(@SQL, LEN(@SQL) - 2) + CHAR(13) + ');' + CHAR(13);

    SET @SQLCreateView = 'CREATE OR ALTER VIEW [' + @ViewName + ']' + CHAR(13)
                            + 'AS' + CHAR(13) 
                            + 'SELECT * FROM [' + @ViewName + '_Snapshot];' + CHAR(13);

    INSERT INTO #SQLScripts (SqlScript) VALUES (@SQL);
    INSERT INTO #SQLScripts (SqlScript) VALUES (@SQLCreateView);

    FETCH NEXT FROM ViewCursor INTO @ViewName;
END

CLOSE ViewCursor;
DEALLOCATE ViewCursor;

SELECT * FROM #SQLScripts;
