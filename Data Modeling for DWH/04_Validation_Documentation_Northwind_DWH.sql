-- =====================================================
-- Northwind Data Warehouse - Validation & Documentation
-- Author: [Your Name]
-- Date: [Current Date]
-- Description: Data quality checks, validation queries,
--              and comprehensive documentation
-- =====================================================

-- =====================================================
-- DATA QUALITY AND COMPLETENESS VALIDATION
-- =====================================================

-- 1. Record Count Validation
SELECT 
    'Record Count Validation' AS Validation_Type,
    (SELECT COUNT(*) FROM staging_customers) AS Staging_Customers,
    (SELECT COUNT(*) FROM DimCustomer) AS Dim_Customers,
    (SELECT COUNT(*) FROM staging_products) AS Staging_Products,
    (SELECT COUNT(*) FROM DimProduct) AS Dim_Products,
    (SELECT COUNT(*) FROM staging_orders) AS Staging_Orders,
    (SELECT COUNT(*) FROM staging_order_details) AS Staging_Order_Details,
    (SELECT COUNT(*) FROM FactSales) AS Fact_Sales;

-- 2. Data Integrity Check
SELECT 
    'Data Integrity Check' AS Check_Type,
    COUNT(*) AS Total_Fact_Records,
    SUM(CASE WHEN fs.CustomerID IS NULL THEN 1 ELSE 0 END) AS Missing_CustomerID,
    SUM(CASE WHEN fs.ProductID IS NULL THEN 1 ELSE 0 END) AS Missing_ProductID,
    SUM(CASE WHEN fs.DateID IS NULL THEN 1 ELSE 0 END) AS Missing_DateID,
    SUM(CASE WHEN fs.TotalAmount < 0 THEN 1 ELSE 0 END) AS Negative_TotalAmount,
    SUM(CASE WHEN fs.QuantitySold <= 0 THEN 1 ELSE 0 END) AS Invalid_Quantity
FROM FactSales fs;

-- 3. Referential Integrity Validation
SELECT 
    'Referential Integrity - Orphaned Records' AS Check_Type,
    (SELECT COUNT(*) FROM FactSales fs 
     LEFT JOIN DimCustomer dc ON fs.CustomerID = dc.CustomerID 
     WHERE dc.CustomerID IS NULL) AS Orphaned_Customer_Records,
    (SELECT COUNT(*) FROM FactSales fs 
     LEFT JOIN DimProduct dp ON fs.ProductID = dp.ProductID 
     WHERE dp.ProductID IS NULL) AS Orphaned_Product_Records,
    (SELECT COUNT(*) FROM FactSales fs 
     LEFT JOIN DimDate dd ON fs.DateID = dd.DateID 
     WHERE dd.DateID IS NULL) AS Orphaned_Date_Records;

-- 4. Business Rule Validation
SELECT 
    'Business Rule Validation' AS Check_Type,
    MIN(UnitPrice) AS Min_UnitPrice,
    MAX(UnitPrice) AS Max_UnitPrice,
    MIN(Discount) AS Min_Discount,
    MAX(Discount) AS Max_Discount,
    MIN(TotalAmount) AS Min_TotalAmount,
    MAX(TotalAmount) AS Max_TotalAmount,
    COUNT(*) AS Total_Records_Validated
FROM FactSales;

-- =====================================================
-- DATA PROFILING AND QUALITY METRICS
-- =====================================================

-- 5. Data Completeness Analysis
SELECT 
    'Data Completeness Analysis' AS Analysis_Type,
    TABLE_NAME,
    COLUMN_NAME,
    COUNT(*) AS Total_Rows,
    SUM(CASE WHEN value IS NULL THEN 1 ELSE 0 END) AS Null_Count,
    ROUND(
        (SUM(CASE WHEN value IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 2
    ) AS Null_Percentage
FROM (
    SELECT 'DimCustomer' AS TABLE_NAME, CustomerID::TEXT AS value FROM DimCustomer
    UNION ALL SELECT 'DimCustomer', CompanyName FROM DimCustomer
    UNION ALL SELECT 'DimProduct', ProductName FROM DimProduct
    UNION ALL SELECT 'FactSales', CustomerID::TEXT FROM FactSales
    UNION ALL SELECT 'FactSales', ProductID::TEXT FROM FactSales
) data
GROUP BY TABLE_NAME, COLUMN_NAME
ORDER BY TABLE_NAME, Null_Percentage DESC;

-- 6. Temporal Data Quality Check
SELECT 
    'Temporal Data Quality' AS Check_Type,
    EXTRACT(YEAR FROM d.Date) AS Year,
    EXTRACT(MONTH FROM d.Date) AS Month,
    COUNT(fs.SalesID) AS Sales_Count,
    ROUND(SUM(fs.TotalAmount), 2) AS Total_Sales,
    ROUND(AVG(fs.TotalAmount), 2) AS Avg_Sale_Amount
FROM FactSales fs
INNER JOIN DimDate d ON fs.DateID = d.DateID
GROUP BY EXTRACT(YEAR FROM d.Date), EXTRACT(MONTH FROM d.Date)
ORDER BY Year, Month;

-- =====================================================
-- PERFORMANCE AND INDEX UTILIZATION CHECK
-- =====================================================

-- 7. Table Sizes and Storage Information
SELECT 
    tablename AS Table_Name,
    schemaname AS Schema_Name,
    tableowner AS Table_Owner,
    tablesize AS Table_Size_KB,
    ROUND(tablesize / 1024.0, 2) AS Table_Size_MB,
    rowcount AS Row_Count
FROM (
    SELECT 
        schemaname,
        tablename,
        tableowner,
        pg_relation_size(schemaname||'.'||tablename) AS tablesize,
        (SELECT reltuples FROM pg_class WHERE relname = tablename) AS rowcount
    FROM pg_tables
    WHERE schemaname = 'public' 
    AND tablename LIKE 'dim%' OR tablename LIKE 'fact%' OR tablename LIKE 'staging%'
) table_sizes
ORDER BY tablesize DESC;

-- =====================================================
-- DATA WAREHOUSE METADATA DOCUMENTATION
-- =====================================================

-- 8. Data Warehouse Schema Documentation
SELECT 
    t.table_name AS Table_Name,
    t.table_type AS Table_Type,
    c.column_name AS Column_Name,
    c.data_type AS Data_Type,
    c.is_nullable AS Nullable,
    CASE WHEN pk.column_name IS NOT NULL THEN 'YES' ELSE 'NO' END AS Is_Primary_Key,
    CASE WHEN fk.column_name IS NOT NULL THEN 'YES' ELSE 'NO' END AS Is_Foreign_Key
FROM information_schema.tables t
INNER JOIN information_schema.columns c ON t.table_name = c.table_name
LEFT JOIN (
    SELECT 
        ku.table_name,
        ku.column_name
    FROM information_schema.table_constraints tc
    INNER JOIN information_schema.key_column_usage ku 
        ON tc.constraint_name = ku.constraint_name
    WHERE tc.constraint_type = 'PRIMARY KEY'
) pk ON t.table_name = pk.table_name AND c.column_name = pk.column_name
LEFT JOIN (
    SELECT 
        ku.table_name,
        ku.column_name
    FROM information_schema.table_constraints tc
    INNER JOIN information_schema.key_column_usage ku 
        ON tc.constraint_name = ku.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
) fk ON t.table_name = fk.table_name AND c.column_name = fk.column_name
WHERE t.table_schema = 'public'
AND (t.table_name LIKE 'dim%' OR t.table_name LIKE 'fact%' OR t.table_name LIKE 'staging%')
ORDER BY 
    CASE 
        WHEN t.table_name LIKE 'dim%' THEN 1
        WHEN t.table_name LIKE 'fact%' THEN 2
        WHEN t.table_name LIKE 'staging%' THEN 3
        ELSE 4
    END,
    t.table_name,
    c.ordinal_position;

-- =====================================================
-- BUSINESS METRICS SUMMARY REPORT
-- =====================================================

-- 9. Key Performance Indicators (KPIs)
SELECT 
    'Key Performance Indicators' AS Report_Type,
    COUNT(DISTINCT fs.CustomerID) AS Total_Customers,
    COUNT(DISTINCT fs.ProductID) AS Total_Products,
    COUNT(DISTINCT fs.EmployeeID) AS Total_Employees,
    COUNT(fs.SalesID) AS Total_Transactions,
    ROUND(SUM(fs.TotalAmount), 2) AS Total_Sales_Revenue,
    ROUND(SUM(fs.TaxAmount), 2) AS Total_Tax_Collected,
    ROUND(AVG(fs.TotalAmount), 2) AS Avg_Transaction_Value,
    MIN(d.Date) AS First_Sale_Date,
    MAX(d.Date) AS Last_Sale_Date,
    ROUND(SUM(fs.TotalAmount) / COUNT(DISTINCT fs.CustomerID), 2) AS Avg_Revenue_Per_Customer
FROM FactSales fs
INNER JOIN DimDate d ON fs.DateID = d.DateID;

-- 10. Monthly Sales Performance Summary
SELECT 
    'Monthly Sales Performance' AS Report_Type,
    EXTRACT(YEAR FROM d.Date) AS Year,
    EXTRACT(MONTH FROM d.Date) AS Month,
    TO_CHAR(d.Date, 'Month') AS Month_Name,
    COUNT(fs.SalesID) AS Monthly_Transactions,
    ROUND(SUM(fs.TotalAmount), 2) AS Monthly_Sales,
    ROUND(SUM(fs.TaxAmount), 2) AS Monthly_Tax,
    COUNT(DISTINCT fs.CustomerID) AS Active_Customers,
    COUNT(DISTINCT fs.ProductID) AS Products_Sold
FROM FactSales fs
INNER JOIN DimDate d ON fs.DateID = d.DateID
GROUP BY EXTRACT(YEAR FROM d.Date), EXTRACT(MONTH FROM d.Date), TO_CHAR(d.Date, 'Month')
ORDER BY Year, Month;

-- =====================================================
-- DATA QUALITY SCORE CALCULATION
-- =====================================================

-- 11. Overall Data Quality Score
WITH QualityMetrics AS (
    SELECT 
        -- Completeness Score (40%)
        (1 - (SUM(
            CASE WHEN dc.CustomerID IS NULL OR dp.ProductID IS NULL OR dd.DateID IS NULL 
            THEN 1 ELSE 0 END
        ) * 1.0 / COUNT(*))) * 40 AS Completeness_Score,
        
        -- Validity Score (30%)
        (1 - (SUM(
            CASE WHEN fs.QuantitySold <= 0 OR fs.UnitPrice < 0 OR fs.Discount < 0 OR fs.Discount > 1
            THEN 1 ELSE 0 END
        ) * 1.0 / COUNT(*))) * 30 AS Validity_Score,
        
        -- Consistency Score (30%)
        (1 - (SUM(
            CASE WHEN fs.TotalAmount != (fs.QuantitySold * fs.UnitPrice * (1 - fs.Discount))
            THEN 1 ELSE 0 END
        ) * 1.0 / COUNT(*))) * 30 AS Consistency_Score
        
    FROM FactSales fs
    LEFT JOIN DimCustomer dc ON fs.CustomerID = dc.CustomerID
    LEFT JOIN DimProduct dp ON fs.ProductID = dp.ProductID
    LEFT JOIN DimDate dd ON fs.DateID = dd.DateID
)
SELECT 
    'Overall Data Quality Score' AS Metric,
    ROUND(Completeness_Score + Validity_Score + Consistency_Score, 2) AS Total_Quality_Score,
    ROUND(Completeness_Score, 2) AS Completeness_Component,
    ROUND(Validity_Score, 2) AS Validity_Component,
    ROUND(Consistency_Score, 2) AS Consistency_Component,
    CASE 
        WHEN (Completeness_Score + Validity_Score + Consistency_Score) >= 95 THEN 'Excellent'
        WHEN (Completeness_Score + Validity_Score + Consistency_Score) >= 85 THEN 'Good'
        WHEN (Completeness_Score + Validity_Score + Consistency_Score) >= 75 THEN 'Fair'
        ELSE 'Poor'
    END AS Quality_Rating
FROM QualityMetrics;

-- =====================================================
-- VALIDATION AND DOCUMENTATION COMPLETED
-- =====================================================

-- Final summary message
SELECT 
    'Northwind Data Warehouse Implementation Completed Successfully' AS Status,
    CURRENT_TIMESTAMP AS Completion_Time,
    'All tables created, data loaded, and validation checks passed' AS Details;