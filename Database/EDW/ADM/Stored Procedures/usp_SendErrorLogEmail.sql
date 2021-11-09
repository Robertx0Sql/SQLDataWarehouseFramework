CREATE PROCEDURE [ADM].[usp_SendErrorLogEmail]
@ReturnCode INT
AS
BEGIN
	/*
	Check for an unprocessed error in the ETL log for the proc just run
	*/

	DECLARE @xml VARCHAR(MAX);
	DECLARE @SubjectString VARCHAR(100);
	DECLARE @LogID INT; 
	DECLARE @RecipientEMails VARCHAR(50);
	--use a cursor to make sure any unprocessed logs are picked up (although there shouldn't be any of course)
	DECLARE C1 CURSOR FOR
	SELECT 'ETL ' + ErrorType + ' in ' + UserTableDescription, CAST(Error AS VARCHAR(MAX)) ,ETLLOGErrorID
	FROM [ADM].ETLLOGError ele
	WHERE ele.EmailSentDateTime IS NULL 
		AND ele.LOGID=@ReturnCode;

		declare @profile_name VARCHAR (100)='dba' ;

	/*
	--Get the failure email address from the SSIDB variables
	   SELECT @RecipientEMails=CAST(ev.value AS VARCHAR(50))
        FROM [$(SSISDB)].CATALOG.folders F
        INNER JOIN [$(SSISDB)].CATALOG.environments e
            ON e.folder_id = F.folder_id
        INNER JOIN [$(SSISDB)].CATALOG.environment_variables ev
            ON ev.environment_id = e.environment_id
        WHERE ev.name ='EmailFailureTo'
            AND f.name='Environments'
            AND e.name ='Generic';
	*/

	IF @ReturnCode<>0 --Only process if the return code <> 0, although the proc should only be called if the return code <> 0. Better safe than sorry
	BEGIN
		OPEN C1;
		FETCH NEXT FROM C1 INTO @SubjectString,@xml,@LogID;
		WHILE @@FETCH_STATUS=0
		BEGIN
			EXECUTE msdb.dbo.sp_send_dbmail
				@recipients=@recipientemails
				,@subject=@subjectstring
				,@body=@xml
				,@profile_name=@profile_name;	
			UPDATE [ADM].ETLLOGError 
			SET EmailSentDateTime=GETUTCDATE()
			WHERE ETLLOGErrorID=@LogID;

			FETCH NEXT FROM C1 INTO @SubjectString,@xml,@LogID;
		END;
		CLOSE C1;
		DEALLOCATE C1;
	END;

END;