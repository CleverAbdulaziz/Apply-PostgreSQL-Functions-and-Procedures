-- =====================================================
-- Northwind Data Warehouse - Business Reports Script
-- Author: [Your Name]
-- Date: [Current Date]
-- Description: Comprehensive business intelligence queries
--              for sales analysis and performance reporting
-- =====================================================

-- =====================================================
-- REPORT 1: Sales Trends per Product Category Monthly
-- Purpose: Analyze average sales, quantities, and transactions
--          for Q1 (Jan, Feb, Mar) by category
-- =====================================================

WITH MonthlyCategorySales AS (
    SELECT 
        d.Year,
        d.Month,
        d.MonthName,
        c.CategoryName,
        COUNT(DISTINCT fs.SalesID) AS TransactionCount,
        SUM(fs.QuantitySold) AS TotalQuantitySold,
        ROUND(AVG(fs.TotalAmount), 2) AS AvgSalesAmount,
        ROUND(SUM(fs.TotalAmount), 2) AS TotalSalesAmount
    FROM FactSales fs
    INNER JOIN DimDate d ON fs.DateID = d.DateID
    INNER JOIN DimProduct p ON fs.ProductID = p.ProductID
    INNER JOIN DimCategory c ON p.CategoryID = c.CategoryID
    WHERE d.Month IN (1, 2, 3) -- January, February, March
    GROUP BY d.Year, d.Month, d.MonthName, c.CategoryName
)
SELECT 
    Year,
    Month,
    MonthName,
    CategoryName,
    TransactionCount,
    TotalQuantitySold,
    AvgSalesAmount,
    TotalSalesAmount,
    -- Calculate month-over-month growth for insightful trends
    LAG(TotalSalesAmount) OVER (
        PARTITION BY CategoryName 
        ORDER BY Year, Month
    ) AS PreviousMonthSales,
    CASE 
        WHEN LAG(TotalSalesAmount) OVER (
            PARTITION BY CategoryName 
            ORDER BY Year, Month
        ) IS NOT NULL THEN
            ROUND(
                ((TotalSalesAmount - LAG(TotalSalesAmount) OVER (
                    PARTITION BY CategoryName 
                    ORDER BY Year, Month
                )) / LAG(TotalSalesAmount) OVER (
                    PARTITION BY CategoryName 
                    ORDER BY Year, Month
                )) * 100, 2
            )
        ELSE NULL
    END AS SalesGrowthPercent
FROM MonthlyCategorySales
ORDER BY Year, Month, TotalSalesAmount DESC;

-- =====================================================
-- REPORT 2: Top Products by Transactions and Sales Monthly
-- Purpose: Identify top 5 products by transactions and sales
--          with category information
-- =====================================================

WITH ProductMonthlyMetrics AS (
    SELECT 
        EXTRACT(YEAR FROM d.Date) AS Year,
        EXTRACT(MONTH FROM d.Date) AS Month,
        p.ProductID,
        p.ProductName,
        c.CategoryName,
        COUNT(fs.SalesID) AS TransactionCount,
        ROUND(SUM(fs.TotalAmount), 2) AS TotalSales,
        ROUND(SUM(fs.TaxAmount), 2) AS TotalTax,
        ROUND(AVG(fs.TotalAmount), 2) AS AvgTransactionValue
    FROM FactSales fs
    INNER JOIN DimDate d ON fs.DateID = d.DateID
    INNER JOIN DimProduct p ON fs.ProductID = p.ProductID
    INNER JOIN DimCategory c ON p.CategoryID = c.CategoryID
    GROUP BY Year, Month, p.ProductID, p.ProductName, c.CategoryName
),
RankedProducts AS (
    SELECT *,
        -- Rank by transaction count
        RANK() OVER (
            PARTITION BY Year, Month 
            ORDER BY TransactionCount DESC
        ) AS TransactionRank,
        -- Rank by total sales
        RANK() OVER (
            PARTITION BY Year, Month 
            ORDER BY TotalSales DESC
        ) AS SalesRank
    FROM ProductMonthlyMetrics
)
SELECT 
    Year,
    Month,
    ProductName,
    CategoryName,
    TransactionCount,
    TotalSales,
    TotalTax,
    AvgTransactionValue,
    TransactionRank,
    SalesRank,
    CASE 
        WHEN TransactionRank <= 5 AND SalesRank <= 5 THEN 'Top in Both'
        WHEN TransactionRank <= 5 THEN 'Top in Transactions'
        WHEN SalesRank <= 5 THEN 'Top in Sales'
        ELSE 'Not in Top 5'
    END AS PerformanceCategory
FROM RankedProducts
WHERE TransactionRank <= 5 OR SalesRank <= 5
ORDER BY Year, Month, TransactionRank, SalesRank;

-- =====================================================
-- REPORT 3: Top Five Customers by Transactions and Purchases
-- Purpose: Identify most valuable customers by activity and spending
-- =====================================================

WITH CustomerMetrics AS (
    SELECT 
        c.CustomerID,
        c.CompanyName,
        c.Country,
        c.City,
        COUNT(DISTINCT fs.SalesID) AS TransactionCount,
        ROUND(SUM(fs.TotalAmount), 2) AS TotalPurchaseAmount,
        ROUND(AVG(fs.TotalAmount), 2) AS AvgTransactionValue,
        COUNT(DISTINCT p.CategoryID) AS UniqueCategoriesPurchased,
        MAX(d.Date) AS LastPurchaseDate
    FROM FactSales fs
    INNER JOIN DimCustomer c ON fs.CustomerID = c.CustomerID
    INNER JOIN DimDate d ON fs.DateID = d.DateID
    INNER JOIN DimProduct p ON fs.ProductID = p.ProductID
    GROUP BY c.CustomerID, c.CompanyName, c.Country, c.City
),
RankedCustomers AS (
    SELECT *,
        RANK() OVER (ORDER BY TransactionCount DESC) AS TransactionRank,
        RANK() OVER (ORDER BY TotalPurchaseAmount DESC) AS PurchaseRank,
        -- Customer value score combining frequency and monetary value
        ROUND(
            (TransactionCount * 0.4 + TotalPurchaseAmount * 0.6) / 100, 2
        ) AS CustomerValueScore
    FROM CustomerMetrics
)
SELECT 
    CustomerID,
    CompanyName,
    Country,
    City,
    TransactionCount,
    TotalPurchaseAmount,
    AvgTransactionValue,
    UniqueCategoriesPurchased,
    LastPurchaseDate,
    TransactionRank,
    PurchaseRank,
    CustomerValueScore
FROM RankedCustomers
WHERE TransactionRank <= 5 OR PurchaseRank <= 5
ORDER BY CustomerValueScore DESC, TotalPurchaseAmount DESC
LIMIT 10; -- Show top 10 for comprehensive view

-- =====================================================
-- REPORT 4: Sales Chart for First Week of Each Month
-- Purpose: Analyze sales performance in the first week of each month
-- =====================================================

WITH FirstWeekSales AS (
    SELECT 
        d.Year,
        d.Month,
        d.MonthName,
        MIN(d.WeekOfYear) AS FirstWeek,
        COUNT(fs.SalesID) AS TransactionCount,
        SUM(fs.QuantitySold) AS TotalQuantitySold,
        ROUND(SUM(fs.TotalAmount), 2) AS TotalSalesAmount,
        ROUND(SUM(fs.TaxAmount), 2) AS TotalTaxAmount,
        ROUND(AVG(fs.TotalAmount), 2) AS AvgTransactionValue
    FROM FactSales fs
    INNER JOIN DimDate d ON fs.DateID = d.DateID
    WHERE d.WeekOfYear = (
        SELECT MIN(d2.WeekOfYear) 
        FROM DimDate d2 
        WHERE d2.Year = d.Year AND d2.Month = d.Month
    )
    GROUP BY d.Year, d.Month, d.MonthName
),
FirstWeekGrowth AS (
    SELECT *,
        LAG(TotalSalesAmount) OVER (
            PARTITION BY Month 
            ORDER BY Year, Month
        ) AS PreviousYearSameMonthSales,
        CASE 
            WHEN LAG(TotalSalesAmount) OVER (
                PARTITION BY Month 
                ORDER BY Year, Month
            ) IS NOT NULL THEN
                ROUND(
                    ((TotalSalesAmount - LAG(TotalSalesAmount) OVER (
                        PARTITION BY Month 
                        ORDER BY Year, Month
                    )) / LAG(TotalSalesAmount) OVER (
                        PARTITION BY Month 
                        ORDER BY Year, Month
                    )) * 100, 2
                )
            ELSE NULL
        END AS YearOverYearGrowth
    FROM FirstWeekSales
)
SELECT 
    Year,
    Month,
    MonthName,
    FirstWeek,
    TransactionCount,
    TotalQuantitySold,
    TotalSalesAmount,
    TotalTaxAmount,
    AvgTransactionValue,
    PreviousYearSameMonthSales,
    YearOverYearGrowth,
    CASE 
        WHEN YearOverYearGrowth > 0 THEN 'Growth'
        WHEN YearOverYearGrowth < 0 THEN 'Decline'
        ELSE 'Stable'
    END AS GrowthStatus
FROM FirstWeekGrowth
ORDER BY Year, Month;

-- =====================================================
-- REPORT 5: Weekly Sales Report by Product Categories
-- Purpose: Detailed weekly sales analysis with monthly rollups
-- =====================================================

WITH WeeklyCategorySales AS (
    SELECT 
        d.Year,
        d.Month,
        d.MonthName,
        d.WeekOfYear,
        c.CategoryName,
        COUNT(fs.SalesID) AS WeeklyTransactions,
        SUM(fs.QuantitySold) AS WeeklyQuantity,
        ROUND(SUM(fs.TotalAmount), 2) AS WeeklySales,
        ROUND(SUM(fs.TaxAmount), 2) AS WeeklyTax
    FROM FactSales fs
    INNER JOIN DimDate d ON fs.DateID = d.DateID
    INNER JOIN DimProduct p ON fs.ProductID = p.ProductID
    INNER JOIN DimCategory c ON p.CategoryID = c.CategoryID
    WHERE d.Year = 1997 -- Focus on a specific year for clarity
    GROUP BY d.Year, d.Month, d.MonthName, d.WeekOfYear, c.CategoryName
),
MonthlyTotals AS (
    SELECT 
        Year,
        Month,
        CategoryName,
        SUM(WeeklyTransactions) AS MonthlyTransactions,
        SUM(WeeklyQuantity) AS MonthlyQuantity,
        ROUND(SUM(WeeklySales), 2) AS MonthlySales,
        ROUND(SUM(WeeklyTax), 2) AS MonthlyTax
    FROM WeeklyCategorySales
    GROUP BY Year, Month, CategoryName
)
SELECT 
    w.Year,
    w.Month,
    w.MonthName,
    w.WeekOfYear,
    w.CategoryName,
    w.WeeklyTransactions,
    w.WeeklyQuantity,
    w.WeeklySales,
    w.WeeklyTax,
    m.MonthlyTransactions,
    m.MonthlyQuantity,
    m.MonthlySales,
    m.MonthlyTax,
    -- Calculate weekly contribution to monthly total
    ROUND(
        (w.WeeklySales / NULLIF(m.MonthlySales, 0)) * 100, 2
    ) AS WeeklyContributionPercent,
    -- Calculate running total within month
    ROUND(
        SUM(w.WeeklySales) OVER (
            PARTITION BY w.Year, w.Month, w.CategoryName 
            ORDER BY w.WeekOfYear
        ), 2
    ) AS RunningMonthlySales
FROM WeeklyCategorySales w
INNER JOIN MonthlyTotals m ON w.Year = m.Year 
    AND w.Month = m.Month 
    AND w.CategoryName = m.CategoryName
ORDER BY w.Year, w.Month, w.WeekOfYear, w.WeeklySales DESC;

-- =====================================================
-- REPORT 6: Median Sales Value by Product Category and Country
-- Purpose: Advanced statistical analysis using percentile functions
-- =====================================================

WITH MonthlySalesAggregated AS (
    SELECT 
        c.CategoryName,
        cust.Country,
        EXTRACT(YEAR FROM d.Date) AS Year,
        EXTRACT(MONTH FROM d.Date) AS Month,
        ROUND(SUM(fs.TotalAmount), 2) AS MonthlySales
    FROM FactSales fs
    INNER JOIN DimProduct p ON fs.ProductID = p.ProductID
    INNER JOIN DimCategory c ON p.CategoryID = c.CategoryID
    INNER JOIN DimCustomer cust ON fs.CustomerID = cust.CustomerID
    INNER JOIN DimDate d ON fs.DateID = d.DateID
    GROUP BY c.CategoryName, cust.Country, Year, Month
    HAVING SUM(fs.TotalAmount) > 0 -- Exclude zero sales months
),
MedianCalculations AS (
    SELECT 
        CategoryName,
        Country,
        COUNT(*) AS MonthlyPeriods,
        ROUND(MIN(MonthlySales), 2) AS MinMonthlySales,
        ROUND(MAX(MonthlySales), 2) AS MaxMonthlySales,
        ROUND(AVG(MonthlySales), 2) AS AvgMonthlySales,
        ROUND(
            PERCENTILE_CONT(0.5) WITHIN GROUP (
                ORDER BY MonthlySales
            ), 2
        ) AS MedianSales,
        ROUND(
            PERCENTILE_CONT(0.25) WITHIN GROUP (
                ORDER BY MonthlySales
            ), 2
        ) AS FirstQuartile,
        ROUND(
            PERCENTILE_CONT(0.75) WITHIN GROUP (
                ORDER BY MonthlySales
            ), 2
        ) AS ThirdQuartile
    FROM MonthlySalesAggregated
    GROUP BY CategoryName, Country
)
SELECT 
    CategoryName,
    Country,
    MonthlyPeriods,
    MinMonthlySales,
    MaxMonthlySales,
    AvgMonthlySales,
    MedianSales,
    FirstQuartile,
    ThirdQuartile,
    -- Calculate interquartile range for outlier detection
    ROUND(ThirdQuartile - FirstQuartile, 2) AS InterQuartileRange,
    -- Identify if average is significantly different from median (skewness indicator)
    CASE 
        WHEN ABS(AvgMonthlySales - MedianSales) > (0.1 * MedianSales) THEN 'Skewed'
        ELSE 'Symmetric'
    END AS DistributionType
FROM MedianCalculations
WHERE MonthlyPeriods >= 3 -- Ensure sufficient data points
ORDER BY CategoryName, MedianSales DESC;

-- =====================================================
-- REPORT 7: Sales Ranking by Product Categories
-- Purpose: Category performance ranking with advanced analytics
-- =====================================================

WITH CategorySales AS (
    SELECT 
        c.CategoryID,
        c.CategoryName,
        COUNT(fs.SalesID) AS TotalTransactions,
        SUM(fs.QuantitySold) AS TotalQuantitySold,
        ROUND(SUM(fs.TotalAmount), 2) AS TotalSalesAmount,
        ROUND(SUM(fs.TaxAmount), 2) AS TotalTaxAmount,
        COUNT(DISTINCT fs.CustomerID) AS UniqueCustomers,
        COUNT(DISTINCT fs.ProductID) AS UniqueProducts,
        ROUND(AVG(fs.TotalAmount), 2) AS AvgTransactionValue
    FROM FactSales fs
    INNER JOIN DimProduct p ON fs.ProductID = p.ProductID
    INNER JOIN DimCategory c ON p.CategoryID = c.CategoryID
    GROUP BY c.CategoryID, c.CategoryName
),
RankedCategories AS (
    SELECT *,
        -- Rank by total sales amount
        RANK() OVER (ORDER BY TotalSalesAmount DESC) AS SalesRank,
        -- Rank by transaction count
        RANK() OVER (ORDER BY TotalTransactions DESC) AS TransactionRank,
        -- Rank by unique customers
        RANK() OVER (ORDER BY UniqueCustomers DESC) AS CustomerRank,
        -- Calculate category performance score (composite metric)
        ROUND(
            (SalesRank * 0.5 + TransactionRank * 0.3 + CustomerRank * 0.2) / 3, 2
        ) AS PerformanceScore
    FROM CategorySales
)
SELECT 
    CategoryName,
    TotalTransactions,
    TotalQuantitySold,
    TotalSalesAmount,
    TotalTaxAmount,
    UniqueCustomers,
    UniqueProducts,
    AvgTransactionValue,
    SalesRank,
    TransactionRank,
    CustomerRank,
    PerformanceScore,
    CASE 
        WHEN SalesRank = 1 THEN 'Top Seller'
        WHEN SalesRank <= 3 THEN 'High Performer'
        WHEN SalesRank <= 5 THEN 'Medium Performer'
        ELSE 'Low Performer'
    END AS PerformanceCategory,
    -- Calculate market share
    ROUND(
        (TotalSalesAmount / SUM(TotalSalesAmount) OVER ()) * 100, 2
    ) AS MarketSharePercent
FROM RankedCategories
ORDER BY SalesRank;

-- =====================================================
-- ADDITIONAL ENHANCED REPORT: Customer Segmentation Analysis
-- Bonus report demonstrating advanced analytical capabilities
-- =====================================================

WITH CustomerRFM AS (
    SELECT 
        c.CustomerID,
        c.CompanyName,
        c.Country,
        -- Recency: Days since last purchase
        EXTRACT(DAY FROM (CURRENT_DATE - MAX(d.Date))) AS Recency,
        -- Frequency: Number of transactions
        COUNT(fs.SalesID) AS Frequency,
        -- Monetary: Total spending
        ROUND(SUM(fs.TotalAmount), 2) AS Monetary
    FROM FactSales fs
    INNER JOIN DimCustomer c ON fs.CustomerID = c.CustomerID
    INNER JOIN DimDate d ON fs.DateID = d.DateID
    GROUP BY c.CustomerID, c.CompanyName, c.Country
),
RFMScores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY Recency DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary) AS M_Score
    FROM CustomerRFM
)
SELECT 
    CustomerID,
    CompanyName,
    Country,
    Recency,
    Frequency,
    Monetary,
    R_Score,
    F_Score,
    M_Score,
    (R_Score + F_Score + M_Score) AS RFM_Total,
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
        WHEN R_Score >= 3 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
        WHEN R_Score >= 2 AND F_Score >= 2 THEN 'Potential Loyalists'
        WHEN R_Score >= 3 AND F_Score <= 2 THEN 'New Customers'
        WHEN R_Score <= 2 AND F_Score >= 3 THEN 'At Risk'
        ELSE 'Lost Customers'
    END AS CustomerSegment
FROM RFMScores
ORDER BY RFM_Total DESC;

-- =====================================================
-- BUSINESS REPORTS COMPLETED
-- =====================================================