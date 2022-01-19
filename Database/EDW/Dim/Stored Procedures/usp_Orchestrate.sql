CREATE PROCEDURE [Dim].[usp_Orchestrate]
 @ParentLogId BIGINT = NULL
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE @LogID INT;

		EXECUTE @LogID = [ADM].[usp_AddETLLOGProcedure]  @source_object_id = @@PROCID
            ,@TableName = '-'
            ,@ParentLogId = @ParentLogId

		BEGIN
			/* List of DIM ETL PROCS*/
			PRINT ''
		END

		EXECUTE [ADM].[usp_UpdateETLLog] @LogID = @LogID
	END TRY

	BEGIN CATCH -- Execute error retrieval routine.  
		EXECUTE [ADM].[usp_RethrowError] @logID = @LogID;
	END CATCH;
END;