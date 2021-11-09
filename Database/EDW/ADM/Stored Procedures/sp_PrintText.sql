CREATE PROCEDURE [ADM].[sp_PrintText] (@Text NVARCHAR(MAX))
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Split_position_last INT = 0;
	DECLARE @maxtextlen INT = 4000;
	DECLARE @delimter_pos INT = @maxtextlen;
	DECLARE @delimiter VARCHAR(10) = CHAR(10);
	DECLARE @loopoffset INT = 0;
	DECLARE @printstring NVARCHAR(MAX);

	declare @Counter int =0 

	--print len(@Text)
	WHILE @Split_position_last + @maxtextlen < LEN(@Text)
	BEGIN
		set @Counter =@Counter + 1
		SET @loopoffset = 0;
		SET @delimter_pos = @maxtextlen + @Split_position_last;

		WHILE @delimter_pos - @Split_position_last >= @maxtextlen --or @loopoffset <100
		BEGIN
			SET @delimter_pos = CHARINDEX(@delimiter, @Text, @maxtextlen + @Split_position_last - @loopoffset);
			--PRINT @delimter_pos; 
			SET @loopoffset = @loopoffset + 10;
		END;

		SET @printstring = SUBSTRING(@Text, @Split_position_last, @delimter_pos - @Split_position_last - 1);

		PRINT @printstring;

		SET @Split_position_last = @delimter_pos + 1;
	END;

	IF @Split_position_last < LEN(@Text)
	BEGIN
		--print 'hello'
		SET @printstring = SUBSTRING(@Text, @Split_position_last, LEN(@Text) - @Split_position_last + 10);

		PRINT @printstring;
			--print len(@printstring )
	END;

	--print @Counter  
	--print LEN(@Text)
END;