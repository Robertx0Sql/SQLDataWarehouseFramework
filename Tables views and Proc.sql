--[DDS].[usp_DimOrchestrate] @ParentLogId = ?
CREATE SCHEMA [Source]
GO

CREATE SCHEMA STG
GO
CREATE SCHEMA LND
GO
CREATE SCHEMA ODS
GO
CREATE TABLE [Source].[Customer] (
    CustomerCode VARCHAR(10)
    ,FirstName VARCHAR(100)
    ,Surname VARCHAR(100)
    ,[CreatedOn] DATETIME
    ,[ModifiedOn] DATETIME
    )
GO

CREATE TABLE LND.[Source_Customer] (
    CustomerCode VARCHAR(10)
    ,FirstName VARCHAR(100)
    ,Surname VARCHAR(100)
    ,[CreatedOn] DATETIME
    ,[ModifiedOn] DATETIME
    )
GO




CREATE TABLE ODS.[Source_Customer] (
	ODSCustomerId [bigint] IDENTITY(1, 1) NOT NULL
    ,CustomerCode VARCHAR(10)
    ,FirstName VARCHAR(100)
    ,Surname VARCHAR(100)
    ,[CreatedOn] DATETIME
    ,[ModifiedOn] DATETIME
    ,[SysStartDateTime] [datetime2](7) NOT NULL
    ,[SysEndDateTime] [datetime2](7) NULL
    ,[SysCurrentFlag] [tinyint] NOT NULL
    ,CONSTRAINT [PK_ODSCustomer] PRIMARY KEY CLUSTERED (ODSCustomerId ASC) ON [PRIMARY]
	)
GO
ALTER TABLE   ODS.[Source_Customer] ADD CONSTRAINT [DF_ODSCustomer_SysStartDateTime] DEFAULT(getutcdate())
FOR [SysStartDateTime]
GO

ALTER TABLE   ODS.[Source_Customer] ADD CONSTRAINT [DF_ODSCustomer_SysCurrentFlag] DEFAULT((1))
FOR [SysCurrentFlag]
GO


CREATE TABLE [DDS].[DIM_Customer] (
    CustomerId [bigint] IDENTITY(1, 1) NOT NULL
    ,CustomerCode VARCHAR(10)
    ,FirstName VARCHAR(100)
    ,Surname VARCHAR(100)
    ,[CreatedOn] DATETIME
    ,[ModifiedOn] DATETIME
    ,[SysStartDateTime] [datetime2](7) NOT NULL
    ,[SysEndDateTime] [datetime2](7) NULL
    ,[SysCurrentFlag] [tinyint] NOT NULL
    ,CONSTRAINT [PK_DimCustomer] PRIMARY KEY CLUSTERED ([CustomerID] ASC) ON [PRIMARY]
    ) ON [PRIMARY]
GO

ALTER TABLE  [DDS].[DIM_Customer] ADD CONSTRAINT [DF_DimCustomer_SysStartDateTime] DEFAULT(getutcdate())
FOR [SysStartDateTime]
GO

ALTER TABLE  [DDS].[DIM_Customer] ADD CONSTRAINT [DF_DimCustomer_SysCurrentFlag] DEFAULT((1))
FOR [SysCurrentFlag]
GO

GO
CREATE VIEW STG.[vw_Source_Customer] 
AS
SELECT
	CustomerCode
	,FirstName
	,Surname
	,CreatedOn
	,ModifiedOn
FROM ODS.[Source_Customer]
GO

-- CREATE PROCS 
--LND.[Source_Customer] => ODS.[Source_Customer]
EXEC ADM.[sp_CreateUpdateProc] 
	@DestinationTable = 'ODS.[Source_Customer]'
    ,@SourceTable = 'LND.[Source_Customer]'
    ,@JoinFieldList = 'CustomerCode'
	,@MergeSyntax=1
	,@DuplicateRecordCheck=1

--STG.[vw_Source_Customer] => [DDS].[DIM_Customer]
EXEC ADM.[sp_CreateUpdateProc] 
	@DestinationTable = '[DDS].[DIM_Customer]'
    ,@SourceTable = 'STG.[vw_Source_Customer] '
    ,@JoinFieldList = 'CustomerCode'
	,@MergeSyntax=1
	,@DuplicateRecordCheck=1


GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER  PROCEDURE [DDS].[usp_DimOrchestrate]
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
			
			EXEC [DDS].[usp_UpdateDIM_Customer] @ParentLogId = @ParentLogId

		END

		EXECUTE [ADM].[usp_UpdateETLLog] @LogID = @LogID
	END TRY

	BEGIN CATCH -- Execute error retrieval routine.  
		EXECUTE [ADM].[usp_RethrowError] @logID = @LogID;
	END CATCH;
END;	
GO
CREATE OR ALTER PROCEDURE DDS.[usp_FactOrchestrate]
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
GO
ALTER PROCEDURE [ADM].[usp_AddETLLOGSSIS] 
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
 
