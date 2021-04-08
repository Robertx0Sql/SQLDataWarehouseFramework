CREATE PROCEDURE [ADM].[usp_AddETLLOGError] 
	@LOGID INT
	,@ErrorXML XML
	,@UserTableDescription VARCHAR(250)
	,@ErrorType VARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO [ADM].[ETLLOGError] (
		[LOGID]
		,[ErrorXML]
		,UserTableDescription
		,[ErrorType]
		)
	SELECT @LOGID
		,@ErrorXML
		,@UserTableDescription
		,@ErrorType;

	RETURN SCOPE_IDENTITY();
END