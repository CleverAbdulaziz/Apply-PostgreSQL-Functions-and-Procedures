-- =============================================
-- DIMENSION TABLES CREATION SCRIPT
-- Purpose: Create all dimension tables for the data warehouse
-- =============================================

-- Date Dimension Table
CREATE TABLE IF NOT EXISTS DimDate (
    DateID SERIAL PRIMARY KEY,
    Date DATE NOT NULL UNIQUE,
    Day INT NOT NULL CHECK (Day BETWEEN 1 AND 31),
    Month INT NOT NULL CHECK (Month BETWEEN 1 AND 12),
    Year INT NOT NULL CHECK (Year BETWEEN 1900 AND 2100),
    Quarter INT NOT NULL CHECK (Quarter BETWEEN 1 AND 4),
    WeekOfYear INT NOT NULL CHECK (WeekOfYear BETWEEN 1 AND 53),
    DayOfWeek INT NOT NULL CHECK (DayOfWeek BETWEEN 0 AND 6),
    DayName VARCHAR(9) NOT NULL,
    MonthName VARCHAR(9) NOT NULL,
    IsWeekend BOOLEAN NOT NULL,
    IsHoliday BOOLEAN DEFAULT FALSE
);

-- Supplier Dimension Table
CREATE TABLE IF NOT EXISTS DimSupplier (
    SupplierID INT PRIMARY KEY,
    CompanyName VARCHAR(40) NOT NULL,
    ContactName VARCHAR(30),
    ContactTitle VARCHAR(30),
    Address VARCHAR(60),
    City VARCHAR(15),
    Region VARCHAR(15),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    Phone VARCHAR(24),
    Fax VARCHAR(24),
    IsActive BOOLEAN DEFAULT TRUE,
    ValidFrom DATE NOT NULL DEFAULT CURRENT_DATE,
    ValidTo DATE DEFAULT '9999-12-31'
);

-- Category Dimension Table
CREATE TABLE IF NOT EXISTS DimCategory (
    CategoryID INT PRIMARY KEY,
    CategoryName VARCHAR(15) NOT NULL,
    Description TEXT,
    ValidFrom DATE NOT NULL DEFAULT CURRENT_DATE,
    ValidTo DATE DEFAULT '9999-12-31'
);

-- Product Dimension Table (Type 2 SCD for price changes)
CREATE TABLE IF NOT EXISTS DimProduct (
    ProductSK SERIAL PRIMARY KEY,
    ProductID INT NOT NULL,
    ProductName VARCHAR(40) NOT NULL,
    SupplierID INT,
    CategoryID INT,
    QuantityPerUnit VARCHAR(20),
    UnitPrice DECIMAL(10,2),
    UnitsInStock SMALLINT,
    UnitsOnOrder SMALLINT,
    ReorderLevel SMALLINT,
    Discontinued BOOLEAN DEFAULT FALSE,
    IsCurrent BOOLEAN DEFAULT TRUE,
    ValidFrom DATE NOT NULL DEFAULT CURRENT_DATE,
    ValidTo DATE DEFAULT '9999-12-31',
    FOREIGN KEY (SupplierID) REFERENCES DimSupplier(SupplierID),
    FOREIGN KEY (CategoryID) REFERENCES DimCategory(CategoryID)
);

-- Customer Dimension Table
CREATE TABLE IF NOT EXISTS DimCustomer (
    CustomerID VARCHAR(5) PRIMARY KEY,
    CompanyName VARCHAR(40) NOT NULL,
    ContactName VARCHAR(30),
    ContactTitle VARCHAR(30),
    Address VARCHAR(60),
    City VARCHAR(15),
    Region VARCHAR(15),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    Phone VARCHAR(24),
    Fax VARCHAR(24),
    CustomerSegment VARCHAR(20) DEFAULT 'Standard',
    IsActive BOOLEAN DEFAULT TRUE,
    ValidFrom DATE NOT NULL DEFAULT CURRENT_DATE,
    ValidTo DATE DEFAULT '9999-12-31'
);

-- Employee Dimension Table
CREATE TABLE IF NOT EXISTS DimEmployee (
    EmployeeID INT PRIMARY KEY,
    LastName VARCHAR(20) NOT NULL,
    FirstName VARCHAR(10) NOT NULL,
    FullName VARCHAR(50) GENERATED ALWAYS AS (FirstName || ' ' || LastName) STORED,
    Title VARCHAR(30),
    TitleOfCourtesy VARCHAR(25),
    BirthDate DATE,
    HireDate DATE,
    Address VARCHAR(60),
    City VARCHAR(15),
    Region VARCHAR(15),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    HomePhone VARCHAR(24),
    ReportsTo INT,
    IsActive BOOLEAN DEFAULT TRUE,
    ValidFrom DATE NOT NULL DEFAULT CURRENT_DATE,
    ValidTo DATE DEFAULT '9999-12-31'
);

-- Shipper Dimension Table
CREATE TABLE IF NOT EXISTS DimShipper (
    ShipperID INT PRIMARY KEY,
    CompanyName VARCHAR(40) NOT NULL,
    Phone VARCHAR(24),
    IsActive BOOLEAN DEFAULT TRUE,
    ValidFrom DATE NOT NULL DEFAULT CURRENT_DATE,
    ValidTo DATE DEFAULT '9999-12-31'
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_dimdate_date ON DimDate(Date);
CREATE INDEX IF NOT EXISTS idx_dimproduct_productid ON DimProduct(ProductID);
CREATE INDEX IF NOT EXISTS idx_dimproduct_current ON DimProduct(IsCurrent);
CREATE INDEX IF NOT EXISTS idx_dimsupplier_country ON DimSupplier(Country);
CREATE INDEX IF NOT EXISTS idx_dimcustomer_country ON DimCustomer(Country);
CREATE INDEX IF NOT EXISTS idx_dimcustomer_segment ON DimCustomer(CustomerSegment);

-- Comments for documentation
COMMENT ON TABLE DimDate IS 'Date dimension table with comprehensive date attributes for time-based analysis';
COMMENT ON TABLE DimSupplier IS 'Supplier dimension with SCD Type 2 support for historical tracking';
COMMENT ON TABLE DimProduct IS 'Product dimension with Type 2 SCD to track price and attribute changes over time';
COMMENT ON TABLE DimCategory IS 'Product category dimension for product classification';
COMMENT ON TABLE DimCustomer IS 'Customer dimension with segmentation and contact information';
COMMENT ON TABLE DimEmployee IS 'Employee dimension with hierarchical reporting structure';
COMMENT ON TABLE DimShipper IS 'Shipping company dimension for delivery analysis';