CREATE TABLE [Dim].[Date] (
    [DateID]                INT            NOT NULL,
    [FullDate]              DATE           NOT NULL,
    [DayNumberOfWeek]       TINYINT        NOT NULL,
    [EnglishDayNameOfWeek]  NVARCHAR (10)  NOT NULL,
    [DayNumberOfMonth]      TINYINT        NOT NULL,
    [DayNumberOfYear]       SMALLINT       NOT NULL,
    [WeekNumberOfYear]      TINYINT        NOT NULL,
    [EnglishMonthName]      NVARCHAR (10)  NOT NULL,
    [MonthNumberOfYear]     TINYINT        NOT NULL,
    [CalendarQuarter]       TINYINT        NOT NULL,
    [CalendarYear]          SMALLINT       NOT NULL,
    [CalendarSemester]      TINYINT        NOT NULL,
    [FiscalYear]            SMALLINT       NOT NULL,
    [FiscalPeriod]          TINYINT        NOT NULL,
    [FiscalWeekYear]        SMALLINT       NULL,
    [FiscalWeekPeriod]      TINYINT        NULL,
    [FiscalWeek]            TINYINT        NULL,
    [FiscalDayofWeek]       TINYINT        NULL,
    [UKHolidayEnglandFlag]  BIT            CONSTRAINT [DF_dimDate_UKHolidayEnglandFlag] DEFAULT ((0)) NOT NULL,
    [UKHolidayName]         VARCHAR (50)   NULL,
    [FiscalPriorYearDateID] INT            NULL,
    [WorkingDay]            DECIMAL (9, 2) NULL,
    [LastUpdatedDateTime]   DATETIME       NULL,
    CONSTRAINT [PK_DimDate] PRIMARY KEY CLUSTERED ([DateID] ASC)
);







