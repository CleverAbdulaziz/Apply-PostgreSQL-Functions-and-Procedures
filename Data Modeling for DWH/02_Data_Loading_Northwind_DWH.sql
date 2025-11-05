-- =====================================================
-- Northwind Data Warehouse - Data Loading Script
-- Author: [Your Name]
-- Date: [Current Date]
-- Description: Loads data from source to staging tables, 
--              transforms and loads into dimension and fact tables
-- =====================================================

-- =====================================================
-- STAGING DATA LOADING
-- Purpose: Extract data from source tables to staging area
-- =====================================================

-- Load customers data into staging
INSERT INTO staging_customers 
SELECT * FROM customers;

-- Display count for validation
SELECT 'Staging Customers loaded: ' || COUNT(*)::TEXT FROM staging_customers;

-- Load employees data into staging
INSERT INTO staging_employees 
SELECT * FROM employees;

SELECT 'Staging Employees loaded: ' || COUNT(*)::TEXT FROM staging_employees;

-- Load categories data into staging
INSERT INTO staging_categories 
SELECT * FROM categories;

SELECT 'Staging Categories loaded: ' || COUNT(*)::TEXT FROM staging_categories;

-- Load suppliers data into staging
INSERT INTO staging_suppliers 
SELECT * FROM suppliers;

SELECT 'Staging Suppliers loaded: ' || COUNT(*)::TEXT FROM staging_suppliers;

-- Load shippers data into staging
INSERT INTO staging_shippers 
SELECT * FROM shippers;

SELECT 'Staging Shippers loaded: ' || COUNT(*)::TEXT FROM staging_shippers;

-- Load products data into staging
INSERT INTO staging_products 
SELECT * FROM products;

SELECT 'Staging Products loaded: ' || COUNT(*)::TEXT FROM staging_products;

-- Load orders data into staging
INSERT INTO staging_orders 
SELECT * FROM orders;

SELECT 'Staging Orders loaded: ' || COUNT(*)::TEXT FROM staging_orders;

-- Load order details data into staging
INSERT INTO staging_order_details 
SELECT * FROM order_details;

SELECT 'Staging Order Details loaded: ' || COUNT(*)::TEXT FROM staging_order_details;

-- =====================================================
-- DATE DIMENSION POPULATION
-- Purpose: Create comprehensive date dimension for time analysis
-- =====================================================

-- Generate date dimension for typical Northwind data range (1990-2000)
INSERT INTO DimDate (Date, Day, Month, Year, Quarter, WeekOfYear, DayOfWeek, MonthName, QuarterName, IsWeekend)
SELECT 
    datum AS Date,
    EXTRACT(DAY FROM datum)::INTEGER AS Day,
    EXTRACT(MONTH FROM datum)::INTEGER AS Month,
    EXTRACT(YEAR FROM datum)::INTEGER AS Year,
    EXTRACT(QUARTER FROM datum)::INTEGER AS Quarter,
    EXTRACT(WEEK FROM datum)::INTEGER AS WeekOfYear,
    EXTRACT(ISODOW FROM datum)::INTEGER AS DayOfWeek,
    TO_CHAR(datum, 'Month') AS MonthName,
    'Q' || EXTRACT(QUARTER FROM datum)::TEXT AS QuarterName,
    EXTRACT(ISODOW FROM datum) IN (6, 7) AS IsWeekend
FROM (
    SELECT generate_series(
        '1990-01-01'::date,
        '2000-12-31'::date,
        '1 day'::interval
    ) AS datum
) dates;

-- Validate date dimension population
SELECT 'Date Dimension populated: ' || COUNT(*)::TEXT FROM DimDate;

-- =====================================================
-- DIMENSION DATA LOADING WITH DATA QUALITY CHECKS
-- Purpose: Transform and load clean data into dimension tables
-- =====================================================

-- Load customer dimension with data validation
INSERT INTO DimCustomer (CustomerID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone)
SELECT 
    CustomerID,
    COALESCE(CompanyName, 'Unknown') AS CompanyName,
    ContactName,
    ContactTitle,
    Address,
    COALESCE(City, 'Unknown') AS City,
    Region,
    PostalCode,
    COALESCE(Country, 'Unknown') AS Country,
    Phone
FROM staging_customers
WHERE CustomerID IS NOT NULL;

SELECT 'Customer Dimension loaded: ' || COUNT(*)::TEXT FROM DimCustomer;

-- Load employee dimension with data validation
INSERT INTO DimEmployee (EmployeeID, LastName, FirstName, Title, BirthDate, HireDate, Address, City, Region, PostalCode, Country, HomePhone, Extension)
SELECT 
    EmployeeID,
    COALESCE(LastName, 'Unknown') AS LastName,
    COALESCE(FirstName, 'Unknown') AS FirstName,
    Title,
    BirthDate,
    HireDate,
    Address,
    City,
    Region,
    PostalCode,
    Country,
    HomePhone,
    Extension
FROM staging_employees
WHERE EmployeeID IS NOT NULL;

SELECT 'Employee Dimension loaded: ' || COUNT(*)::TEXT FROM DimEmployee;

-- Load category dimension with data validation
INSERT INTO DimCategory (CategoryID, CategoryName, Description)
SELECT 
    CategoryID,
    COALESCE(CategoryName, 'Unknown') AS CategoryName,
    Description
FROM staging_categories
WHERE CategoryID IS NOT NULL;

SELECT 'Category Dimension loaded: ' || COUNT(*)::TEXT FROM DimCategory;

-- Load shipper dimension with data validation
INSERT INTO DimShipper (ShipperID, CompanyName, Phone)
SELECT 
    ShipperID,
    COALESCE(CompanyName, 'Unknown') AS CompanyName,
    Phone
FROM staging_shippers
WHERE ShipperID IS NOT NULL;

SELECT 'Shipper Dimension loaded: ' || COUNT(*)::TEXT FROM DimShipper;

-- Load supplier dimension with data validation
INSERT INTO DimSupplier (SupplierID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone)
SELECT 
    SupplierID,
    COALESCE(CompanyName, 'Unknown') AS CompanyName,
    ContactName,
    ContactTitle,
    Address,
    COALESCE(City, 'Unknown') AS City,
    Region,
    PostalCode,
    COALESCE(Country, 'Unknown') AS Country,
    Phone
FROM staging_suppliers
WHERE SupplierID IS NOT NULL;

SELECT 'Supplier Dimension loaded: ' || COUNT(*)::TEXT FROM DimSupplier;

-- Load product dimension with data validation and business rules
INSERT INTO DimProduct (ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock, Discontinued)
SELECT 
    p.ProductID,
    COALESCE(p.ProductName, 'Unknown') AS ProductName,
    p.SupplierID,
    p.CategoryID,
    p.QuantityPerUnit,
    COALESCE(p.UnitPrice, 0) AS UnitPrice,
    COALESCE(p.UnitsInStock, 0) AS UnitsInStock,
    COALESCE(p.Discontinued, FALSE) AS Discontinued
FROM staging_products p
WHERE p.ProductID IS NOT NULL
AND EXISTS (SELECT 1 FROM DimSupplier s WHERE s.SupplierID = p.SupplierID)
AND EXISTS (SELECT 1 FROM DimCategory c WHERE c.CategoryID = p.CategoryID);

SELECT 'Product Dimension loaded: ' || COUNT(*)::TEXT FROM DimProduct;

-- =====================================================
-- FACT TABLE LOADING WITH COMPREHENSIVE BUSINESS LOGIC
-- Purpose: Load sales facts with calculated measures and relationships
-- =====================================================

-- Load fact sales with comprehensive business calculations
INSERT INTO FactSales (
    DateID, CustomerID, ProductID, EmployeeID, CategoryID, 
    ShipperID, SupplierID, QuantitySold, UnitPrice, Discount, 
    TotalAmount, TaxAmount
)
SELECT
    dd.DateID,
    o.CustomerID,
    od.ProductID,
    o.EmployeeID,
    p.CategoryID,
    o.ShipVia AS ShipperID,
    p.SupplierID,
    od.Quantity AS QuantitySold,
    od.UnitPrice,
    COALESCE(od.Discount, 0) AS Discount,
    -- Calculate total amount considering discount
    (od.Quantity * od.UnitPrice * (1 - COALESCE(od.Discount, 0))) AS TotalAmount,
    -- Calculate tax amount (assuming 10% tax rate)
    (od.Quantity * od.UnitPrice * (1 - COALESCE(od.Discount, 0)) * 0.1) AS TaxAmount
FROM staging_order_details od
INNER JOIN staging_orders o ON od.OrderID = o.OrderID
INNER JOIN staging_products p ON od.ProductID = p.ProductID
INNER JOIN DimDate dd ON o.OrderDate = dd.Date
INNER JOIN DimCustomer dc ON o.CustomerID = dc.CustomerID
INNER JOIN DimProduct dp ON od.ProductID = dp.ProductID
LEFT JOIN DimEmployee de ON o.EmployeeID = de.EmployeeID
LEFT JOIN DimCategory dcat ON p.CategoryID = dcat.CategoryID
LEFT JOIN DimShipper ds ON o.ShipVia = ds.ShipperID
LEFT JOIN DimSupplier dsup ON p.SupplierID = dsup.SupplierID
WHERE o.OrderDate IS NOT NULL
AND od.Quantity > 0
AND od.UnitPrice >= 0
AND COALESCE(od.Discount, 0) BETWEEN 0 AND 1;

SELECT 'Fact Sales loaded: ' || COUNT(*)::TEXT FROM FactSales;

-- =====================================================
-- DATA QUALITY AND INTEGRITY VALIDATION
-- Purpose: Ensure data completeness and referential integrity
-- =====================================================

-- Data completeness check
SELECT 
    'Staging vs Dimension Records Comparison' AS Check_Type,
    (SELECT COUNT(*) FROM staging_customers) AS Staging_Customers,
    (SELECT COUNT(*) FROM DimCustomer) AS Dimension_Customers,
    (SELECT COUNT(*) FROM staging_products) AS Staging_Products,
    (SELECT COUNT(*) FROM DimProduct) AS Dimension_Products,
    (SELECT COUNT(*) FROM staging_orders) AS Staging_Orders,
    (SELECT COUNT(*) FROM staging_order_details) AS Staging_Order_Details,
    (SELECT COUNT(*) FROM FactSales) AS Fact_Sales;

-- Referential integrity validation
SELECT 
    'Referential Integrity Check' AS Check_Type,
    COUNT(*) AS Total_Fact_Records,
    SUM(CASE WHEN fs.CustomerID IS NULL THEN 1 ELSE 0 END) AS Missing_CustomerID,
    SUM(CASE WHEN fs.ProductID IS NULL THEN 1 ELSE 0 END) AS Missing_ProductID,
    SUM(CASE WHEN fs.DateID IS NULL THEN 1 ELSE 0 END) AS Missing_DateID,
    SUM(CASE WHEN fs.TotalAmount < 0 THEN 1 ELSE 0 END) AS Negative_TotalAmount
FROM FactSales fs;

-- Business rule validation
SELECT 
    'Business Rule Validation' AS Check_Type,
    MIN(TotalAmount) AS Min_TotalAmount,
    MAX(TotalAmount) AS Max_TotalAmount,
    AVG(TotalAmount) AS Avg_TotalAmount,
    MIN(TaxAmount) AS Min_TaxAmount,
    MAX(TaxAmount) AS Max_TaxAmount,
    COUNT(*) AS Total_Records_Validated
FROM FactSales
WHERE TotalAmount >= 0 AND TaxAmount >= 0;

-- =====================================================
-- DATA LOADING COMPLETED SUCCESSFULLY
-- =====================================================