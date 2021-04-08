CREATE PROCEDURE [Dim].[usp_UpdateDate]
AS  
    /* Created from :
    -- [TOOLS].[usp_CreateUpdateProc]  @DestinationTable='[Dim].[Date]' , @JoinFieldList='DateId' , @SourceTable='CTE_Data' , @OutputType='ALL' , @MergeType='Update' , @IncludeNotMatched=0
    */
BEGIN 
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @LogID INT; 
        EXECUTE  @LogID = [ADM].[usp_AddETLLOGProcedure]  @@PROCID;

        DECLARE @RowCountStart AS BIGINT, @TotalRows BIGINT;
        DECLARE @MergeRowInsert INT, @MergeRowUpdate INT, @MergeRowDelete INT;

        SELECT @RowCountStart = COUNT(*)	FROM [Dim].[Date];

		DECLARE @WeekStartDay INT =5 ;--Friday

		WITH CTE_DATA --DUMMY 
		AS (
			SELECT  SRC.[DateID], SRC.[FullDate], SRC.[DayNumberOfWeek], SRC.[EnglishDayNameOfWeek], SRC.[DayNumberOfMonth], SRC.[DayNumberOfYear], SRC.[WeekNumberOfYear], SRC.[EnglishMonthName], SRC.[MonthNumberOfYear], SRC.[CalendarQuarter], SRC.[CalendarYear], SRC.[CalendarSemester], SRC.[FiscalYear], SRC.[FiscalPeriod], SRC.[FiscalWeekYear], SRC.[FiscalWeekPeriod], SRC.[FiscalWeek], SRC.[FiscalDayofWeek], SRC.[UKHolidayEnglandFlag], SRC.[UKHolidayName], SRC.[FiscalPriorYearDateID], SRC.[WorkingDay]
				,LastUpdatedDateTime = GETDATE()
			FROM [Dim].[Date]  SRC 
			where 1=0
			)
			

             MERGE INTO [Dim].[Date] AS DST 
             USING CTE_Data AS SRC 
             ON (
                DST.[DateID] = SRC.[DateID] 
                )
		  WHEN NOT MATCHED BY TARGET 
                 THEN 
                     INSERT ( [DateID], [FullDate], [DayNumberOfWeek], [EnglishDayNameOfWeek], [DayNumberOfMonth], [DayNumberOfYear], [WeekNumberOfYear], [EnglishMonthName], [MonthNumberOfYear], [CalendarQuarter], [CalendarYear], [CalendarSemester], [FiscalYear], [FiscalPeriod], [FiscalWeekYear], [FiscalWeekPeriod], [FiscalWeek], [FiscalDayofWeek], [UKHolidayEnglandFlag], [UKHolidayName], [FiscalPriorYearDateID], [WorkingDay]) 
                    VALUES ( SRC.[DateID], SRC.[FullDate], SRC.[DayNumberOfWeek], SRC.[EnglishDayNameOfWeek], SRC.[DayNumberOfMonth], SRC.[DayNumberOfYear], SRC.[WeekNumberOfYear], SRC.[EnglishMonthName], SRC.[MonthNumberOfYear], SRC.[CalendarQuarter], SRC.[CalendarYear], SRC.[CalendarSemester], SRC.[FiscalYear], SRC.[FiscalPeriod], SRC.[FiscalWeekYear], SRC.[FiscalWeekPeriod], SRC.[FiscalWeek], SRC.[FiscalDayofWeek], SRC.[UKHolidayEnglandFlag], SRC.[UKHolidayName], SRC.[FiscalPriorYearDateID], SRC.[WorkingDay]) 
    
             WHEN MATCHED 
                 AND  EXISTS (
						SELECT DST.[FiscalYear] ,DST.[FiscalPeriod] ,DST.[FiscalWeekYear] ,DST.[FiscalWeekPeriod] ,DST.[FiscalWeek] ,DST.[FiscalPriorYearDateID] ,DST.WorkingDay
						EXCEPT 
						SELECT SRC.[FiscalYear] ,SRC.[FiscalPeriod] ,SRC.[FiscalWeekYear] ,SRC.[FiscalWeekPeriod] ,SRC.[FiscalWeek] ,SRC.[FiscalPriorYearDateID] ,SRC.WorkingDay
							)
                THEN 
                    UPDATE  
                    SET
                        DST.[FiscalYear] = SRC.[FiscalYear]
                        ,DST.[FiscalPeriod] = SRC.[FiscalPeriod]
                        ,DST.[FiscalWeekYear] = SRC.[FiscalWeekYear]
                        ,DST.[FiscalWeekPeriod] = SRC.[FiscalWeekPeriod]
                        ,DST.[FiscalWeek] = SRC.[FiscalWeek]
                        ,DST.[FiscalPriorYearDateID] = SRC.[FiscalPriorYearDateID]
						,DST.WorkingDay = SRC.WorkingDay
						,DST.LastUpdatedDateTime = SRC.LastUpdatedDateTime;

        SELECT @MergeRowUpdate = @@RowCount;

        SELECT @TotalRows = COUNT(1)	FROM [Dim].[Date];

        SELECT @MergeRowInsert = ABS(@TotalRows - @RowCountStart ), @MergeRowUpdate = @MergeRowUpdate -  ABS(@TotalRows - @RowCountStart ) ;

        EXECUTE [ADM].[usp_UpdateETLLog] @LogID = @LogID, @DataCountInsert = @MergeRowInsert, @DataCountUpdate = @MergeRowUpdate, @DataCountDelete = @MergeRowDelete, @DataCountTotalRows = @TotalRows;

    END TRY  
    BEGIN CATCH       -- Execute error retrieval routine.  
        EXECUTE [ADM].[usp_RethrowError] @logID = @LogID ;
    END CATCH; 

END;