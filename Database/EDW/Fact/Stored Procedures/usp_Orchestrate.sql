CREATE   PROCEDURE Fact.[usp_Orchestrate]
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
			
			print ''

		END

		EXECUTE [ADM].[usp_UpdateETLLog] @LogID = @LogID
	END TRY

	BEGIN CATCH -- Execute error retrieval routine.  
		EXECUTE [ADM].[usp_RethrowError] @logID = @LogID;
	END CATCH;
END;



-- BUG FIX - Add @ParentLogId to [ADM].[usp_AddETLLOGSSIS] 