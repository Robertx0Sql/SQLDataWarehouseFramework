CREATE TABLE [ADM].[ETLLOGError] (
    [ETLLOGErrorID]        INT            IDENTITY (1, 1) NOT NULL,
    [LOGID]                INT            NOT NULL,
    [Error]                NVARCHAR (MAX) NULL,
    [ErrorType]            VARCHAR (10)   NOT NULL,
    [UserTableDescription] VARCHAR (250)  NULL,
    [LogDateTime]          DATETIME2 (7)  CONSTRAINT [DF_ETLLOGError_LogDateTime] DEFAULT (getutcdate()) NOT NULL,
    [EmailSentDateTime]    DATETIME2 (7)  NULL,
    PRIMARY KEY CLUSTERED ([ETLLOGErrorID] ASC) WITH (FILLFACTOR = 80)
);




GO
CREATE UNIQUE NONCLUSTERED INDEX [UX_TOOLS_ETLLOGError_LogId_ErrorType]
    ON [ADM].[ETLLOGError]([LOGID] ASC, [ErrorType] ASC);

