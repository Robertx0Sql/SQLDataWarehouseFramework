

CREATE PROCEDURE [ADM].[usp_UpdateETLLOGSSISError] 
	@ExecutionId UNIQUEIDENTIFIER
	,@message NVARCHAR(2048)
AS
BEGIN

	SET NOCOUNT ON; 
	UPDATE [ADM].[ETLLOG]
	SET [message] = @message
	WHERE SSISExecutionGUId = @ExecutionId;

	IF @@ROWCOUNT = 0
	BEGIN
		EXECUTE [ADM].[usp_AddETLLOGSSIS] @PackageName = 'UNKNOWN'
			,@ExecutionId = @ExecutionId
			,@ProjectName = 'UNKNOWN';

		UPDATE [ADM].[ETLLOG]
		SET [message] = @message
		WHERE SSISExecutionGUId = @ExecutionId;
	END;

END;