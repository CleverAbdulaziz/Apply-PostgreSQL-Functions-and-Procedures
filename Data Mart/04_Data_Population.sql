-- =============================================
-- DATA POPULATION SCRIPT
-- Purpose: Populate dimension and fact tables with data from staging tables
-- =============================================

-- Begin transaction for data consistency
BEGIN;

-- Step 1: Populate Date Dimension with comprehensive date range
INSERT INTO DimDate (Date, Day, Month, Year, Quarter, WeekOfYear, DayOfWeek, DayName, MonthName, IsWeekend)
SELECT 
    datum AS Date,
    EXTRACT(DAY FROM datum) AS Day,
    EXTRACT(MONTH FROM datum) AS Month,
    EXTRACT(YEAR FROM datum) AS Year,
    EXTRACT(QUARTER FROM datum) AS Quarter,
    EXTRACT(WEEK FROM datum) AS WeekOfYear,
    EXTRACT(DOW FROM datum) AS DayOfWeek,
    TO_CHAR(datum, 'Day') AS DayName,
    TO_CHAR(datum, 'Month') AS MonthName,
    EXTRACT(DOW FROM datum) IN (0,6) AS IsWeekend
FROM (
    SELECT GENERATE_SERIES(
        '1990-01-01'::DATE, 
        '2025-12-31'::DATE, 
        '1 day'::INTERVAL
    ) AS datum
) dates
ON CONFLICT (Date) DO NOTHING;

-- Step 2: Populate Supplier Dimension
INSERT INTO DimSupplier (SupplierID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
SELECT 
    SupplierID, 
    CompanyName, 
    ContactName, 
    ContactTitle, 
    Address, 
    City, 
    Region, 
    PostalCode, 
    Country, 
    Phone, 
    Fax
FROM staging_suppliers
ON CONFLICT (SupplierID) DO UPDATE SET
    CompanyName = EXCLUDED.CompanyName,
    ContactName = EXCLUDED.ContactName,
    ContactTitle = EXCLUDED.ContactTitle,
    Address = EXCLUDED.Address,
    City = EXCLUDED.City;

-- Step 3: Populate Category Dimension
INSERT INTO DimCategory (CategoryID, CategoryName, Description)
SELECT 
    CategoryID, 
    CategoryName, 
    Description
FROM staging_categories
ON CONFLICT (CategoryID) DO UPDATE SET
    CategoryName = EXCLUDED.CategoryName,
    Description = EXCLUDED.Description;

-- Step 4: Populate Product Dimension (current versions only)
INSERT INTO DimProduct (ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock, UnitsOnOrder, ReorderLevel, Discontinued)
SELECT 
    ProductID, 
    ProductName, 
    SupplierID, 
    CategoryID, 
    QuantityPerUnit, 
    UnitPrice, 
    UnitsInStock, 
    UnitsOnOrder, 
    ReorderLevel, 
    Discontinued
FROM staging_products
ON CONFLICT (ProductID) DO UPDATE SET
    ProductName = EXCLUDED.ProductName,
    UnitPrice = EXCLUDED.UnitPrice,
    UnitsInStock = EXCLUDED.UnitsInStock;

-- Step 5: Populate Customer Dimension
INSERT INTO DimCustomer (CustomerID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
SELECT 
    CustomerID, 
    CompanyName, 
    ContactName, 
    ContactTitle, 
    Address, 
    City, 
    Region, 
    PostalCode, 
    Country, 
    Phone, 
    Fax
FROM staging_customers
ON CONFLICT (CustomerID) DO UPDATE SET
    CompanyName = EXCLUDED.CompanyName,
    ContactName = EXCLUDED.ContactName,
    City = EXCLUDED.City,
    Country = EXCLUDED.Country;

-- Step 6: Populate Employee Dimension
INSERT INTO DimEmployee (EmployeeID, LastName, FirstName, Title, TitleOfCourtesy, BirthDate, HireDate, Address, City, Region, PostalCode, Country, HomePhone, ReportsTo)
SELECT 
    EmployeeID, 
    LastName, 
    FirstName, 
    Title, 
    TitleOfCourtesy, 
    BirthDate, 
    HireDate, 
    Address, 
    City, 
    Region, 
    PostalCode, 
    Country, 
    HomePhone, 
    ReportsTo
FROM staging_employees
ON CONFLICT (EmployeeID) DO UPDATE SET
    LastName = EXCLUDED.LastName,
    FirstName = EXCLUDED.FirstName,
    Title = EXCLUDED.Title;

-- Step 7: Populate Shipper Dimension
INSERT INTO DimShipper (ShipperID, CompanyName, Phone)
SELECT 
    ShipperID, 
    CompanyName, 
    Phone
FROM staging_shippers
ON CONFLICT (ShipperID) DO UPDATE SET
    CompanyName = EXCLUDED.CompanyName,
    Phone = EXCLUDED.Phone;

-- Step 8: Populate Main Sales Fact Table
INSERT INTO FactSales (
    DateID, CustomerID, ProductID, EmployeeID, CategoryID, ShipperID, SupplierID, OrderID, 
    QuantitySold, UnitPrice, Discount, LineTotal, TaxAmount, FreightCost
)
SELECT 
    d.DateID,
    o.CustomerID,
    od.ProductID,
    o.EmployeeID,
    p.CategoryID,
    o.ShipVia AS ShipperID,
    p.SupplierID,
    o.OrderID,
    od.Quantity AS QuantitySold,
    od.UnitPrice,
    od.Discount,
    (od.Quantity * od.UnitPrice * (1 - od.Discount)) AS LineTotal,
    (od.Quantity * od.UnitPrice * (1 - od.Discount)) * 0.1 AS TaxAmount, -- 10% tax assumption
    o.Freight / (SELECT COUNT(*) FROM staging_order_details WHERE OrderID = o.OrderID) AS FreightCost -- Allocate freight
FROM staging_order_details od
JOIN staging_orders o ON od.OrderID = o.OrderID
JOIN staging_products p ON od.ProductID = p.ProductID
JOIN DimDate d ON o.OrderDate = d.Date
WHERE o.OrderDate IS NOT NULL;

-- Step 9: Populate Supplier Purchases Fact Table
INSERT INTO FactSupplierPurchases (SupplierID, DateID, TotalPurchaseAmount, NumberOfProducts, AverageUnitPrice, TotalQuantity)
SELECT 
    p.SupplierID,
    d.DateID,
    SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS TotalPurchaseAmount,
    COUNT(DISTINCT od.ProductID) AS NumberOfProducts,
    AVG(od.UnitPrice) AS AverageUnitPrice,
    SUM(od.Quantity) AS TotalQuantity
FROM staging_order_details od
JOIN staging_orders o ON od.OrderID = o.OrderID
JOIN staging_products p ON od.ProductID = p.ProductID
JOIN DimDate d ON o.OrderDate = d.Date
WHERE o.OrderDate IS NOT NULL
GROUP BY p.SupplierID, d.DateID;

-- Step 10: Populate Product Sales Fact Table
INSERT INTO FactProductSales (DateID, ProductID, CategoryID, SupplierID, QuantitySold, TotalSales, AverageUnitPrice, NumberOfOrders)
SELECT 
    d.DateID,
    p.ProductID,
    p.CategoryID,
    p.SupplierID,
    SUM(od.Quantity) AS QuantitySold,
    SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS TotalSales,
    AVG(od.UnitPrice) AS AverageUnitPrice,
    COUNT(DISTINCT o.OrderID) AS NumberOfOrders
FROM staging_order_details od
JOIN staging_orders o ON od.OrderID = o.OrderID
JOIN staging_products p ON od.ProductID = p.ProductID
JOIN DimDate d ON o.OrderDate = d.Date
WHERE o.OrderDate IS NOT NULL
GROUP BY d.DateID, p.ProductID, p.CategoryID, p.SupplierID;

-- Step 11: Populate Customer Sales Fact Table
INSERT INTO FactCustomerSales (DateID, CustomerID, TotalAmount, TotalQuantity, NumberOfTransactions, AverageTransactionValue, DaysSinceFirstPurchase)
SELECT 
    d.DateID,
    o.CustomerID,
    SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS TotalAmount,
    SUM(od.Quantity) AS TotalQuantity,
    COUNT(DISTINCT o.OrderID) AS NumberOfTransactions,
    AVG(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS AverageTransactionValue,
    EXTRACT(DAYS FROM (o.OrderDate - MIN(o.OrderDate) OVER (PARTITION BY o.CustomerID))) AS DaysSinceFirstPurchase
FROM staging_orders o
JOIN staging_order_details od ON o.OrderID = od.OrderID
JOIN DimDate d ON o.OrderDate = d.Date
WHERE o.OrderDate IS NOT NULL
GROUP BY d.DateID, o.CustomerID, o.OrderDate;

-- Step 12: Populate Inventory Fact Table (current snapshot)
INSERT INTO FactInventory (DateID, ProductID, UnitsInStock, UnitsOnOrder, ReorderLevel, StockValue, IsBelowReorderLevel, DaysOfSupply)
SELECT 
    (SELECT DateID FROM DimDate WHERE Date = CURRENT_DATE) AS DateID,
    p.ProductID,
    p.UnitsInStock,
    p.UnitsOnOrder,
    p.ReorderLevel,
    (p.UnitsInStock * p.UnitPrice) AS StockValue,
    (p.UnitsInStock <= p.ReorderLevel) AS IsBelowReorderLevel,
    CASE 
        WHEN (SELECT AVG(Quantity) FROM staging_order_details WHERE ProductID = p.ProductID) > 0 
        THEN (p.UnitsInStock / (SELECT AVG(Quantity) FROM staging_order_details WHERE ProductID = p.ProductID))
        ELSE NULL 
    END AS DaysOfSupply
FROM staging_products p
WHERE p.UnitsInStock IS NOT NULL;

-- Commit transaction
COMMIT;

-- Verification queries
SELECT 'Dimension Tables Count:' AS "Verification";
SELECT 'DimDate: ' || COUNT(*) FROM DimDate
UNION ALL SELECT 'DimSupplier: ' || COUNT(*) FROM DimSupplier
UNION ALL SELECT 'DimCategory: ' || COUNT(*) FROM DimCategory
UNION ALL SELECT 'DimProduct: ' || COUNT(*) FROM DimProduct
UNION ALL SELECT 'DimCustomer: ' || COUNT(*) FROM DimCustomer
UNION ALL SELECT 'DimEmployee: ' || COUNT(*) FROM DimEmployee
UNION ALL SELECT 'DimShipper: ' || COUNT(*) FROM DimShipper;

SELECT 'Fact Tables Count:' AS "Verification";
SELECT 'FactSales: ' || COUNT(*) FROM FactSales
UNION ALL SELECT 'FactSupplierPurchases: ' || COUNT(*) FROM FactSupplierPurchases
UNION ALL SELECT 'FactProductSales: ' || COUNT(*) FROM FactProductSales
UNION ALL SELECT 'FactCustomerSales: ' || COUNT(*) FROM FactCustomerSales
UNION ALL SELECT 'FactInventory: ' || COUNT(*) FROM FactInventory;