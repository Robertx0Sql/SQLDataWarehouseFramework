CREATE PROCEDURE [ADM].[usp_AddETLLOGSSIS] 
	@PackageName VARCHAR(100) 
	,@ExecutionId UNIQUEIDENTIFIER
	,@ProjectName VARCHAR(100)=NULL 
	,@ParentLogId BIGINT = NULL
AS
BEGIN 
SET NOCOUNT ON ;

	DECLARE   @LOGID INT;
	
	DECLARE @Source VARCHAR(100)  
	SET @Source = COALESCE(@ProjectName + '.', '')  +  @PackageName

	INSERT INTO [ADM].[ETLLOG]
           ([source]
           ,[starttime]
           ,[SSISExecutionGUId]
		   ,ParentLogId )
     VALUES
           (@Source, GETUTCDATE() , @ExecutionId, @ParentLogId );
	SET @LOGID = SCOPE_IDENTITY();
	RETURN @LOGID;
END;