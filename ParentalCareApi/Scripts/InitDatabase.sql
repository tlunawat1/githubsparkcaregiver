-- ParentalCare Azure SQL Database Initialization Script
-- Run this script to create the initial database schema

-- Users table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
BEGIN
    CREATE TABLE Users (
        Id NVARCHAR(36) PRIMARY KEY,
        Name NVARCHAR(200) NOT NULL,
        Email NVARCHAR(255) NOT NULL,
        PasswordHash NVARCHAR(255) NOT NULL,
        Role NVARCHAR(20) NOT NULL,
        PhoneNumber NVARCHAR(20) NULL,
        UniqueCode NVARCHAR(9) NOT NULL,
        AvatarUrl NVARCHAR(500) NULL,
        EmailVerified BIT NOT NULL DEFAULT 0,
        VerificationCode NVARCHAR(6) NULL,
        VerificationCodeExpiry DATETIME2 NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        LastLoginAt DATETIME2 NULL,
        DeviceToken NVARCHAR(500) NULL,
        RefreshToken NVARCHAR(500) NULL,
        RefreshTokenExpiry DATETIME2 NULL,
        CONSTRAINT UQ_Users_Email UNIQUE (Email),
        CONSTRAINT UQ_Users_UniqueCode UNIQUE (UniqueCode),
        CONSTRAINT CK_Users_Role CHECK (Role IN ('caregiver', 'dependent'))
    );

    CREATE INDEX IX_Users_Email ON Users(Email);
    CREATE INDEX IX_Users_UniqueCode ON Users(UniqueCode);
    CREATE INDEX IX_Users_Role ON Users(Role);

    PRINT 'Created Users table';
END
GO

-- CareRelationships table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'CareRelationships')
BEGIN
    CREATE TABLE CareRelationships (
        Id NVARCHAR(36) PRIMARY KEY,
        CaregiverId NVARCHAR(36) NOT NULL,
        DependentId NVARCHAR(36) NOT NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'pending',
        LinkingCode NVARCHAR(5) NULL,
        CodeExpiresAt DATETIME2 NULL,
        VerificationAttempts INT NOT NULL DEFAULT 0,
        InitiatedBy NVARCHAR(20) NOT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        VerifiedAt DATETIME2 NULL,
        CONSTRAINT FK_CareRelationships_Caregiver FOREIGN KEY (CaregiverId) REFERENCES Users(Id),
        CONSTRAINT FK_CareRelationships_Dependent FOREIGN KEY (DependentId) REFERENCES Users(Id),
        CONSTRAINT CK_CareRelationships_Status CHECK (Status IN ('pending', 'active', 'removed')),
        CONSTRAINT CK_CareRelationships_InitiatedBy CHECK (InitiatedBy IN ('caregiver', 'dependent'))
    );

    CREATE INDEX IX_CareRelationships_CaregiverId ON CareRelationships(CaregiverId);
    CREATE INDEX IX_CareRelationships_DependentId ON CareRelationships(DependentId);
    CREATE INDEX IX_CareRelationships_Status ON CareRelationships(CaregiverId, DependentId, Status);

    PRINT 'Created CareRelationships table';
END
GO

-- Reminders table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Reminders')
BEGIN
    CREATE TABLE Reminders (
        Id NVARCHAR(36) PRIMARY KEY,
        CreatorId NVARCHAR(36) NOT NULL,
        DependentId NVARCHAR(36) NOT NULL,
        Title NVARCHAR(200) NOT NULL,
        Description NVARCHAR(MAX) NULL,
        VoiceNoteUrl NVARCHAR(500) NULL,
        RepeatPattern NVARCHAR(20) NOT NULL,
        RepeatDays NVARCHAR(100) NULL,
        Hour INT NOT NULL,
        Minute INT NOT NULL,
        Priority NVARCHAR(10) NOT NULL DEFAULT 'normal',
        IsActive BIT NOT NULL DEFAULT 1,
        StartDate DATETIME2 NOT NULL,
        EndDate DATETIME2 NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT FK_Reminders_Creator FOREIGN KEY (CreatorId) REFERENCES Users(Id),
        CONSTRAINT FK_Reminders_Dependent FOREIGN KEY (DependentId) REFERENCES Users(Id),
        CONSTRAINT CK_Reminders_RepeatPattern CHECK (RepeatPattern IN ('once', 'daily', 'weekly', 'specific_days')),
        CONSTRAINT CK_Reminders_Priority CHECK (Priority IN ('normal', 'high')),
        CONSTRAINT CK_Reminders_Hour CHECK (Hour >= 0 AND Hour <= 23),
        CONSTRAINT CK_Reminders_Minute CHECK (Minute >= 0 AND Minute <= 59)
    );

    CREATE INDEX IX_Reminders_CreatorId ON Reminders(CreatorId);
    CREATE INDEX IX_Reminders_DependentId ON Reminders(DependentId);
    CREATE INDEX IX_Reminders_IsActive ON Reminders(DependentId, IsActive);

    PRINT 'Created Reminders table';
END
GO

-- ReminderInstances table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ReminderInstances')
BEGIN
    CREATE TABLE ReminderInstances (
        Id NVARCHAR(36) PRIMARY KEY DEFAULT NEWID(),
        ReminderId NVARCHAR(36) NOT NULL,
        ScheduledTime DATETIME2 NOT NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'pending',
        CompletedAt DATETIME2 NULL,
        SnoozedUntil DATETIME2 NULL,
        EscalationLevel INT NOT NULL DEFAULT 0,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT FK_ReminderInstances_Reminder FOREIGN KEY (ReminderId) REFERENCES Reminders(Id) ON DELETE CASCADE,
        CONSTRAINT CK_ReminderInstances_Status CHECK (Status IN ('pending', 'completed', 'missed', 'snoozed'))
    );

    CREATE INDEX IX_ReminderInstances_ReminderId ON ReminderInstances(ReminderId);
    CREATE INDEX IX_ReminderInstances_ScheduledTime ON ReminderInstances(ScheduledTime);
    CREATE INDEX IX_ReminderInstances_Reminder_ScheduledTime ON ReminderInstances(ReminderId, ScheduledTime);

    PRINT 'Created ReminderInstances table';
END
GO

-- SosEvents table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SosEvents')
BEGIN
    CREATE TABLE SosEvents (
        Id NVARCHAR(36) PRIMARY KEY,
        DependentId NVARCHAR(36) NOT NULL,
        Status NVARCHAR(20) NOT NULL DEFAULT 'triggered',
        TriggeredAt DATETIME2 NOT NULL,
        ResolvedAt DATETIME2 NULL,
        ResolvedBy NVARCHAR(36) NULL,
        Notes NVARCHAR(MAX) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT FK_SosEvents_Dependent FOREIGN KEY (DependentId) REFERENCES Users(Id),
        CONSTRAINT FK_SosEvents_Resolver FOREIGN KEY (ResolvedBy) REFERENCES Users(Id),
        CONSTRAINT CK_SosEvents_Status CHECK (Status IN ('triggered', 'cancelled', 'resolved'))
    );

    CREATE INDEX IX_SosEvents_DependentId ON SosEvents(DependentId);
    CREATE INDEX IX_SosEvents_Status ON SosEvents(DependentId, Status);
    CREATE INDEX IX_SosEvents_TriggeredAt ON SosEvents(TriggeredAt DESC);

    PRINT 'Created SosEvents table';
END
GO

PRINT 'Database initialization complete!';
