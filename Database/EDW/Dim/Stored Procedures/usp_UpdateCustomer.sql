CREATE PROCEDURE [Dim].[usp_UpdateCustomer]
@ParentLogId BIGINT = NULL
AS  
    ---------------------------------------------------------------------------------------------------------------------------------------
    /*
    	Name:				[Dim].[usp_UpdateCustomer]
    	Author:				SATURN\Robert
    	Create date:		09 Apr 2021
    	Version:			1.01
    	Description:		Add Data to [Dim].[Customer]
    
    	Example:			exec [Dim].[usp_UpdateCustomer]
    
    	Version Updates:
    	Reference			Version			Date			Updated By				Description
    	---------			-------			----			----------				-----------
     */
     ---------------------------------------------------------------------------------------------------------------------------------------

    /* Created from :
    -- [ADM].[sp_CreateUpdateProc]  @DestinationTable='[Dim].[Customer]' , @JoinFieldList='CustomerCode' , @SourceTable='stage.[vw_Source_Customer] ' , @OutputType='ALL' , @IncludeNotMatched=0
    */
BEGIN 
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @LogID INT;
        EXEC  @LogID = [ADM].[usp_AddETLLOGProcedure]  @source_object_id = @@PROCID, @TableName = '[Dim].[Customer]',  @ParentLogId = @ParentLogId 

        DECLARE @RowInsert INT, @RowUpdate INT, @RowDelete INT , @TotalRows INT;

        DECLARE @ETLLOGUpdateMessage NVARCHAR(2048) = NULL, @ErrorFlag BIT = 0 ; 

        DECLARE @RowCountStart AS BIGINT;
        SELECT @RowCountStart = COUNT(1)	FROM [Dim].[Customer];

        IF NOT EXISTS (  SELECT *
            FROM [Dim].[Customer]
            WHERE [CustomerId] = -1)
        BEGIN 
            SET IDENTITY_INSERT [Dim].[Customer] ON;

            INSERT INTO [Dim].[Customer] ( [CustomerId]) 
            VALUES ( -1  );

            SET IDENTITY_INSERT [Dim].[Customer] OFF;
        END;

		BEGIN /*Duplicate Record Check */
			DECLARE @DuplicateRowXml XML;
			SET @DuplicateRowXml  =(
				SELECT   [SRC].[CustomerCode], [SRC].[FirstName], [SRC].[Surname], [SRC].[CreatedOn], [SRC].[ModifiedOn]
				FROM stage.[vw_Source_Customer]  src 
				INNER JOIN (
							SELECT [CustomerCode]
							FROM stage.[vw_Source_Customer] 
							GROUP BY [CustomerCode]
							HAVING COUNT(1) != 1 
						) DST 	
						ON [DST].[CustomerCode] = [SRC].[CustomerCode]
					FOR XML RAW('row') ,ROOT('stage_vw_Source_Customer') 
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

		INSERT INTO [Dim].[Customer]( [CustomerCode], [FirstName], [Surname], [CreatedOn], [ModifiedOn])
		SELECT  [CustomerCode], [FirstName], [Surname], [CreatedOn], [ModifiedOn]
		FROM ( 
			MERGE INTO [Dim].[Customer] AS DST 
			USING stage.[vw_Source_Customer]  AS SRC 
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
        SELECT @TotalRows = COUNT(1)	FROM [Dim].[Customer];
        SET @RowInsert = @TotalRows - @RowCountStart - @RowUpdate;

        EXECUTE [ADM].[usp_UpdateETLLOG] @LogID = @LogID, @DataCountInsert = @RowInsert, @DataCountUpdate = @RowUpdate, @DataCountDelete = @RowDelete, @DataCountTotalRows = @TotalRows,  @message = @ETLLOGUpdateMessage , @ErrorFlag = @ErrorFlag;

    END TRY  
    BEGIN CATCH       -- Execute error retrieval routine.  
        EXECUTE [ADM].[usp_RethrowError] @logID = @LogID ;
    END CATCH; 

END