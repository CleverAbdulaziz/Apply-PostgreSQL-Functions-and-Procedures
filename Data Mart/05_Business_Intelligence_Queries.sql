-- =============================================
-- BUSINESS INTELLIGENCE QUERIES SCRIPT
-- Purpose: Comprehensive analytical queries for all data marts
-- =============================================

-- SUPPLIERS DATA MART QUERIES

-- Query 1: Supplier Performance Scorecard
WITH SupplierMetrics AS (
    SELECT
        s.CompanyName,
        s.Country,
        COUNT(DISTINCT fsp.PurchaseID) AS TotalPurchases,
        SUM(fsp.TotalPurchaseAmount) AS TotalSpend,
        AVG(fsp.TotalPurchaseAmount) AS AvgPurchaseValue,
        SUM(fsp.TotalQuantity) AS TotalUnitsPurchased,
        AVG(fsp.AverageUnitPrice) AS AvgUnitPrice,
        COUNT(DISTINCT p.ProductID) AS UniqueProductsSupplied
    FROM FactSupplierPurchases fsp
    JOIN DimSupplier s ON fsp.SupplierID = s.SupplierID
    JOIN DimProduct p ON s.SupplierID = p.SupplierID
    GROUP BY s.CompanyName, s.Country
)
SELECT 
    CompanyName AS "Supplier",
    Country,
    TotalSpend AS "Total Spend",
    RANK() OVER (ORDER BY TotalSpend DESC) AS "Spend Rank",
    TotalUnitsPurchased AS "Total Units",
    AvgUnitPrice AS "Avg Price",
    UniqueProductsSupplied AS "Product Count",
    CASE 
        WHEN TotalSpend > 100000 THEN 'Strategic Partner'
        WHEN TotalSpend BETWEEN 50000 AND 100000 THEN 'Key Supplier'
        WHEN TotalSpend BETWEEN 10000 AND 50000 THEN 'Preferred Supplier'
        ELSE 'Standard Supplier'
    END AS "Supplier Tier"
FROM SupplierMetrics
ORDER BY TotalSpend DESC;

-- Query 2: Monthly Supplier Spending Trend
SELECT
    d.Year,
    d.Month,
    s.CompanyName AS Supplier,
    SUM(fsp.TotalPurchaseAmount) AS MonthlySpend,
    LAG(SUM(fsp.TotalPurchaseAmount)) OVER (PARTITION BY s.CompanyName ORDER BY d.Year, d.Month) AS PreviousMonthSpend,
    CASE 
        WHEN LAG(SUM(fsp.TotalPurchaseAmount)) OVER (PARTITION BY s.CompanyName ORDER BY d.Year, d.Month) IS NOT NULL
        THEN ROUND(((SUM(fsp.TotalPurchaseAmount) - LAG(SUM(fsp.TotalPurchaseAmount)) OVER (PARTITION BY s.CompanyName ORDER BY d.Year, d.Month)) 
              / LAG(SUM(fsp.TotalPurchaseAmount)) OVER (PARTITION BY s.CompanyName ORDER BY d.Year, d.Month)) * 100, 2)
        ELSE NULL
    END AS MonthlyGrowthPercent
FROM FactSupplierPurchases fsp
JOIN DimSupplier s ON fsp.SupplierID = s.SupplierID
JOIN DimDate d ON fsp.DateID = d.DateID
GROUP BY d.Year, d.Month, s.CompanyName
ORDER BY d.Year, d.Month, MonthlySpend DESC;

-- PRODUCTS DATA MART QUERIES

-- Query 3: Product Performance Dashboard
SELECT
    p.ProductName,
    c.CategoryName,
    s.CompanyName AS Supplier,
    SUM(fps.QuantitySold) AS TotalUnitsSold,
    SUM(fps.TotalSales) AS TotalRevenue,
    AVG(fps.AverageUnitPrice) AS AvgSellingPrice,
    SUM(fps.NumberOfOrders) AS OrderCount,
    RANK() OVER (ORDER BY SUM(fps.TotalSales) DESC) AS RevenueRank,
    CASE 
        WHEN SUM(fps.QuantitySold) > 1000 THEN 'High Demand'
        WHEN SUM(fps.QuantitySold) BETWEEN 500 AND 1000 THEN 'Medium Demand'
        ELSE 'Low Demand'
    END AS DemandCategory
FROM FactProductSales fps
JOIN DimProduct p ON fps.ProductID = p.ProductID
JOIN DimCategory c ON fps.CategoryID = c.CategoryID
JOIN DimSupplier s ON fps.SupplierID = s.SupplierID
GROUP BY p.ProductName, c.CategoryName, s.CompanyName
ORDER BY TotalRevenue DESC
LIMIT 15;

-- Query 4: Inventory Health Analysis
SELECT
    p.ProductName,
    c.CategoryName,
    fi.UnitsInStock,
    fi.UnitsOnOrder,
    fi.ReorderLevel,
    fi.StockValue,
    fi.IsBelowReorderLevel,
    fi.DaysOfSupply,
    CASE 
        WHEN fi.DaysOfSupply > 60 THEN 'Overstocked'
        WHEN fi.DaysOfSupply BETWEEN 30 AND 60 THEN 'Adequate Stock'
        WHEN fi.DaysOfSupply BETWEEN 15 AND 30 THEN 'Low Stock'
        ELSE 'Critical Stock'
    END AS StockStatus,
    CASE 
        WHEN fi.IsBelowReorderLevel THEN 'REORDER NEEDED'
        ELSE 'Stock OK'
    END AS ActionRequired
FROM FactInventory fi
JOIN DimProduct p ON fi.ProductID = p.ProductID
JOIN DimCategory c ON p.CategoryID = c.CategoryID
ORDER BY fi.StockValue DESC, fi.IsBelowReorderLevel DESC;

-- CUSTOMERS DATA MART QUERIES

-- Query 5: Customer Lifetime Value Analysis
WITH CustomerCLV AS (
    SELECT
        c.CompanyName,
        c.Country,
        c.CustomerSegment,
        SUM(fcs.TotalAmount) AS LifetimeValue,
        SUM(fcs.NumberOfTransactions) AS TotalTransactions,
        AVG(fcs.AverageTransactionValue) AS AvgTransactionValue,
        MAX(fcs.DaysSinceFirstPurchase) AS CustomerTenure,
        SUM(fcs.TotalQuantity) AS TotalItemsPurchased,
        ROUND(SUM(fcs.TotalAmount) / NULLIF(SUM(fcs.NumberOfTransactions), 0), 2) AS RevenuePerTransaction
    FROM FactCustomerSales fcs
    JOIN DimCustomer c ON fcs.CustomerID = c.CustomerID
    GROUP BY c.CompanyName, c.Country, c.CustomerSegment
)
SELECT
    CompanyName AS "Customer",
    Country,
    CustomerSegment AS "Segment",
    LifetimeValue AS "LTV",
    RANK() OVER (ORDER BY LifetimeValue DESC) AS "LTV Rank",
    TotalTransactions AS "Transactions",
    AvgTransactionValue AS "Avg Order Value",
    CustomerTenure AS "Tenure (Days)",
    CASE 
        WHEN LifetimeValue > 50000 THEN 'Platinum'
        WHEN LifetimeValue BETWEEN 20000 AND 50000 THEN 'Gold'
        WHEN LifetimeValue BETWEEN 10000 AND 20000 THEN 'Silver'
        ELSE 'Bronze'
    END AS "Value Tier"
FROM CustomerCLV
ORDER BY LifetimeValue DESC;

-- Query 6: Customer Geographic Analysis
SELECT
    c.Country,
    c.Region,
    COUNT(DISTINCT c.CustomerID) AS CustomerCount,
    SUM(fcs.TotalAmount) AS TotalRevenue,
    SUM(fcs.TotalQuantity) AS TotalUnitsSold,
    ROUND(AVG(fcs.AverageTransactionValue), 2) AS AvgOrderValue,
    ROUND(SUM(fcs.TotalAmount) / COUNT(DISTINCT c.CustomerID), 2) AS RevenuePerCustomer
FROM FactCustomerSales fcs
JOIN DimCustomer c ON fcs.CustomerID = c.CustomerID
GROUP BY GROUPING SETS ((c.Country), (c.Country, c.Region))
ORDER BY TotalRevenue DESC;

-- SALES DATA MART QUERIES

-- Query 7: Comprehensive Sales Performance Dashboard
SELECT
    d.Year,
    d.Month,
    c.CategoryName,
    e.FullName AS Employee,
    s.CompanyName AS Shipper,
    COUNT(DISTINCT fs.OrderID) AS OrderCount,
    SUM(fs.QuantitySold) AS TotalUnitsSold,
    SUM(fs.LineTotal) AS GrossSales,
    SUM(fs.TaxAmount) AS TotalTax,
    SUM(fs.FreightCost) AS TotalFreight,
    SUM(fs.LineTotal + fs.TaxAmount + fs.FreightCost) AS TotalRevenue,
    ROUND(AVG(fs.LineTotal), 2) AS AvgOrderValue,
    ROUND(SUM(fs.Discount * fs.UnitPrice * fs.QuantitySold), 2) AS TotalDiscounts
FROM FactSales fs
JOIN DimDate d ON fs.DateID = d.DateID
JOIN DimCategory c ON fs.CategoryID = c.CategoryID
JOIN DimEmployee e ON fs.EmployeeID = e.EmployeeID
JOIN DimShipper s ON fs.ShipperID = s.ShipperID
GROUP BY d.Year, d.Month, c.CategoryName, e.FullName, s.CompanyName
ORDER BY d.Year, d.Month, TotalRevenue DESC;

-- Query 8: Sales Trend Analysis with Moving Averages
WITH MonthlySales AS (
    SELECT
        d.Year,
        d.Month,
        SUM(fs.LineTotal) AS MonthlySales,
        SUM(fs.QuantitySold) AS MonthlyUnits,
        COUNT(DISTINCT fs.OrderID) AS MonthlyOrders
    FROM FactSales fs
    JOIN DimDate d ON fs.DateID = d.DateID
    GROUP BY d.Year, d.Month
),
SalesWithTrends AS (
    SELECT
        Year,
        Month,
        MonthlySales,
        MonthlyUnits,
        MonthlyOrders,
        LAG(MonthlySales) OVER (ORDER BY Year, Month) AS PreviousMonthSales,
        AVG(MonthlySales) OVER (ORDER BY Year, Month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ThreeMonthMovingAvg,
        SUM(MonthlySales) OVER (PARTITION BY Year ORDER BY Month) AS YTDSales
    FROM MonthlySales
)
SELECT
    Year,
    Month,
    MonthlySales,
    PreviousMonthSales,
    CASE 
        WHEN PreviousMonthSales IS NOT NULL 
        THEN ROUND(((MonthlySales - PreviousMonthSales) / PreviousMonthSales) * 100, 2)
        ELSE NULL
    END AS MonthlyGrowthPercent,
    ThreeMonthMovingAvg,
    YTDSales,
    CASE 
        WHEN MonthlySales > ThreeMonthMovingAvg THEN 'Above Trend'
        WHEN MonthlySales < ThreeMonthMovingAvg THEN 'Below Trend'
        ELSE 'On Trend'
    END AS TrendStatus
FROM SalesWithTrends
ORDER BY Year, Month;

-- Query 9: Employee Sales Performance with Commission Calculation
SELECT
    e.FullName,
    e.Title,
    e.HireDate,
    COUNT(DISTINCT fs.OrderID) AS TotalOrders,
    SUM(fs.QuantitySold) AS TotalUnitsSold,
    SUM(fs.LineTotal) AS TotalSales,
    ROUND(AVG(fs.LineTotal), 2) AS AvgOrderValue,
    ROUND(SUM(fs.LineTotal) * 0.05, 2) AS EstimatedCommission, -- 5% commission assumption
    RANK() OVER (ORDER BY SUM(fs.LineTotal) DESC) AS SalesRank,
    CASE 
        WHEN SUM(fs.LineTotal) > 100000 THEN 'Top Performer'
        WHEN SUM(fs.LineTotal) BETWEEN 50000 AND 100000 THEN 'Strong Performer'
        WHEN SUM(fs.LineTotal) BETWEEN 25000 AND 50000 THEN 'Solid Performer'
        ELSE 'Developing'
    END AS PerformanceCategory
FROM FactSales fs
JOIN DimEmployee e ON fs.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeID, e.FullName, e.Title, e.HireDate
ORDER BY TotalSales DESC;

-- Query 10: Product Category Performance Deep Dive
SELECT
    c.CategoryName,
    COUNT(DISTINCT p.ProductID) AS ProductCount,
    SUM(fs.QuantitySold) AS TotalUnitsSold,
    SUM(fs.LineTotal) AS TotalRevenue,
    ROUND(SUM(fs.LineTotal) / SUM(fs.QuantitySold), 2) AS AvgPricePerUnit,
    SUM(fs.QuantitySold) / COUNT(DISTINCT p.ProductID) AS AvgUnitsPerProduct,
    ROUND(SUM(fs.LineTotal) / COUNT(DISTINCT p.ProductID), 2) AS AvgRevenuePerProduct,
    RANK() OVER (ORDER BY SUM(fs.LineTotal) DESC) AS RevenueRank,
    ROUND((SUM(fs.LineTotal) / (SELECT SUM(LineTotal) FROM FactSales)) * 100, 2) AS MarketSharePercent
FROM FactSales fs
JOIN DimCategory c ON fs.CategoryID = c.CategoryID
JOIN DimProduct p ON fs.ProductID = p.ProductID
GROUP BY c.CategoryName
ORDER BY TotalRevenue DESC;

-- Advanced: Cross-Data Mart Analysis
-- Query 11: Supplier-Product-Customer Relationship Analysis
SELECT
    sup.CompanyName AS Supplier,
    cat.CategoryName,
    cus.CompanyName AS Customer,
    COUNT(DISTINCT fs.OrderID) AS SharedTransactions,
    SUM(fs.QuantitySold) AS TotalUnits,
    SUM(fs.LineTotal) AS TotalRevenue,
    ROUND(AVG(fs.UnitPrice), 2) AS AvgUnitPrice
FROM FactSales fs
JOIN DimSupplier sup ON fs.SupplierID = sup.SupplierID
JOIN DimCategory cat ON fs.CategoryID = cat.CategoryID
JOIN DimCustomer cus ON fs.CustomerID = cus.CustomerID
GROUP BY sup.CompanyName, cat.CategoryName, cus.CompanyName
HAVING COUNT(DISTINCT fs.OrderID) >= 5
ORDER BY TotalRevenue DESC
LIMIT 20;