CREATE VIEW [ADM].[vwETLLOG]
AS
SELECT DATEDIFF(SECOND, starttime, COALESCE(endtime, GETUTCDATE())) / 60. AS TimeDiffMin
	,[LOGID]
	,[source]
	,[starttime]
	,[endtime]
	,[message]
	,[DataCountInsert]
	,[DataCountUpdate]
	,[DataCountDelete]
	,[TotalRows]
	--,[SSISExecutionId]
	,[LOGID] AS Id
	--,CASE WHEN CHARINDEX( 'usp_update', [source] ) >0 THEN REPLACE([source],'usp_update','')  END AS DestinationTable
	
	,CASE WHEN SSISExecutionGUId IS NULL AND CHARINDEX( 'usp_update', [source] ) >0 AND TableName IS NULL THEN REPLACE([source],'usp_update','')  ELSE TableName END AS TableName
	,CASE WHEN SSISExecutionGUId IS NOT NULL AND CHARINDEX( '.', [source] ) > 0 THEN SUBSTRING([source] ,0,  CHARINDEX( '.', [source] )  )  END AS SSISProjectName 
	,CASE WHEN SSISExecutionGUId IS NOT NULL Then case  when CHARINDEX( '.', [source] ) > 0 THEN SUBSTRING([source] ,  CHARINDEX( '.', [source] ) +1 , LEN ( [source]  ) ) else [source]  END END AS SSISPackageName

FROM [ADM].ETLLOG;