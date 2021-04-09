CREATE TABLE [ODS].[Source_Customer] (
    [ODSCustomerId]    BIGINT        IDENTITY (1, 1) NOT NULL,
    [CustomerCode]     VARCHAR (10)  NULL,
    [FirstName]        VARCHAR (100) NULL,
    [Surname]          VARCHAR (100) NULL,
    [CreatedOn]        DATETIME      NULL,
    [ModifiedOn]       DATETIME      NULL,
    [SysStartDateTime] DATETIME2 (7) CONSTRAINT [DF_ODSCustomer_SysStartDateTime] DEFAULT (getutcdate()) NOT NULL,
    [SysEndDateTime]   DATETIME2 (7) NULL,
    [SysCurrentFlag]   TINYINT       CONSTRAINT [DF_ODSCustomer_SysCurrentFlag] DEFAULT ((1)) NOT NULL,
    CONSTRAINT [PK_ODSCustomer] PRIMARY KEY CLUSTERED ([ODSCustomerId] ASC)
);

