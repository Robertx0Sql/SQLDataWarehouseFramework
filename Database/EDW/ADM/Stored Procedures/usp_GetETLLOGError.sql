CREATE PROCEDURE [ADM].[usp_GetETLLOGError] 
    @LOGID int,
    @ErrorType varchar(10)='Duplicate'
AS
BEGIN 
	SET NOCOUNT ON 

	SELECT TOP 1 
		[Error] 
		,[ErrorType]
	FROM [ADM].[ETLLOGError]
	WHERE [LOGID] = @LOGID
			AND ([ErrorType]=@ErrorType OR ([ErrorType] IS NULL and @ErrorType IS NULL) )
END