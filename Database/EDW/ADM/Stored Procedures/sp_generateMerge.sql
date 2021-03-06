CREATE PROCEDURE [ADM].[sp_generateMerge] (
	@DestinationTable NVARCHAR(776)
	,@JoinFieldList NVARCHAR(MAX) = NULL
	,@SourceTable VARCHAR(250) = NULL
	,@SCD_Type TINYINT = 2 -- if 1 then updates current row (setting SyslastUpdateDateTime) , if 2 then archives current record and inserts new 
	,@SysCurrentFlag_value TINYINT =1--  0 / NULL do not include SysCurrentflag in Join/MATCHING criteria ; if 1 then use SysCurrentflag= 1 ; if 2 then SysCurrentflag> 1 
	,@delete_if_not_matched BIT = 0 -- When 1, deletes unmatched source rows from target, when 0 source rows will only be used to update existing rows or insert new.
	,@debug_mode BIT = 0 -- If @debug_mode is set to 1, the SQL statements constructed by this procedure will be printed for later examination
	,@results_to_text BIT = 0 -- When 0, outputs MERGE statement in an XML fragment. When NULL, only the @output OUTPUT parameter is returned.
	,@output NVARCHAR(MAX) = NULL OUTPUT -- Use this output parameter to return the generated T-SQL batches to the caller (Hint: specify @batch_separator=NULL to output all statements within a single batch)
	,@MergeSyntax BIT = 1 -- when 1 then Merge Syntax , when 0 then Insert / Update Statements 
	 ,@cols_to_exclude NVARCHAR(MAX) = NULL -- List of columns to be excluded from the MERGE statement
	,@Cols_for_Update_Compare NVARCHAR(MAX) =NULL 
	,@IdentityColumnList NVARCHAR(MAX) =NULL OUTPUT 
	,@SQLtargetColumns NVARCHAR(MAX) =NULL OUTPUT
	,@DuplicateRecordCheck BIT = 1 
	,@EmailProc VARCHAR(100) = NULL -- EMail Stored PROC
	,@ErrorLogProc VARCHAR(100) = NULL --'[ADM].[usp_AddETLLOGError]' 
	,@SourceTableDescription VARCHAR(100) = NULL 
	,@SQLNonNullColumns NVARCHAR(MAX)  =NULL OUTPUT 
	,@columns_to_variables VARCHAR(MAX)  = 'ETLLogId;@LogId,SysLastUpdateDateTime;GETUTCDATE()'
	)
AS
SET NOCOUNT ON; 
BEGIN
	PRINT '==== run sp_generateMerge ' + ISNULL(@DestinationTable, 'no target table defined'); 
	DECLARE @objectid INT = OBJECT_ID(@DestinationTable);

	IF @objectid IS NULL
	BEGIN
		PRINT 'DestinationTable ''' + ISNULL(@DestinationTable, '<NULL>') + ''' does not exist';
		RETURN -1;
	END;
	
	--Variable declarations
		DECLARE @SQLDestinationTableName VARCHAR(250);
		DECLARE @CTEFlag BIT = 0;
		DECLARE @delimiter AS VARCHAR(10) = ',';
		
		DECLARE @xml AS XML;
	
		--
		DECLARE @sql NVARCHAR(MAX); -- 
		DECLARE @lf AS VARCHAR(1) = CHAR(13);
		DECLARE @t VARCHAR(1) = CHAR(9);
		--
		DECLARE @SQLSourceColumns NVARCHAR(MAX);
		
		DECLARE @SQLUpdateColumns NVARCHAR(MAX);
		DECLARE @SQLMergeOutputWhere NVARCHAR(MAX);
		DECLARE @SQLInsertColumns NVARCHAR(MAX);
		DECLARE @SQLIdentityColumns NVARCHAR(MAX);
		DECLARE @SQLInsertIdentityColumns NVARCHAR(MAX);
		DECLARE @SQLJoinColumns NVARCHAR(MAX);
		DECLARE @SQLUpdateComparisonColumns NVARCHAR(MAX);
		DECLARE @SQLJoinDuplicateColumnList NVARCHAR(MAX); 
		DECLARE @SQLSourceColumnsExist NVARCHAR(MAX);
		DECLARE @SQLtargetColumnsExist	 NVARCHAR(MAX);
		DECLARE @SQLSourceColumnsValues  NVARCHAR(MAX);
		DECLARE @SQLSourceColumnsMergeOutput  NVARCHAR(MAX);

		DECLARE @syscolumntablelist NVARCHAR(MAX);
		DECLARE @SysCurrentFlagFieldExistsFlag BIT =0 ;
		DECLARE @SQLUpdate NVARCHAR(MAX);
		

		/*table variables */
		DECLARE @TableJoinColumns AS TABLE (columnName VARCHAR(100));
		DECLARE @TableUpdateComparisonColumns AS TABLE (columnName VARCHAR(100));
		

		DECLARE @TableSysColumns AS TABLE (
			columnName VARCHAR(100)
			,is_updateOnly BIT
			);

		CREATE TABLE #TableDestinationColumn (
			Name VARCHAR(100) COLLATE Latin1_General_CI_AS
			,is_computed BIT
			,is_identity BIT
			,is_updateOnly BIT
			,is_SysColumn BIT 
			,is_nullable  BIT
			,DefaultValue VARCHAR(100) COLLATE Latin1_General_CI_AS
			);

		--DO WORK HERE !

		IF @SourceTable IS NULL
		BEGIN
			SET @SourceTable = 'CTE_DATA';
			SET @CTEFlag = 1;
		END;

		SELECT @SQLDestinationTableName = QUOTENAME(object_SCHEMA_NAME(@objectid)) + '.' + QUOTENAME(OBJECT_NAME(@objectid));

		INSERT INTO @TableSysColumns (columnName , is_updateOnly)
		VALUES ('SysStartDateTime',0)
			,('SysStartDate',0)
			,('SysEndDateTime',0)
			,('SysEndDate',0)
			,('SysCurrentFlag',0)
			, ('SysLastUpdateDateTime',1)
			;

	SELECT @syscolumntablelist= STUFF((
					SELECT ', (' + '''' + columnName + '''' + ',' + CAST (is_updateOnly AS VARCHAR(1)) + ') '
					FROM @TableSysColumns AS T 
					FOR XML PATH('')
					), 1, 1, '');




	BEGIN --@TableJoinColumns
		SET @xml = CAST(('<X>' + REPLACE(@JoinFieldList, @delimiter, '</X><X>') + '</X>') AS XML);

		INSERT INTO @TableJoinColumns (columnName)
		SELECT PARSENAME(LTRIM(RTRIM(N.value('.', 'varchar(100)'))), 1) AS VALUE
		FROM @xml.nodes('X') AS T(N);
		IF @debug_mode=1
			SELECT QUOTENAME(columnName) FROM  @TableJoinColumns;
	END;

	BEGIN --@TableUpdateComparisonColumns
		SET @xml = CAST(('<X>' + REPLACE(@Cols_for_Update_Compare, @delimiter, '</X><X>') + '</X>') AS XML);

		INSERT INTO @TableUpdateComparisonColumns (columnName)
		SELECT PARSENAME(LTRIM(RTRIM(N.value('.', 'varchar(100)'))), 1) AS VALUE
		FROM @xml.nodes('X') AS T(N);
		IF @debug_mode=1
			SELECT QUOTENAME(columnName) FROM  @TableUpdateComparisonColumns;
	END;
		
		DECLARE @SQLExcludeTargetColumns NVARCHAR(MAX); 
		
	BEGIN --@TableUpdateComparisonColumns
		SET @xml = CAST(('<X>' + REPLACE(@cols_to_exclude, @delimiter, '</X><X>') + '</X>') AS XML);

		SELECT @SQLExcludeTargetColumns= STUFF((
					SELECT ', (' + '''' + columnName + '''' +  ') '
					FROM (
						SELECT PARSENAME(LTRIM(RTRIM(N.value('.', 'varchar(100)'))), 1) AS columnName
						FROM @xml.nodes('X') AS T(N)
					) AS T 
					FOR XML PATH('')
					), 1, 1, '');

		
	END;
		

	SET @SQL ='INSERT INTO #TableDestinationColumn (
			Name
			,is_computed
			,is_identity
			,is_updateOnly 
			,is_SysColumn
			,is_nullable
			)
		SELECT col.name
			,is_computed
			,is_identity
			,isnull(T.is_updateOnly, 0)
			,is_SysColumn = iif (T.columnName is null, 0, 1)
			,is_nullable
		FROM ' + DB_NAME() + '.sys.columns Col
		left join (select * from (values ' + @syscolumntablelist + ' ) as T (columnName, is_updateOnly) ) T on col.name = T.columnName  
		left join (select * from (values ' + COALESCE(@SQLExcludeTargetColumns,'('''')')  +' ) as TEX (columnName)) as TEX on col.name = TEX.columnName
		WHERE TEX.ColumnName is NULL 
			AND OBJECT_ID =' + CAST(@objectid AS VARCHAR(100));


PRINT @SQL;

	EXECUTE sp_executesql @sql;--, N'@columnname nvarchar(128) OUTPUT', @columnname = @checkhashcolumn OUTPUT
	
	WITH CTE AS (	
		SELECT 
		 REVERSE(PARSENAME(REPLACE(REVERSE(VALUE), ';', '.'), 1)) AS ColumnName
	   , REVERSE(PARSENAME(REPLACE(REVERSE(VALUE), ';', '.'), 2)) AS ColumnVariable
  
	FROM   STRING_SPLIT(@columns_to_variables, ',')
		)
		UPDATE TDC 
		SET  DefaultValue  = ColumnVariable
		FROM 	#TableDestinationColumn TDC 
		INNER JOIN CTE 
			ON CTE.ColumnName = TDC.Name;

	IF EXISTS (
			SELECT 1
			FROM @TableJoinColumns Jt
			LEFT JOIN #TableDestinationColumn Col
				ON Jt.columnName COLLATE Latin1_General_CI_AS = col.Name COLLATE Latin1_General_CI_AS
			WHERE col.Name IS NULL
			)
	BEGIN
		SELECT * FROM #TableDestinationColumn; 
		SELECT * FROM @TableJoinColumns;
		PRINT 'ERROR Requested join field(s) not in destination table ';

		RETURN - 1;
	END;



	DECLARE @JoinhasIndentity BIT = 0 ;
	IF EXISTS(
	SELECT 1 
	 FROM #TableDestinationColumn  Colmn
					WHERE Name COLLATE Latin1_General_CI_AS  IN (SELECT columnName COLLATE Latin1_General_CI_AS  FROM @TableJoinColumns ) 
					AND is_identity =1 
					) 
					BEGIN 
					--print '@TableJoinColumns contains identity'
	SET @JoinhasIndentity  =1;
	END; 

	
	BEGIN -- create column lists
	SELECT @SQLJoinColumns = STUFF((
			SELECT 'AND [DST].' + QUOTENAME(Colmn.Name) + ' = [SRC].' + QUOTENAME(Colmn.Name)  
			FROM #TableDestinationColumn  Colmn
			WHERE 
				Name COLLATE Latin1_General_CI_AS IN (
				SELECT t.columnName COLLATE Latin1_General_CI_AS
				FROM @TableJoinColumns t
			)
			FOR XML PATH('')), 1, 4, '');


				

		SELECT @SQLUpdateComparisonColumns = STUFF((
			SELECT 'AND [DST].' + QUOTENAME(Colmn.Name) + ' != [SRC].' + QUOTENAME(Colmn.Name)  
			FROM #TableDestinationColumn  Colmn
			WHERE 
				Name COLLATE Latin1_General_CI_AS IN (
				SELECT t.columnName COLLATE Latin1_General_CI_AS
				FROM @TableUpdateComparisonColumns t
			)
			FOR XML PATH('')), 1, 4, '');

		SELECT @SQLIdentityColumns = STUFF((
				SELECT 'AND [DST].' + QUOTENAME(Colmn.Name) + ' !=-1 '
				FROM #TableDestinationColumn  Colmn
				WHERE is_computed = 0
					AND is_identity = 1 
					AND is_SysColumn=0
				FOR XML PATH('')
				), 1, 0, '');
		
			SELECT @IdentityColumnList = STUFF((
			SELECT ','+ QUOTENAME (Colmn.Name)   
				FROM #TableDestinationColumn  Colmn
				WHERE is_computed = 0
					AND is_identity = 1 
					AND is_SysColumn=0
			FOR XML PATH('')),1, 1, '');  


		SELECT @SQLInsertIdentityColumns = STUFF((
				SELECT 'AND [DST].' + QUOTENAME(Colmn.Name) + ' IS NULL '
				FROM #TableDestinationColumn  Colmn
				WHERE is_computed = 0
					AND is_identity = 1 
					AND is_SysColumn=0
				FOR XML PATH('')
				), 1, 4, '');

			SELECT @SQLSourceColumns= STUFF((
					SELECT ', [SRC].' + QUOTENAME(Colmn.Name) 
					FROM #TableDestinationColumn  Colmn
					WHERE is_computed = 0
						AND (is_identity = 0 OR @JoinhasIndentity =1 )
						AND is_updateOnly =0
						AND is_SysColumn=0
					FOR XML PATH('')
					), 1, 1, '');

			SELECT @SQLSourceColumnsExist = STUFF((
					SELECT ', [SRC].' + QUOTENAME(Colmn.Name) 
					FROM #TableDestinationColumn  Colmn
					WHERE is_computed = 0
						AND (is_identity = 0 OR @JoinhasIndentity =1 )
						AND is_updateOnly =0
						AND is_SysColumn=0
						AND DefaultValue IS NULL
					FOR XML PATH('')
					), 1, 1, '');
			
			SELECT @SQLSourceColumnsValues = STUFF((
					SELECT ', ' + COALESCE(Colmn.DefaultValue ,  '[SRC].' + QUOTENAME(Colmn.Name) )
					FROM #TableDestinationColumn  Colmn
					WHERE is_computed = 0
						AND (is_identity = 0 OR @JoinhasIndentity =1 )
						AND is_updateOnly =0
						AND is_SysColumn=0
					FOR XML PATH('')
					), 1, 1, '');
			
			SELECT @SQLSourceColumnsMergeOutput = STUFF((
					SELECT ', ' + COALESCE(Colmn.DefaultValue + ' AS ' + QUOTENAME(Colmn.Name)  ,  '[SRC].' + QUOTENAME(Colmn.Name) )
					FROM #TableDestinationColumn  Colmn
					WHERE is_computed = 0
						AND (is_identity = 0 OR @JoinhasIndentity =1 )
						AND is_updateOnly =0
						AND is_SysColumn=0
					FOR XML PATH('')
					), 1, 1, '');

			SELECT @SQLtargetColumns= STUFF((
					SELECT ', [DST].' + QUOTENAME(Colmn.Name) 
					FROM #TableDestinationColumn  Colmn
					WHERE is_computed = 0
						AND (is_identity = 0 OR @JoinhasIndentity =1 )
						AND is_updateOnly =0
						AND is_SysColumn=0
					FOR XML PATH('')
					), 1, 1, '');
					
			SELECT @SQLtargetColumnsExist = STUFF(( /*Same as @SQLtargetColumns but ignoring columns where there is a Default value */
					SELECT ', [DST].' + QUOTENAME(Colmn.Name) 
					FROM #TableDestinationColumn  Colmn
					WHERE is_computed = 0
						AND (is_identity = 0 OR @JoinhasIndentity =1 )
						AND is_updateOnly =0
						AND is_SysColumn=0
						AND DefaultValue IS NULL
					FOR XML PATH('')
					), 1, 1, '');

			SELECT @SQLUpdateColumns= COALESCE(STUFF((
					SELECT ', [DST].' + QUOTENAME(Colmn.Name) + ' = ' + COALESCE(Colmn.DefaultValue  , '[SRC].' + QUOTENAME(Colmn.Name)   ) 
					FROM #TableDestinationColumn  Colmn
					WHERE is_computed = 0
						AND is_identity = 0 
						AND (is_SysColumn=0 OR is_updateOnly =1)
						AND Name COLLATE Latin1_General_CI_AS NOT IN (
							SELECT t.columnName COLLATE Latin1_General_CI_AS
							FROM @TableJoinColumns t
						)
					FOR XML PATH('')
					), 1, 1, ''), '/*No Update Columns as already used in Join Columns */') ;
					
			SELECT @SQLInsertColumns= STUFF((
					SELECT ', ' + QUOTENAME(Colmn.Name) 
					FROM #TableDestinationColumn  Colmn
					WHERE is_computed = 0
						AND (is_identity = 0 OR @JoinhasIndentity =1 )
						AND is_updateOnly =0
						AND is_SysColumn=0
					FOR XML PATH('')
					), 1, 1, '');

		
		SELECT @SQLMergeOutputWhere = STUFF((
			SELECT 'AND MRG.' + QUOTENAME(Colmn.Name) + ' IS NOT NULL '
			FROM #TableDestinationColumn Colmn
			WHERE 
				is_computed = 0
				AND (is_identity = 0 OR @JoinhasIndentity = 1)
				AND Name COLLATE Latin1_General_CI_AS IN (
					SELECT t.columnName COLLATE Latin1_General_CI_AS
					FROM @TableJoinColumns t
					)
			FOR XML PATH('')), 1, 4, '');

		SELECT @SQLJoinDuplicateColumnList = STUFF((
				SELECT ',' + QUOTENAME(Colmn.Name) 
				FROM #TableDestinationColumn  Colmn
				WHERE 
					Name COLLATE Latin1_General_CI_AS IN (
					SELECT t.columnName COLLATE Latin1_General_CI_AS
					FROM @TableJoinColumns t
				)
				FOR XML PATH('')), 1, 1, '');



		DECLARE @SQLDuplicateColumnCASTList NVARCHAR(MAX); 
		SELECT @SQLDuplicateColumnCASTList = STUFF((
				SELECT ', "'' + CAST(SRC.'+QUOTENAME(Colmn.NAME) +' AS VARCHAR(1000)) + ''"' 
				FROM #TableDestinationColumn  Colmn
				WHERE 
					Name COLLATE Latin1_General_CI_AS IN (
					SELECT t.columnName COLLATE Latin1_General_CI_AS
					FROM @TableJoinColumns t
				)
				FOR XML PATH('')), 1, 1, '');
			

				
		SELECT @SQLNonNullColumns = STUFF((
		SELECT ', '+ QUOTENAME (Colmn.Name)   
			FROM #TableDestinationColumn  Colmn
			WHERE is_computed = 0
				AND (is_identity = 1 
				OR is_nullable =0 )
				AND is_SysColumn=0
		FOR XML PATH('')),1, 1, '');  
			END;
			
		IF EXISTS (SELECT 1 FROM #TableDestinationColumn WHERE name = 'SysCurrentFlag' 	AND is_SysColumn=1) --AND @SCD_Type =2
		BEGIN 
			SET @SysCurrentFlagFieldExistsFlag=1;
		END; 
					
		IF @SCD_Type = 2 
			SET @SQLUpdate =  '[DST].[SysCurrentFlag] = 0,  [DST].[SysEndDateTime] = GETUTCDATE()   ';
		ELSE 
			SET @SQLUpdate = @SQLUpdateColumns; 


	
		IF @debug_mode=1
		BEGIN 
			PRINT 'Identity Column:     ' + ISNULL( @SQLIdentityColumns, 'ERROR');
			
			PRINT '@SQLSourceColumns :  ' + ISNULL(@SQLSourceColumns, 'ERROR');
			PRINT '@SQLtargetColumns :  ' + ISNULL( @SQLtargetColumns, 'ERROR');
			PRINT '@SQLUpdateColumns    ' + ISNULL( @SQLUpdateColumns, 'ERROR');
			PRINT '@SQLMergeOutputWhere ' + ISNULL( @SQLMergeOutputWhere, 'ERROR');
			PRINT '@SQLJoinColumns      ' + ISNULL( @SQLJoinColumns, 'ERROR');
			PRINT '@SQLUpdate           ' + ISNULL( @SQLUpdate, 'ERROR');
			PRINT '@SQLInsertIdentityColumns' + ISNULL( @SQLInsertIdentityColumns, 'ERROR');
	END; 
	IF  @SQLInsertIdentityColumns IS NULL 
	BEGIN 
	RAISERROR (
			'Aborting dbo.sp_generatemerge  as no Identity Column defined ' -- Message text.  
			,16 -- Severity.  
			,1 -- State.  
			);

	END; 

	SET @output ='';
	
	DECLARE @indent INT = 1; 
	IF @SCD_Type = 2
		SET @indent =2;

	--	print @indent 

	DECLARE @ti VARCHAR(100) = REPLICATE(@t , @indent); 
	DECLARE @t2 VARCHAR(100) =  @t + @t ;
	DECLARE @t3 VARCHAR(100) =  @t2 + @t;
	DECLARE @t4 VARCHAR(100) =  @t3 + @t;

	IF NOT (COALESCE(@MergeSyntax, 1) = 1 ) OR @DuplicateRecordCheck =1
	BEGIN

			
		IF (@SourceTableDescription IS NULL)
			SET @SourceTableDescription = @SourceTable;
		/* change non XML chars to Allowed chars*/
		SET @SourceTableDescription =  REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@SourceTableDescription, '[',''), ']',''), '<',''), '>',''), '&','_'), '.','_');

		SET @output += @lf + @t + @t + 'BEGIN /*Duplicate Record Check */';

		SET @output += @lf + @t + @t2 + 'DECLARE @DuplicateRecords VARCHAR(max);'

		SET @output += @lf + @t + @ti + @t + 'SELECT @DuplicateRecords = '''+@SQLJoinDuplicateColumnList+''' +  SUBSTRING(('
		SET @output += @lf + @t + @ti + @t + @t + 'SELECT '', ('+@SQLDuplicateColumnCASTList+')'''
		SET @output += @lf + @t + @ti + @t + @t2 + ' FROM '
		SET @output += @lf + @t + @ti + @t + @t2 + ' '+ @SourceTable +' SRC'
		SET @output += @lf + @t + @ti + @t + @t + ' GROUP BY '
		SET @output += @lf + @t + @ti + @t + @t2 + @SQLJoinDuplicateColumnList
		SET @output += @lf + @t + @ti + @t + @t2 + ' '
		SET @output += @lf + @t + @ti + @t + @t2 + ' HAVING COUNT(1) !=1'
		SET @output += @lf + @t + @ti + @t + 'FOR XML PATH('''')'
		SET @output += @lf + @t + @ti + @t + '), 3, 200000);'

		SET @output += @lf + @t + @t2 + 'IF @DuplicateRecords IS NOT NULL';
		
		IF ( @ErrorLogProc IS NOT NULL) 
		BEGIN
			SET @output += @lf + @t + @t2 + 'BEGIN';
			SET @output += @lf + @t + @t2 + '	EXEC '+ @ErrorLogProc +' @LogId = @LogId, @Error = @DuplicateRecords ,@UserTableDescription = ''' + @SourceTableDescription +  ''' , @ErrorType = ''Duplicate'';';
			SET @output += @lf + @t + @t2 + '	SET @ETLLOGUpdateMessage =''Duplicates found in Staging Data. See LogError SubTable for Details.''';
			SET @output += @lf + @t + @t2 + '	SET @ErrorFlag = 1';
			IF ( @ErrorLogProc IS NOT NULL AND @EmailProc IS NOT NULL ) 
			BEGIN
				SET @output += @lf + @t + @t2 + '	EXECUTE '+ @EmailProc+'  @LogId;';
			END;
			SET @output += @lf + @t + @t3 + 'RAISERROR (';
			SET @output += @lf + @t + @t4 + '''Duplicates found in Staging Data. Select * from ADM.ETLLOGError WHERE LogId = %d'' -- Message text.  ';
			SET @output += @lf + @t + @t4 + ',16 -- Severity.  ';
			SET @output += @lf + @t + @t4 + ',1 -- State.  ';
			SET @output += @lf + @t + @t4 + ',@LogId';
			SET @output += @lf + @t + @t4 + ');';
			SET @output += @lf + @t + @t2 + 'END';
		END; 
		ELSE
		
		BEGIN
			SET @output += @lf + @t + @t2 + 'BEGIN';
			SET @output += @lf + @t + @t3 + 'RAISERROR (';
			SET @output += @lf + @t + @t4 + '''Aborting ETL due to Duplicates :  %s'' -- Message text.  ';
			SET @output += @lf + @t + @t4 + ',16 -- Severity.  ';
			SET @output += @lf + @t + @t4 + ',1 -- State.  ';
			SET @output += @lf + @t + @t4 + ',@DuplicateRecords';
			SET @output += @lf + @t + @t4 + ');';
			SET @output += @lf + @t + @t2 + 'END;';
		END;
		SET @output += @lf + @t + @t + 'END;	';	
		
		SET @output += @lf;
		
	END; 


	IF @JoinhasIndentity =1
	BEGIN 
		SET @output += @lf + @t + 'SET IDENTITY_INSERT ' + @SQLDestinationTableName + ' ON;';
		SET @output += @lf;
	END; 

	IF @CTEFlag =1 
	BEGIN 
		SET @output += @lf + @t + 'WITH ' + @SourceTable + ' AS ()';
	END; 

	DECLARE @TempTableNameSCD_Type2 VARCHAR(100);
	IF @MergeSyntax =1 OR @MergeSyntax IS NULL
	BEGIN 
		IF @SCD_Type = 2
		BEGIN 
			SET @TempTableNameSCD_Type2 = '#temp_STG_'+OBJECT_NAME(@objectid);
			
			SET @output += @lf + @ti + '/* Use #Temp table to workaround the merge/foreign key error that would occur if inserting directing into the target table */';

	 		SET @output += @lf + @ti + 'SELECT ' + @SQLInsertColumns;
			SET @output += @lf + @ti + 'INTO '+ @TempTableNameSCD_Type2; 
			SET @output += @lf + @ti + 'FROM ' + @SQLDestinationTableName; 
			SET @output += @lf + @ti + 'WHERE 1=0 ';
			SET @output += @lf; 

			SET @output += @lf + @ti + 'INSERT INTO ' + @TempTableNameSCD_Type2 + '(' + @SQLInsertColumns + ')';
			SET @output += @lf + @ti + 'SELECT ' + @SQLInsertColumns; 
			SET @output += @lf + @ti + 'FROM ( ';
		END;	  

		SET @output += @lf + @ti + @t + 'MERGE INTO ' + @SQLDestinationTableName + ' AS DST ';
		
		BEGIN 
			SET @output += @lf + @ti + @t + 'USING ' + @SourceTable + ' AS SRC ';
		END; 
		SET @output += @lf + @ti + @t2 + 'ON ('; 
		SET @output += @lf + @ti + @t3 + REPLACE(@SQLJoinColumns , 'AND [DST].',  @lf + @ti + @t + @t + 'AND [DST].'); 
			
		SET @output += @lf + @ti + @t2 + ')' ;

		IF @SysCurrentFlagFieldExistsFlag =1  AND ISNULL(@SysCurrentFlag_value, 0)  >0
		BEGIN 
		SET @output += @lf + @ti + @t2 + 
			CASE 
				WHEN @SysCurrentFlag_value = 1 THEN 'AND [DST].[SysCurrentFlag] IN (1)' 
				WHEN @SysCurrentFlag_value >= 2 THEN 'AND [DST].[SysCurrentFlag] IN (1,2)' 
			END; 
		END;
		
		
		SET @output += @lf + @ti + @t + 'WHEN NOT MATCHED BY TARGET ';
		SET @output += @lf + @ti + @t2 + 'THEN ';
		SET @output += @lf + @ti + @t3 + 'INSERT (' + @SQLInsertColumns + ') ';
		SET @output += @lf + @ti + @t3 + 'VALUES (' + @SQLSourceColumnsValues + ') ';
		SET @output += @lf + @ti + @t + 'WHEN MATCHED ';
		SET @output += @lf + @ti + @t2 + 'AND  EXISTS(';
		SET @output += @lf + @ti + @t3 + 'SELECT ' + @SQLSourceColumnsExist;
		SET @output += @lf + @ti + @t3 + 'EXCEPT';
		SET @output += @lf + @ti + @t3 + 'SELECT ' + @SQLtargetColumnsExist;
		SET @output += @lf + @ti + @t2 + ')';
		SET @output += @lf + @ti + @t2 + 'THEN ';
		SET @output += @lf + @ti + @t3 + 'UPDATE  ';
		SET @output += @lf + @ti + @t3 + 'SET';
	
		SET @output += @lf + @ti + @t4 + REPLACE( @SQLUpdate, ', [DST].' , @lf + @ti + @t4 + ',[DST].');

		IF @delete_if_not_matched =1 
		BEGIN
			SET @output += @lf + @ti + @t + 'WHEN NOT MATCHED BY SOURCE';
			SET @output += @lf + @ti + @t2 + 'THEN';
			SET @output += @lf + @ti + @t3 + 'DELETE';
		END;

		IF @SCD_Type = 2
		BEGIN 
			SET @output += @lf + @ti + @t + 'OUTPUT ' + @SQLSourceColumnsMergeOutput + ' ,$Action AS MergeAction';
			SET @output += @lf + @ti + @t + ') AS MRG  ';
			SET @output += @lf + @ti + 'WHERE MRG.MergeAction = ''UPDATE''';
			SET @output += @lf + @ti + 'AND ' + ISNULL(@SQLMergeOutputWhere, '/*TODO : SET @SQLMergeOutputWhere COLUMNS */'); 
		END;

		SET @output += ';';  --Merge Terminator
		SET @output += @lf; 
		SET @output += @lf + @ti + 'SELECT @RowUpdate = @@ROWCOUNT; ';
		
		IF @SCD_Type = 2
		BEGIN 
			SET @output += @lf; 
			SET @output += @lf + @ti + 'INSERT INTO ' + @SQLDestinationTableName + '(' + @SQLInsertColumns + ')';
			SET @output += @lf + @ti + 'SELECT ' + @SQLInsertColumns;
			SET @output += @lf + @ti + 'FROM '+ @TempTableNameSCD_Type2; 
			SET @output += @lf; 
			SET @output += @lf + @ti + 'SELECT @RowUpdate += @@ROWCOUNT; ';
		END; 
	END;
	ELSE 
	BEGIN -- TSQL INSERT /Update Statements 

		IF LEN(@cols_to_exclude) > 0 
		BEGIN 
			SET @output += @lf + @ti + @t + '--Note : Ignoring Columns from Insert/Update: "' + @cols_to_exclude +'"';
			SET @output += @lf; 
		END; 

		BEGIN -- UPDATE
			SET @output += @lf + @ti + @t + 'UPDATE DST';
			SET @output += @lf + @ti + @t + 'SET ';
			SET @output += @lf + @ti + @t2 + REPLACE(@SQLUpdateColumns , '[DST].' , '');
			SET @output += @lf + @ti + @t + 'FROM ' + @SQLDestinationTableName + ' AS DST ';
			SET @output += @lf + @ti + @t + 'INNER JOIN ' + @SourceTable + ' AS SRC ';
			SET @output += @lf + @ti + @t2 + 'ON '; 
			SET @output += @lf + @ti + @t3 + REPLACE(@SQLJoinColumns , 'AND [DST].',  @lf + @ti + @t3 + 'AND [DST].'); 

			IF LEN(@SQLUpdateComparisonColumns) > 0 
			BEGIN 
				SET @output += @lf + @ti + @t + 'WHERE ' + @SQLUpdateComparisonColumns;
			END; 
			ELSE 
			BEGIN 
				SET @output += @lf + @ti + @t + 'WHERE EXISTS(';
				SET @output += @lf + @ti + @t3 + 'SELECT ' + @SQLtargetColumnsExist;
				SET @output += @lf + @ti + @t3 + 'EXCEPT';
				SET @output += @lf + @ti + @t3 + 'SELECT ' + @SQLSourceColumnsExist;
				SET @output += @lf + @ti + @t2 + ')';
			END; 
			SET @output += ';'; 
			SET @output += @lf ;
			SET @output += @lf + @ti + @t  + 'SELECT @RowUpdate = @@ROWCOUNT; ';
			SET @output += @lf ;
		END; 


		BEGIN -- INSERT 
			SET @output += @lf + @ti + @t + 'INSERT INTO ' + @SQLDestinationTableName + '(' + @SQLInsertColumns + ')';
			SET @output += @lf + @ti + @t + 'SELECT ' +  @SQLSourceColumnsMergeOutput; -- @SQLSourceColumns; 
			SET @output += @lf + @ti + @t + 'FROM ' + @SourceTable + ' AS SRC ';
			SET @output += @lf + @ti + @t + 'LEFT JOIN ' + @SQLDestinationTableName + ' AS DST ';
			SET @output += @lf + @ti + @t2 + 'ON '; 
			SET @output += @lf + @ti + @t3 + REPLACE(@SQLJoinColumns , 'AND [DST].',  @lf + @ti + @t + @t + 'AND [DST].'); 
			SET @output += @lf + @ti + @t + 'WHERE ' +  @SQLInsertIdentityColumns ;
			SET @output += ';';
		
			SET @output += @lf ;
			SET @output += @lf + @ti + @t  + 'SELECT @RowInsert = @@ROWCOUNT; ';
			SET @output += @lf ;
		
		END; 

	END; 
	
	IF @JoinhasIndentity =1
	BEGIN 
		SET @output += @lf + @lf + @t + 'SET IDENTITY_INSERT ' + @SQLDestinationTableName + ' OFF;';
	END; 
	PRINT '==== END sp_generateMerge ';

	IF @results_to_text !=1 
	BEGIN 
		--SELECT @output;
		SELECT CAST('<![CDATA[--' + @lf + @output + @lf + '--]]>' AS XML);
	END; 
		
END;