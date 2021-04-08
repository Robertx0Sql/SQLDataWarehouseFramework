
CREATE PROCEDURE [ADM].[usp_UpdateETLLog] 
	 @LOGID INT
	,@DataCountInsert INT = NULL
	,@DataCountUpdate INT = NULL
	,@DataCountDelete INT = NULL
	,@DataCountTotalRows BIGINT = NULL
	,@endtime DATETIME = NULL
	,@message NVARCHAR(2048) = NULL
	,@ErrorFlag BIT = 0 

AS 
BEGIN 
	SET NOCOUNT ON; 
	SET XACT_ABORT ON;  

	if @endtime is null set @endtime=GETUTCDATE();
	
	DECLARE @source NVARCHAR(1024);
	
	select @source = source from [ADM].[ETLLOG]
	where [LOGID] = @LOGID;

	DECLARE @printmessage VARCHAR(100), @printtime varchar(25) 
	SET @printmessage = 'COMPLETED EXEC ' + @source;
	RAISERROR ('%s', 0, 1, @printmessage ) WITH NOWAIT

    UPDATE [ADM].[ETLLOG]
    SET [endtime] = @endtime
	    ,[message] = @message
	    ,[DataCountInsert] = @DataCountInsert
	    ,[DataCountUpdate] = @DataCountUpdate
	    ,[DataCountDelete] = @DataCountDelete
	    ,[TotalRows] = @DataCountTotalRows
		,ErrorFlag = @ErrorFlag
    WHERE [LOGID] = @LOGID;
END