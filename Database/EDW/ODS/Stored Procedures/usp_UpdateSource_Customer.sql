CREATE PROCEDURE [ODS].[usp_UpdateSource_Customer]
@ParentLogId BIGINT = NULL
AS  
    /* Created from :
    -- [ADM].[sp_CreateUpdateProc]  @DestinationTable='[ODS].[Source_Customer]' , @JoinFieldList='CustomerCode' , @SourceTable='LND.[Source_Customer]' , @OutputType='ALL' , @IncludeNotMatched=0
    */
BEGIN 
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @LogId INT;
        EXEC  @LogId = [ADM].[usp_AddETLLOGProcedure]  @source_object_id = @@PROCID, @TableName = '[ODS].[Source_Customer]',  @ParentLogId = @ParentLogId 

        DECLARE @RowInsert INT, @RowUpdate INT, @RowDelete INT , @TotalRows INT;

        DECLARE @ETLLOGUpdateMessage NVARCHAR(2048) = NULL, @ErrorFlag BIT = 0 ; 


		BEGIN /*Duplicate Record Check */
			DECLARE @DuplicateRecords VARCHAR(max);
				SELECT @DuplicateRecords = '[CustomerCode]' +  SUBSTRING((
					SELECT ', ( "' + CAST(SRC.[CustomerCode] AS VARCHAR(1000)) + '")'
						 FROM 
						 LND.[Source_Customer] SRC
					 GROUP BY 
						[CustomerCode]
						 
						 HAVING COUNT(1) !=1
				FOR XML PATH('')
				), 3, 200000);
			IF @DuplicateRecords IS NOT NULL
			BEGIN
				RAISERROR (
					'Aborting ETL due to Duplicates :  %s' -- Message text.  
					,16 -- Severity.  
					,1 -- State.  
					,@DuplicateRecords
					);
			END;
		END;	

			UPDATE DST
			SET 
				 [FirstName] = [SRC].[FirstName], [Surname] = [SRC].[Surname], [CreatedOn] = [SRC].[CreatedOn], [ModifiedOn] = [SRC].[ModifiedOn]
			FROM [ODS].[Source_Customer] AS DST 
			INNER JOIN LND.[Source_Customer] AS SRC 
				ON 
					[DST].[CustomerCode] = [SRC].[CustomerCode]
			WHERE [DST].[ModifiedOn] != [SRC].[ModifiedOn];

			SELECT @RowUpdate = @@ROWCOUNT; 

			INSERT INTO [ODS].[Source_Customer]( [CustomerCode], [FirstName], [Surname], [CreatedOn], [ModifiedOn])
			SELECT  [SRC].[CustomerCode], [SRC].[FirstName], [SRC].[Surname], [SRC].[CreatedOn], [SRC].[ModifiedOn]
			FROM LND.[Source_Customer] AS SRC 
			LEFT JOIN [ODS].[Source_Customer] AS DST 
				ON 
					[DST].[CustomerCode] = [SRC].[CustomerCode]
			WHERE [DST].[ODSCustomerId] IS NULL ;

			SELECT @RowInsert = @@ROWCOUNT; 

        EXECUTE [ADM].[usp_UpdateETLLog] @LogId = @LogId, @DataCountInsert = @RowInsert, @DataCountUpdate = @RowUpdate, @DataCountDelete = @RowDelete, @DataCountTotalRows = @TotalRows,  @message = @ETLLOGUpdateMessage , @ErrorFlag = @ErrorFlag;

    END TRY  
    BEGIN CATCH       -- Execute error retrieval routine.  
        EXECUTE [ADM].[usp_RethrowError] @LogId = @LogId ;
    END CATCH; 

END