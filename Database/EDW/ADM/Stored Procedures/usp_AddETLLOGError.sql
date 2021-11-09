CREATE PROCEDURE [ADM].[usp_AddETLLOGError] 
	@LOGID INT
	,@Error NVARCHAR(MAX) 
	,@UserTableDescription VARCHAR(250)
	,@ErrorType VARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO [ADM].[ETLLOGError] (
		[LOGID]
		,[Error]
		,UserTableDescription
		,[ErrorType]
		)
	SELECT @LOGID
		,@Error
		,@UserTableDescription
		,@ErrorType;

	RETURN SCOPE_IDENTITY();
END