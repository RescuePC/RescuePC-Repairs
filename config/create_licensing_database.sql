-- RescuePC Licensing Database Schema
-- Run this script to create the licensing database and tables

USE master;
GO

-- Create the database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'RescuePC_Licensing')
BEGIN
    CREATE DATABASE [RescuePC_Licensing];
    PRINT 'Database RescuePC_Licensing created successfully.';
END
ELSE
BEGIN
    PRINT 'Database RescuePC_Licensing already exists.';
END
GO

USE [RescuePC_Licensing];
GO

-- Create Customers table
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Customers' AND xtype='U')
BEGIN
    CREATE TABLE [dbo].[Customers](
        [CustomerID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [CustomerName] [nvarchar](255) NOT NULL,
        [Email] [nvarchar](255) NOT NULL UNIQUE,
        [Company] [nvarchar](255) NULL,
        [Phone] [nvarchar](50) NULL,
        [Address] [nvarchar](500) NULL,
        [CreatedDate] [datetime2] NOT NULL DEFAULT GETDATE(),
        [LastLoginDate] [datetime2] NULL,
        [IsActive] [bit] NOT NULL DEFAULT 1
    );
    PRINT 'Customers table created successfully.';
END
ELSE
BEGIN
    PRINT 'Customers table already exists.';
END
GO

-- Create Packages table
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Packages' AND xtype='U')
BEGIN
    CREATE TABLE [dbo].[Packages](
        [PackageType] [nvarchar](50) NOT NULL PRIMARY KEY,
        [PackageName] [nvarchar](255) NOT NULL,
        [Description] [nvarchar](1000) NULL,
        [MaxDevices] [int] NOT NULL DEFAULT 1,
        [MonthlyPrice] [decimal](10,2) NULL,
        [Features] [nvarchar](max) NULL,
        [IsActive] [bit] NOT NULL DEFAULT 1
    );
    PRINT 'Packages table created successfully.';
END
ELSE
BEGIN
    PRINT 'Packages table already exists.';
END
GO

-- Create Licenses table
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Licenses' AND xtype='U')
BEGIN
    CREATE TABLE [dbo].[Licenses](
        [LicenseID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [CustomerID] [int] NOT NULL,
        [LicenseKey] [nvarchar](255) NOT NULL UNIQUE,
        [PackageType] [nvarchar](50) NOT NULL,
        [IsActive] [bit] NOT NULL DEFAULT 1,
        [ExpirationDate] [datetime2] NOT NULL,
        [CreatedDate] [datetime2] NOT NULL DEFAULT GETDATE(),
        [LastUsedDate] [datetime2] NULL,
        [ActivatedDate] [datetime2] NULL,
        [MaxDevices] [int] NOT NULL DEFAULT 1,
        [DevicesUsed] [int] NOT NULL DEFAULT 0,
        CONSTRAINT [FK_Licenses_Customers] FOREIGN KEY([CustomerID]) REFERENCES [dbo].[Customers] ([CustomerID]),
        CONSTRAINT [FK_Licenses_Packages] FOREIGN KEY([PackageType]) REFERENCES [dbo].[Packages] ([PackageType])
    );
    PRINT 'Licenses table created successfully.';
END
ELSE
BEGIN
    PRINT 'Licenses table already exists.';
END
GO

-- Insert sample package data
IF NOT EXISTS (SELECT * FROM Packages WHERE PackageType = 'BASIC')
BEGIN
    INSERT INTO Packages (PackageType, PackageName, Description, MaxDevices, MonthlyPrice, Features, IsActive)
    VALUES ('BASIC', 'Basic Repair Package', 'Essential Windows repair tools for basic system maintenance', 1, 9.99,
            'System Health Check, Basic Cleaning, Network Repair, Audio Repair, Service Repair', 1);
    PRINT 'Basic package inserted.';
END

IF NOT EXISTS (SELECT * FROM Packages WHERE PackageType = 'PROFESSIONAL')
BEGIN
    INSERT INTO Packages (PackageType, PackageName, Description, MaxDevices, MonthlyPrice, Features, IsActive)
    VALUES ('PROFESSIONAL', 'Professional Repair Package', 'Advanced repair tools for comprehensive system optimization', 3, 19.99,
            'All Basic features plus Performance Boost, Driver Management, Malware Scan, Advanced Repairs, Backup Tools', 1);
    PRINT 'Professional package inserted.';
END

IF NOT EXISTS (SELECT * FROM Packages WHERE PackageType = 'ENTERPRISE')
BEGIN
    INSERT INTO Packages (PackageType, PackageName, Description, MaxDevices, MonthlyPrice, Features, IsActive)
    VALUES ('ENTERPRISE', 'Enterprise Repair Package', 'Complete repair suite with unlimited device support', 999, 49.99,
            'All Professional features plus Custom Scripting, Enterprise Support, Priority Updates', 1);
    PRINT 'Enterprise package inserted.';
END

-- Insert sample customer data
IF NOT EXISTS (SELECT * FROM Customers WHERE Email = 'demo@rescuepc.com')
BEGIN
    INSERT INTO Customers (CustomerName, Email, Company, Phone, Address, IsActive)
    VALUES ('Demo Customer', 'demo@rescuepc.com', 'Demo Company', '555-0123', '123 Demo Street', 1);
    PRINT 'Demo customer inserted.';
END

-- Insert sample license data (valid for testing)
DECLARE @DemoCustomerID INT = (SELECT CustomerID FROM Customers WHERE Email = 'demo@rescuepc.com');

IF NOT EXISTS (SELECT * FROM Licenses WHERE LicenseKey = 'DEMO-2025-RESCUE-PC-TEST-001')
BEGIN
    INSERT INTO Licenses (CustomerID, LicenseKey, PackageType, IsActive, ExpirationDate, CreatedDate, MaxDevices)
    VALUES (@DemoCustomerID, 'DEMO-2025-RESCUE-PC-TEST-001', 'PROFESSIONAL', 1, DATEADD(YEAR, 1, GETDATE()), GETDATE(), 3);
    PRINT 'Demo license inserted.';
END

IF NOT EXISTS (SELECT * FROM Licenses WHERE LicenseKey = 'ENTERPRISE-2025-RESCUE-PC-DEMO-001')
BEGIN
    INSERT INTO Licenses (CustomerID, LicenseKey, PackageType, IsActive, ExpirationDate, CreatedDate, MaxDevices)
    VALUES (@DemoCustomerID, 'ENTERPRISE-2025-RESCUE-PC-DEMO-001', 'ENTERPRISE', 1, DATEADD(YEAR, 1, GETDATE()), GETDATE(), 999);
    PRINT 'Enterprise demo license inserted.';
END

PRINT 'Database setup completed successfully!';
PRINT '';
PRINT 'Sample licenses for testing:';
PRINT 'PROFESSIONAL: DEMO-2025-RESCUE-PC-TEST-001';
PRINT 'ENTERPRISE: ENTERPRISE-2025-RESCUE-PC-DEMO-001';
GO
