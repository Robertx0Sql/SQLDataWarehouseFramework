
CREATE PROCEDURE [ADM].[usp_UpdateETLLOGSSIS] 
	@ExecutionId UNIQUEIDENTIFIER
	,@RowCount int =NULL
AS
BEGIN 
SET NOCOUNT ON ;
	UPDATE [ADM].[ETLLOG]
	SET       
		[endtime]  =GETUTCDATE()
		,DataCountInsert=@RowCount
		, TotalRows= @RowCount 
	WHERE 
		[SSISExecutionGUId] = @ExecutionId;
END;