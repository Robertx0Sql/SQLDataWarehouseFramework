CREATE PROCEDURE [ODS].[usp_UpdateSource_Customer]
@ParentLogId BIGINT = NULL
AS  
    ---------------------------------------------------------------------------------------------------------------------------------------
    /*
    	Name:				[ODS].[usp_UpdateSource_Customer]
    	Author:				SATURN\Robert
    	Create date:		09 Apr 2021
    	Version:			1.01
    	Description:		Add Data to [ODS].[Source_Customer]
    
    	Example:			exec [ODS].[usp_UpdateSource_Customer]
    
    	Version Updates:
    	Reference			Version			Date			Updated By				Description
    	---------			-------			----			----------				-----------
     */
     ---------------------------------------------------------------------------------------------------------------------------------------

    /* Created from :
    -- [ADM].[sp_CreateUpdateProc]  @DestinationTable='[ODS].[Source_Customer]' , @JoinFieldList='CustomerCode' , @SourceTable='LND.[Source_Customer]' , @OutputType='ALL' , @IncludeNotMatched=0
    */
BEGIN 
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @LogID INT;
        EXEC  @LogID = [ADM].[usp_AddETLLOGProcedure]  @source_object_id = @@PROCID, @TableName = '[ODS].[Source_Customer]',  @ParentLogId = @ParentLogId 

        DECLARE @RowInsert INT, @RowUpdate INT, @RowDelete INT , @TotalRows INT;

        DECLARE @ETLLOGUpdateMessage NVARCHAR(2048) = NULL, @ErrorFlag BIT = 0 ; 

        DECLARE @RowCountStart AS BIGINT;
        SELECT @RowCountStart = COUNT(1)	FROM [ODS].[Source_Customer];


		BEGIN /*Duplicate Record Check */
			DECLARE @DuplicateRowXml XML;
			SET @DuplicateRowXml  =(
				SELECT   [SRC].[CustomerCode], [SRC].[FirstName], [SRC].[Surname], [SRC].[CreatedOn], [SRC].[ModifiedOn]
				FROM LND.[Source_Customer] src 
				INNER JOIN (
							SELECT [CustomerCode]
							FROM LND.[Source_Customer]
							GROUP BY [CustomerCode]
							HAVING COUNT(1) != 1 
						) DST 	
						ON [DST].[CustomerCode] = [SRC].[CustomerCode]
					FOR XML RAW('row') ,ROOT('LND_Source_Customer') 
			)
			IF  @DuplicateRowXml  IS NOT NULL 
			BEGIN
				DECLARE @DuplicateString VARCHAR(2000) 
				SET @DuplicateString = CAST(@DuplicateRowXml AS VARCHAR(2000))
				RAISERROR (
					'Aborting ETL due to Duplicates :  %s' -- Message text.  
					,16 -- Severity.  
					,1 -- State.  
					,@DuplicateString
					);
			END;
		END;	

		INSERT INTO [ODS].[Source_Customer]( [CustomerCode], [FirstName], [Surname], [CreatedOn], [ModifiedOn])
		SELECT  [CustomerCode], [FirstName], [Surname], [CreatedOn], [ModifiedOn]
		FROM ( 
			MERGE INTO [ODS].[Source_Customer] AS DST 
			USING LND.[Source_Customer] AS SRC 
				ON (
					[DST].[CustomerCode] = [SRC].[CustomerCode]
				)
				AND [DST].[SysCurrentFlag] IN (1)
			WHEN NOT MATCHED BY TARGET 
				THEN 
					INSERT ( [CustomerCode], [FirstName], [Surname], [CreatedOn], [ModifiedOn]) 
					VALUES ( [SRC].[CustomerCode], [SRC].[FirstName], [SRC].[Surname], [SRC].[CreatedOn], [SRC].[ModifiedOn]) 
			WHEN MATCHED 
				AND  EXISTS(
					SELECT  [SRC].[CustomerCode], [SRC].[FirstName], [SRC].[Surname], [SRC].[CreatedOn], [SRC].[ModifiedOn]
					EXCEPT
					SELECT  [DST].[CustomerCode], [DST].[FirstName], [DST].[Surname], [DST].[CreatedOn], [DST].[ModifiedOn]
				)
				THEN 
					UPDATE  
					SET
						[DST].[SysCurrentFlag] = 0,  [DST].[SysEndDateTime] = GETDATE()   
			OUTPUT  [SRC].[CustomerCode], [SRC].[FirstName], [SRC].[Surname], [SRC].[CreatedOn], [SRC].[ModifiedOn] ,$Action AS MergeAction
			) AS MRG  
		WHERE MRG.MergeAction = 'UPDATE'
		AND MRG.[CustomerCode] IS NOT NULL ;

        SELECT @RowUpdate = @@RowCount;

        /*try to calculate the number of rows inserted and updated*/
        SELECT @TotalRows = COUNT(1)	FROM [ODS].[Source_Customer];
        SET @RowInsert = @TotalRows - @RowCountStart - @RowUpdate;

        EXECUTE [ADM].[usp_UpdateETLLOG] @LogID = @LogID, @DataCountInsert = @RowInsert, @DataCountUpdate = @RowUpdate, @DataCountDelete = @RowDelete, @DataCountTotalRows = @TotalRows,  @message = @ETLLOGUpdateMessage , @ErrorFlag = @ErrorFlag;

    END TRY  
    BEGIN CATCH       -- Execute error retrieval routine.  
        EXECUTE [ADM].[usp_RethrowError] @logID = @LogID ;
    END CATCH; 

END