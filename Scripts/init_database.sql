
USE master;
GO
-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK_IMMEDIATE;
DROP DATABASE  DataWarehouse;
END;
GO

-- Creating DataWarehouse Database
CREATE DATABASE DataWarehouse;

USE DataWarehouse;

-- Creating Schema
-- Bronze, Silver and Gold

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
