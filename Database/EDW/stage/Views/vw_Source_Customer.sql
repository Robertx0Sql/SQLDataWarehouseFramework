CREATE VIEW stage.[vw_Source_Customer] 
AS
SELECT
	CustomerCode
	,FirstName
	,Surname
	,CreatedOn
	,ModifiedOn
FROM ODS.[Source_Customer]