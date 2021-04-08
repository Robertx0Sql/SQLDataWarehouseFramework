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

