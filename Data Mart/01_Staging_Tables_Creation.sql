-- =============================================
-- STAGING TABLES CREATION SCRIPT
-- Purpose: Create all necessary staging tables for NORTHWIND data warehouse
-- =============================================

-- Products staging table
CREATE TABLE IF NOT EXISTS staging_products (
    ProductID SERIAL PRIMARY KEY,
    ProductName VARCHAR(40) NOT NULL,
    SupplierID INT,
    CategoryID INT,
    QuantityPerUnit VARCHAR(20),
    UnitPrice DECIMAL(10,2) DEFAULT 0,
    UnitsInStock SMALLINT DEFAULT 0,
    UnitsOnOrder SMALLINT DEFAULT 0,
    ReorderLevel SMALLINT DEFAULT 0,
    Discontinued BOOLEAN DEFAULT FALSE
);

-- Suppliers staging table
CREATE TABLE IF NOT EXISTS staging_suppliers (
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
    Fax VARCHAR(24)
);

-- Categories staging table
CREATE TABLE IF NOT EXISTS staging_categories (
    CategoryID SERIAL PRIMARY KEY,
    CategoryName VARCHAR(15) NOT NULL,
    Description TEXT
);

-- Customers staging table
CREATE TABLE IF NOT EXISTS staging_customers (
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
    Fax VARCHAR(24)
);

-- Employees staging table
CREATE TABLE IF NOT EXISTS staging_employees (
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
    ReportsTo INT,
    PhotoPath VARCHAR(255)
);

-- Shippers staging table
CREATE TABLE IF NOT EXISTS staging_shippers (
    ShipperID SERIAL PRIMARY KEY,
    CompanyName VARCHAR(40) NOT NULL,
    Phone VARCHAR(24)
);

-- Orders staging table
CREATE TABLE IF NOT EXISTS staging_orders (
    OrderID SERIAL PRIMARY KEY,
    CustomerID VARCHAR(5),
    EmployeeID INT,
    OrderDate DATE,
    RequiredDate DATE,
    ShippedDate DATE,
    ShipVia INT,
    Freight DECIMAL(10,2) DEFAULT 0,
    ShipName VARCHAR(40),
    ShipAddress VARCHAR(60),
    ShipCity VARCHAR(15),
    ShipRegion VARCHAR(15),
    ShipPostalCode VARCHAR(10),
    ShipCountry VARCHAR(15),
    FOREIGN KEY (CustomerID) REFERENCES staging_customers(CustomerID),
    FOREIGN KEY (EmployeeID) REFERENCES staging_employees(EmployeeID),
    FOREIGN KEY (ShipVia) REFERENCES staging_shippers(ShipperID)
);

-- Order Details staging table
CREATE TABLE IF NOT EXISTS staging_order_details (
    OrderID INT,
    ProductID INT,
    UnitPrice DECIMAL(10,2) NOT NULL,
    Quantity SMALLINT NOT NULL DEFAULT 1,
    Discount REAL DEFAULT 0,
    PRIMARY KEY (OrderID, ProductID),
    FOREIGN KEY (OrderID) REFERENCES staging_orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES staging_products(ProductID),
    CHECK (Quantity > 0),
    CHECK (Discount BETWEEN 0 AND 1)
);

-- Comments for documentation
COMMENT ON TABLE staging_products IS 'Staging table for product data from NORTHWIND database';
COMMENT ON TABLE staging_suppliers IS 'Staging table for supplier information';
COMMENT ON TABLE staging_categories IS 'Staging table for product categories';
COMMENT ON TABLE staging_customers IS 'Staging table for customer information';
COMMENT ON TABLE staging_employees IS 'Staging table for employee records';
COMMENT ON TABLE staging_shippers IS 'Staging table for shipping companies';
COMMENT ON TABLE staging_orders IS 'Staging table for order headers';
COMMENT ON TABLE staging_order_details IS 'Staging table for order line items with pricing and discounts';