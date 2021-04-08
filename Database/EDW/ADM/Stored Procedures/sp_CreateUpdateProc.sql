CREATE PROCEDURE [ADM].[sp_CreateUpdateProc]
	@DestinationTable VARCHAR (250) 
	,@JoinFieldList VARCHAR(200) =NULL
	,@SourceTable VARCHAR (250)  = 'CTE_Data'
	,@OutputType VARCHAR(5) ='ALL'
	--,@MergeType  VARCHAR(10) = 'DELTA' --or Update 
	,@SCD_Type TINYINT = 2 -- if 1 then updates current row (setting SyslastUpdateDateTime) , if 2 then archives current record and inserts new 
	,@IncludeNotMatched BIT = 0  
	,@debug_mode BIT = 0 -- If @debug_mode is set to 1, the SQL statements constructed by this procedure will be printed for later examination
	,@Cols_for_Update_Compare NVARCHAR(max) =NULL 
	,@cols_to_exclude nvarchar(max) = NULL -- List of columns to be excluded from the MERGE statement
	,@Proc_Suffix VARCHAR (250)  = ''
	,@Dim_UnknownFlag Bit = 1 
	,@MergeSyntax bit = 0 -- when 1 then Merge Syntax , when 0 then Insert / Update Statements 
    ,@delete_if_not_matched BIT = 0 -- When 1, deletes unmatched source rows from target, when 0 source rows will only be used to update existing rows or insert new.
	,@DuplicateRecordCheck BIT =1 
	,@SourceTableDescription VARCHAR(100) =NULL -- DESCRIPTION of source table for user email
AS
BEGIN 
	DECLARE @StepName VARCHAR(100) ='Start';
    BEGIN TRY
        SET NOCOUNT ON;

		IF @DestinationTable  IS NULL SET @DestinationTable  = @SourceTable; 


		DECLARE @ColumnList NVARCHAR(MAX); 
		DECLARE @EqulateColumns NVARCHAR(MAX);
		DECLARE @CompareColumnsWithIsNUll NVARCHAR(MAX);
		DECLARE @JoinColumns NVARCHAR(MAX);
		DECLARE @MergeUpdateWhereClause NVARCHAR(MAX);
		DECLARE @SQLDimUnknownValue NVARCHAR(MAX);
		DECLARE @SqlPart1  NVARCHAR(MAX),@SqlPart2  NVARCHAR(MAX) ,@SqlPart3  NVARCHAR(MAX);  

		DECLARE @Joins VARCHAR(MAX); 
		DECLARE @UpdateMatchFields VARCHAR(MAX); 
	
		DECLARE @IdentityColumn VARCHAR(100);
			  

		SELECT 
		@DestinationTable = QUOTENAME(object_SCHEMA_NAME(OBJECT_ID)) + '.' + QUOTENAME(OBJECT_NAME(OBJECT_ID))
		FROM sys.objects
		WHERE OBJECT_ID = OBJECT_ID(@DestinationTable);




		DECLARE @SQLHeader VARCHAR(MAX); 	     
		DECLARE @SQLlogStart VARCHAR(MAX); 	     
		DECLARE @SQLlogUpdate VARCHAR(MAX); 	     
		DECLARE @lf AS VARCHAR(5) = CHAR(10); 
		DECLARE @tab VARCHAR(10) = REPLICATE(' ', 4); 
		DECLARE @output NVARCHAR(MAX) = NULL 	
		DECLARE @SQLNonNullColumns NVARCHAR(MAX)  

	exec [ADM].sp_generatemerge 
		@target_table =@DestinationTable --'[dim].[Chart]'
		,@SourceTable=@SourceTable --'[stage].[vw_Chart]'
		,@cols_to_join_on =@JoinFieldList--'SiteKey, RowPointer'
		,@MergeSyntax =@MergeSyntax
		,@SCD_Type = @SCD_Type
		,@output = @output OUTPUT
		,@IdentityColumnList = @IdentityColumn OUTPUT
		,@SQLtargetColumns=@ColumnList OUTPUT 
		,@debug_mode =@debug_mode
		,@results_to_text =1 
		,@Cols_for_Update_Compare = @Cols_for_Update_Compare
		,@cols_to_exclude  = @cols_to_exclude 
		,@EmailProc = '[ADM].usp_SendErrorLogEmail' -- EMail Stored PROC
		,@ErrorLogProc ='[ADM].[usp_ETLLOGErrorInsert]'
		,@SourceTableDescription = @SourceTableDescription 
		,@delete_if_not_matched = @delete_if_not_matched
		,@DuplicateRecordCheck = @DuplicateRecordCheck
		,@SQLNonNullColumns = @SQLNonNullColumns OUTPUT

	if @output is nULL
		RAISERROR (
			'Aborting due to no output from "dbo.sp_generatemerge" ' -- Message text.  
			,16 -- Severity.  
			,1 -- State.  
			);


	DECLARE @objectid INT = OBJECT_ID(@DestinationTable);
	declare @SQLDestinationTableName VARCHAR(250) = QUOTENAME(object_SCHEMA_NAME(@objectid)) + '.' + QUOTENAME(OBJECT_NAME(@objectid));
	declare @SQLPROCName VARCHAR(250) = QUOTENAME(object_SCHEMA_NAME(@objectid)) + '.' + QUOTENAME('usp_Update' + OBJECT_NAME(@objectid) + ltrim(rtrim(isNULL(@Proc_Suffix, '') )))  ;

	DECLARE @Procobjectid INT = OBJECT_ID(@SQLPROCName);
	
	SET @StepName = ' set @SQLHeader'; 
			SET @SQLHeader = iif(@Procobjectid is null , 'CREATE' , 'ALTER') + ' PROCEDURE ' +  @SQLPROCName
			+ @lf +'@ParentLogId BIGINT = NULL'
			+ @lf +'AS  '
		
			+ @lf + @tab  + '---------------------------------------------------------------------------------------------------------------------------------------'
			+ @lf + @tab  + '/*'
			+ @lf + @tab  + '	Name:				' +  @SQLPROCName
			+ @lf + @tab  + '	Author:				'+ SYSTEM_USER 
			+ @lf + @tab  + '	Create date:		' + convert(varchar(20) , GetDate(), 106)
			+ @lf + @tab  + '	Version:			1.01'
			+ @lf + @tab  + '	Description:		Add Data to ' + @SQLDestinationTableName
			+ @lf + @tab  + ''
			+ @lf + @tab  + '	Example:			exec ' + @SQLPROCName
			+ @lf + @tab  + ''
			+ @lf + @tab  + '	Version Updates:'
			+ @lf + @tab  + '	Reference			Version			Date			Updated By				Description'
			+ @lf + @tab  + '	---------			-------			----			----------				-----------'
			+ @lf + @tab  + ' */'
			+ @lf + @tab  + ' ---------------------------------------------------------------------------------------------------------------------------------------'
			+ @lf	
		
			+ @lf + @tab  + '/* Created from :'
			+ @lf + @tab + '-- ' + QUOTENAME (OBJECT_SCHEMA_NAME(@@PROCID)) + '.' + QUOTENAME (OBJECT_NAME(@@PROCID))  
										+ '  @DestinationTable=''' + coalesce(@DestinationTable, '') +'''' 
										+ ' ,' + ' @JoinFieldList=' +''''+  coalesce(@JoinFieldList,'') + '''' 
										+ ' ,' + ' @SourceTable='+''''+  coalesce(@SourceTable,'') + ''''  	
										+ ' ,' + ' @OutputType='+''''+  coalesce(@OutputType ,'') + ''''  
										--+ ' ,' + ' @MergeType='+''''+  coalesce(@MergeType,'') +''''
										+ ' ,' + ' @IncludeNotMatched='+ coalesce(cast(@IncludeNotMatched as varchar(1)) ,'0') 
			 + @lf + @tab  + '*/'
		
			+ @lf + 'BEGIN '
			+ @lf + @tab + 'BEGIN TRY'
			+ @lf + @tab + @tab + 'SET NOCOUNT ON;'
			+ @lf 
			+ @lf + @tab + @tab + 'DECLARE @LogID INT;'
			+ @lf + @tab + @tab + 'EXEC  @LogID = [ADM].[usp_AddETLLOGProcedure]  @source_object_id = @@PROCID, @TableName = '''+ @SQLDestinationTableName + ''',  @ParentLogId = @ParentLogId '
			+ @lf 
			+ @lf + @tab + @tab + 'DECLARE @RowInsert INT, @RowUpdate INT, @RowDelete INT , @TotalRows INT;'
			+ @lf 
			+ @lf + @tab + @tab + 'DECLARE @ETLLOGUpdateMessage NVARCHAR(2048) = NULL, @ErrorFlag BIT = 0 ; '
			+ @lf 

			IF (@MergeSyntax =1 ) 
			BEGIN 
				SET  @SQLHeader +=  @lf + @tab + @tab + 'DECLARE @RowCountStart AS BIGINT;'
				SET  @SQLHeader +=  @lf + @tab + @tab + 'SELECT @RowCountStart = COUNT(1)	FROM '+ @SQLDestinationTableName + ';'
				SET  @SQLHeader +=  @lf 
			END        
			

			
			SET @StepName = ' set Dimension unknown value';		
		
			IF ((OBJECT_SCHEMA_NAME(@objectid) = 'DIM' or OBJECT_NAME(@objectid) like  'DIM%')and @IdentityColumn is not null and @Dim_UnknownFlag  =1)
			BEGIN

		
				DECLARE @SQLNonNullColumnCount int 
				set @SQLNonNullColumnCount = len(@SQLNonNullColumns) - len(replace (@SQLNonNullColumns,', [', ' [') ) 
				if (@SQLNonNullColumnCount <0 )
					SET @SQLNonNullColumnCount = 0


			  SET @SQLDimUnknownValue = 
				  @lf + @tab + @tab + 'IF NOT EXISTS (  SELECT *'
				+ @lf + @tab + @tab + @tab + 'FROM '+@DestinationTable+''
				+ @lf + @tab + @tab + @tab + 'WHERE '+@IdentityColumn+' = -1)'
				+ @lf + @tab + @tab + 'BEGIN '
				+ @lf + @tab + @tab + @tab + 'SET IDENTITY_INSERT '+@DestinationTable+' ON;'
				+ @lf 
				+ @lf + @tab + @tab + @tab + 'INSERT INTO '+@DestinationTable+' (' + @SQLNonNullColumns + ') '
				+ @lf + @tab + @tab + @tab + 'VALUES ( -1' +  REPLICATE(', -1', @SQLNonNullColumnCount )  + '  );'
				+ @lf 
				+ @lf + @tab + @tab + @tab + 'SET IDENTITY_INSERT '+@DestinationTable+' OFF;'
				+ @lf + @tab + @tab + 'END;';
			END;
			ELSE
			BEGIN
				SELECT @SQLDimUnknownValue='';
			END;
			
			SET @SQLlogUpdate =''

			IF (@MergeSyntax =1 ) 
			BEGIN 
				SET @StepName = ' set MergeRowUpdate';
			   SET @SQLlogUpdate =  @lf  
			   + @lf + @tab + @tab  +  'SELECT @RowUpdate = @@RowCount;'
			   + @lf + 
			   + @lf + @tab + @tab +'/*try to calculate the number of rows inserted and updated*/'
			   + @lf + @tab + @tab + 'SELECT @TotalRows = COUNT(1)	FROM '+ @DestinationTable + ';'
			   + @lf + @tab + @tab 
			   + CASE 
					WHEN @SCD_Type =2 then	'SET @RowInsert = @TotalRows - @RowCountStart - @RowUpdate;'
					WHEN @SCD_Type =1 then	'SELECT @RowInsert = ABS(@TotalRows - @RowCountStart ), @RowUpdate = @RowUpdate -  ABS(@TotalRows - @RowCountStart ) ;'
				ELSE ''
				END 
			END        

			SET @SQLlogUpdate +=
			@lf 
			+ @lf + @tab + @tab + 'EXECUTE [ADM].[usp_UpdateETLLOG] @LogID = @LogID, @DataCountInsert = @RowInsert, @DataCountUpdate = @RowUpdate, @DataCountDelete = @RowDelete, @DataCountTotalRows = @TotalRows,  @message = @ETLLOGUpdateMessage , @ErrorFlag = @ErrorFlag;'
			+ @lf 
			+ @lf + @tab + 'END TRY  '
			+ @lf + @tab + 'BEGIN CATCH       -- Execute error retrieval routine.  '
			+ @lf + @tab + @tab + 'EXECUTE [ADM].[usp_RethrowError] @logID = @LogID ;'
			+ @lf + @tab + 'END CATCH; '
			+ @lf 
			+ @lf + 'END'
			+ @lf + 'GO'
				


		IF @OutputType !='ALL'
		SELECT @SQLHeader = '', @SQLlogUpdate='';

		SELECT CAST('<![CDATA[--' + @lf + 'GO'+ @lf 
		+ ISNULL(@SQLHeader, '*ERROR* @SQLHeader') 
		+ ISNULL(@SQLDimUnknownValue, '--??*ERROR* @SQL UNKNOWN Value ')  
		--+ ISNULL(@SqlPart1, '*ERROR* @SqlPart1')  
		--+ ISNULL(@SqlPart2, '*ERROR* @SqlPart2')  
		--+ ISNULL(@SqlPart3, '*ERROR* @SqlPart3')  
		+ @lf + coalesce(@output,  '*ERROR* @output') 
		+ ISNULL(@SQLlogUpdate, '*ERROR* @SQLlogUpdate')  +  @lf  + '--]]>' AS XML);
						   --print  @SqlPart1 + @SqlPart2+ @SqlPart3 + ' FOR XML PATH(''Student''), ROOT(''Sis''), ELEMENTS XSINIL)'

    END TRY  
    BEGIN CATCH       -- Execute error retrieval routine.  
        
		
DECLARE	@vErrorMessage    NVARCHAR(4000),
	@vErrorNumber     INT,
	@vErrorSeverity   INT,
	@vErrorState      INT,
	@vErrorLine       INT,
	@vErrorProcedure  NVARCHAR(126);

-- Assign variables to error-handling functions that 
-- capture information for RAISERROR.
SELECT	@vErrorNumber = ERROR_NUMBER(),
	@vErrorSeverity = ERROR_SEVERITY(),
	@vErrorState = ERROR_STATE(),
	@vErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-'),
	@vErrorLine = ERROR_LINE(),
	@vErrorMessage = ERROR_MESSAGE();

	
   
-- Building the message string that will contain original
-- error information.
SELECT @vErrorMessage = 
N'Error %d, Level %d, State %d, Procedure %s,  Line %d, ' + 
    'Message: '+ @vErrorMessage;

-- Raise an error: msg_str parameter of RAISERROR will contain
-- the original error information.
RAISERROR
(
@vErrorMessage, 
@vErrorSeverity, 
1,               
@vErrorNumber,    -- parameter: original error number.
@vErrorSeverity,  -- parameter: original error severity.
@vErrorState,     -- parameter: original error state.
@vErrorProcedure, -- parameter: original error procedure name.
@vErrorLine       -- parameter: original error line number.
);
    END CATCH; 
END;