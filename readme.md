##Data Warehouse Db Framework
Examples 

for existing table [dim].[Policy] create a proc for Type2  .

EXEC ADM.[sp_CreateUpdateProc] @DestinationTable = '[dim].[Policy]'
    ,@SourceTable = '[stage].[vw_Policy]'
    ,@JoinFieldList = 'BusinessKey'
	,@MergeSyntax=1
	,@DuplicateRecordCheck=1

--create proc with std Update /Insert (@MergeSyntax=0)
EXEC ADM.[sp_CreateUpdateProc] @DestinationTable = '[dim].[Policy]'
    ,@SourceTable = '[stage].[vw_Policy]'
    ,@JoinFieldList = 'BusinessKey'
	,@MergeSyntax=0
	,@DuplicateRecordCheck=1


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

