CREATE TABLE [Dim].[Customer] (
    [CustomerId]       BIGINT        IDENTITY (1, 1) NOT NULL,
    [CustomerCode]     VARCHAR (10)  NULL,
    [FirstName]        VARCHAR (100) NULL,
    [Surname]          VARCHAR (100) NULL,
    [CreatedOn]        DATETIME      NULL,
    [ModifiedOn]       DATETIME      NULL,
    [SysStartDateTime] DATETIME2 (7) CONSTRAINT [DF_DimCustomer_SysStartDateTime] DEFAULT (getutcdate()) NOT NULL,
    [SysEndDateTime]   DATETIME2 (7) NULL,
    [SysCurrentFlag]   TINYINT       CONSTRAINT [DF_DimCustomer_SysCurrentFlag] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_DimCustomer] PRIMARY KEY CLUSTERED ([CustomerId] ASC)
);

