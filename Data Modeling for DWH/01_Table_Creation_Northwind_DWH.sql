-- =====================================================
-- Northwind Data Warehouse - Table Creation Script
-- Author: [Your Name]
-- Date: [Current Date]
-- Description: Creates staging tables, dimension tables, 
--              and fact table for Northwind star schema
-- =====================================================

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS FactSales CASCADE;
DROP TABLE IF EXISTS DimDate CASCADE;
DROP TABLE IF EXISTS DimCustomer CASCADE;
DROP TABLE IF EXISTS DimProduct CASCADE;
DROP TABLE IF EXISTS DimEmployee CASCADE;
DROP TABLE IF EXISTS DimCategory CASCADE;
DROP TABLE IF EXISTS DimShipper CASCADE;
DROP TABLE IF EXISTS DimSupplier CASCADE;

DROP TABLE IF EXISTS staging_orders CASCADE;
DROP TABLE IF EXISTS staging_order_details CASCADE;
DROP TABLE IF EXISTS staging_products CASCADE;
DROP TABLE IF EXISTS staging_customers CASCADE;
DROP TABLE IF EXISTS staging_employees CASCADE;
DROP TABLE IF EXISTS staging_categories CASCADE;
DROP TABLE IF EXISTS staging_shippers CASCADE;
DROP TABLE IF EXISTS staging_suppliers CASCADE;

-- =====================================================
-- STAGING TABLES CREATION
-- Purpose: Temporary tables to hold raw data from source
-- =====================================================

-- Staging table for customers data
CREATE TABLE staging_customers (
    CustomerID VARCHAR(5) NOT NULL PRIMARY KEY,
    CompanyName VARCHAR(40) NOT NULL,
    ContactName VARCHAR(30),
    ContactTitle VARCHAR(30),
    Address VARCHAR(60),
    City VARCHAR(15),
    Region VARCHAR(15),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    Phone VARCHAR(24),
    Fax VARCHAR(24)
);

-- Staging table for employees data
CREATE TABLE staging_employees (
    EmployeeID SERIAL PRIMARY KEY,
    LastName VARCHAR(20) NOT NULL,
    FirstName VARCHAR(10) NOT NULL,
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
    Extension VARCHAR(4),
    Notes TEXT,
    ReportsTo INTEGER,
    PhotoPath VARCHAR(255)
);

-- Staging table for categories data
CREATE TABLE staging_categories (
    CategoryID SERIAL PRIMARY KEY,
    CategoryName VARCHAR(15) NOT NULL,
    Description TEXT,
    Picture BYTEA
);

-- Staging table for suppliers data
CREATE TABLE staging_suppliers (
    SupplierID SERIAL PRIMARY KEY,
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
    HomePage TEXT
);

-- Staging table for shippers data
CREATE TABLE staging_shippers (
    ShipperID SERIAL PRIMARY KEY,
    CompanyName VARCHAR(40) NOT NULL,
    Phone VARCHAR(24)
);

-- Staging table for products data
CREATE TABLE staging_products (
    ProductID SERIAL PRIMARY KEY,
    ProductName VARCHAR(40) NOT NULL,
    SupplierID INTEGER,
    CategoryID INTEGER,
    QuantityPerUnit VARCHAR(20),
    UnitPrice DECIMAL(10,2),
    UnitsInStock SMALLINT,
    UnitsOnOrder SMALLINT,
    ReorderLevel SMALLINT,
    Discontinued BOOLEAN NOT NULL
);

-- Staging table for orders data
CREATE TABLE staging_orders (
    OrderID SERIAL PRIMARY KEY,
    CustomerID VARCHAR(5),
    EmployeeID INTEGER,
    OrderDate DATE,
    RequiredDate DATE,
    ShippedDate DATE,
    ShipVia INTEGER,
    Freight DECIMAL(10,2),
    ShipName VARCHAR(40),
    ShipAddress VARCHAR(60),
    ShipCity VARCHAR(15),
    ShipRegion VARCHAR(15),
    ShipPostalCode VARCHAR(10),
    ShipCountry VARCHAR(15)
);

-- Staging table for order details data
CREATE TABLE staging_order_details (
    OrderID INTEGER NOT NULL,
    ProductID INTEGER NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    Quantity SMALLINT NOT NULL,
    Discount REAL NOT NULL,
    PRIMARY KEY (OrderID, ProductID)
);

-- =====================================================
-- DIMENSION TABLES CREATION
-- Purpose: Descriptive tables for analysis dimensions
-- =====================================================

-- Date dimension for time-based analysis
CREATE TABLE DimDate (
    DateID SERIAL PRIMARY KEY,
    Date DATE NOT NULL UNIQUE,
    Day INTEGER NOT NULL CHECK (Day BETWEEN 1 AND 31),
    Month INTEGER NOT NULL CHECK (Month BETWEEN 1 AND 12),
    Year INTEGER NOT NULL,
    Quarter INTEGER NOT NULL CHECK (Quarter BETWEEN 1 AND 4),
    WeekOfYear INTEGER NOT NULL CHECK (WeekOfYear BETWEEN 1 AND 53),
    DayOfWeek INTEGER NOT NULL CHECK (DayOfWeek BETWEEN 1 AND 7),
    MonthName VARCHAR(9) NOT NULL,
    QuarterName VARCHAR(2) NOT NULL,
    IsWeekend BOOLEAN NOT NULL
);

-- Customer dimension for customer analysis
CREATE TABLE DimCustomer (
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
    LoadDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Employee dimension for employee performance analysis
CREATE TABLE DimEmployee (
    EmployeeID INTEGER PRIMARY KEY,
    LastName VARCHAR(20) NOT NULL,
    FirstName VARCHAR(10) NOT NULL,
    Title VARCHAR(30),
    BirthDate DATE,
    HireDate DATE,
    Address VARCHAR(60),
    City VARCHAR(15),
    Region VARCHAR(15),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    HomePhone VARCHAR(24),
    Extension VARCHAR(4),
    LoadDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Category dimension for product categorization
CREATE TABLE DimCategory (
    CategoryID INTEGER PRIMARY KEY,
    CategoryName VARCHAR(15) NOT NULL,
    Description TEXT,
    LoadDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Shipper dimension for shipping analysis
CREATE TABLE DimShipper (
    ShipperID INTEGER PRIMARY KEY,
    CompanyName VARCHAR(40) NOT NULL,
    Phone VARCHAR(24),
    LoadDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Supplier dimension for supplier analysis
CREATE TABLE DimSupplier (
    SupplierID INTEGER PRIMARY KEY,
    CompanyName VARCHAR(40) NOT NULL,
    ContactName VARCHAR(30),
    ContactTitle VARCHAR(30),
    Address VARCHAR(60),
    City VARCHAR(15),
    Region VARCHAR(15),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    Phone VARCHAR(24),
    LoadDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product dimension for product analysis
CREATE TABLE DimProduct (
    ProductID INTEGER PRIMARY KEY,
    ProductName VARCHAR(40) NOT NULL,
    SupplierID INTEGER,
    CategoryID INTEGER,
    QuantityPerUnit VARCHAR(20),
    UnitPrice DECIMAL(10,2),
    UnitsInStock SMALLINT,
    Discontinued BOOLEAN NOT NULL,
    LoadDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (SupplierID) REFERENCES DimSupplier(SupplierID),
    FOREIGN KEY (CategoryID) REFERENCES DimCategory(CategoryID)
);

-- =====================================================
-- FACT TABLE CREATION
-- Purpose: Central table for sales measurements and metrics
-- =====================================================

CREATE TABLE FactSales (
    SalesID SERIAL PRIMARY KEY,
    DateID INTEGER NOT NULL,
    CustomerID VARCHAR(5) NOT NULL,
    ProductID INTEGER NOT NULL,
    EmployeeID INTEGER,
    CategoryID INTEGER,
    ShipperID INTEGER,
    SupplierID INTEGER,
    QuantitySold SMALLINT NOT NULL CHECK (QuantitySold > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    Discount REAL NOT NULL CHECK (Discount BETWEEN 0 AND 1),
    TotalAmount DECIMAL(15,2) NOT NULL CHECK (TotalAmount >= 0),
    TaxAmount DECIMAL(15,2) NOT NULL CHECK (TaxAmount >= 0),
    LoadDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Foreign key constraints for referential integrity
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID),
    FOREIGN KEY (CustomerID) REFERENCES DimCustomer(CustomerID),
    FOREIGN KEY (ProductID) REFERENCES DimProduct(ProductID),
    FOREIGN KEY (EmployeeID) REFERENCES DimEmployee(EmployeeID),
    FOREIGN KEY (CategoryID) REFERENCES DimCategory(CategoryID),
    FOREIGN KEY (ShipperID) REFERENCES DimShipper(ShipperID),
    FOREIGN KEY (SupplierID) REFERENCES DimSupplier(SupplierID)
);

-- =====================================================
-- INDEX CREATION FOR PERFORMANCE OPTIMIZATION
-- Purpose: Improve query performance for business reports
-- =====================================================

-- Indexes for FactSales foreign keys
CREATE INDEX idx_factsales_dateid ON FactSales(DateID);
CREATE INDEX idx_factsales_customerid ON FactSales(CustomerID);
CREATE INDEX idx_factsales_productid ON FactSales(ProductID);
CREATE INDEX idx_factsales_employeeid ON FactSales(EmployeeID);
CREATE INDEX idx_factsales_categoryid ON FactSales(CategoryID);

-- Indexes for Date dimension commonly used in reporting
CREATE INDEX idx_dimdate_date ON DimDate(Date);
CREATE INDEX idx_dimdate_year_month ON DimDate(Year, Month);
CREATE INDEX idx_dimdate_quarter ON DimDate(Year, Quarter);

-- Indexes for Product dimension
CREATE INDEX idx_dimproduct_categoryid ON DimProduct(CategoryID);
CREATE INDEX idx_dimproduct_supplierid ON DimProduct(SupplierID);

-- Indexes for Customer dimension
CREATE INDEX idx_dimcustomer_country ON DimCustomer(Country);
CREATE INDEX idx_dimcustomer_city ON DimCustomer(City);

-- Composite index for efficient date range queries
CREATE INDEX idx_factsales_date_product ON FactSales(DateID, ProductID);
CREATE INDEX idx_factsales_date_category ON FactSales(DateID, CategoryID);
CREATE INDEX idx_factsales_date_customer ON FactSales(DateID, CustomerID);

-- =====================================================
-- TABLE CREATION COMPLETED
-- =====================================================