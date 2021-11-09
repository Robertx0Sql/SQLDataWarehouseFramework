CREATE PROCEDURE [ADM].[sp_CreateProcComment]
(
	@DestinationTable VARCHAR (250) 
	,@output NVARCHAR(MAX) = NULL OUTPUT -- Use this output parameter to return the generated T-SQL batches to the caller (Hint: specify @batch_separator=NULL to output all statements within a single batch)
)
AS

		DECLARE @lf AS VARCHAR(5) = CHAR(10); 
		DECLARE @tab VARCHAR(10) = REPLICATE(' ', 4); 

		DECLARE @objectid INT = OBJECT_ID(@DestinationTable);

		DECLARE @SQLDestinationTableName VARCHAR(250) = QUOTENAME(object_SCHEMA_NAME(@objectid)) + '.' + QUOTENAME(OBJECT_NAME(@objectid));


SET @output  = 
			 @lf + @tab  + '---------------------------------------------------------------------------------------------------------------------------------------'
			+ @lf + @tab  + '/*'
			+ @lf + @tab  + '	Author:				'+ SYSTEM_USER 
			+ @lf + @tab  + '	Create date:		' + CONVERT(VARCHAR(20) , GETDATE(), 106)
			+ @lf + @tab  + '	Version:			1.01'
			+ @lf + @tab  + '	Description:		Add Data to ' + @SQLDestinationTableName
			+ @lf + @tab  + ''
			+ @lf + @tab  + '	Example:			'
			+ @lf + @tab  + ''
			+ @lf + @tab  + '	Version Updates:'
			+ @lf + @tab  + '	Reference			Version			Date			Updated By				Description'
			+ @lf + @tab  + '	---------			-------			----			----------				-----------'
			+ @lf + @tab  + ' */'
			+ @lf + @tab  + ' ---------------------------------------------------------------------------------------------------------------------------------------'
			+ @lf;