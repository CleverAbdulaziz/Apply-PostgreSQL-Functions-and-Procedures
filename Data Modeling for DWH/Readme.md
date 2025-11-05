File Descriptions
1. 01_Table_Creation_Northwind_DWH.sql
   Creates all staging tables for raw data extraction

Implements dimension tables (Date, Customer, Product, Employee, Category, Shipper, Supplier)

Builds the central FactSales fact table

Adds performance-optimized indexes

Includes comprehensive constraints for data integrity

2. 02_Data_Loading_Northwind_DWH.sql
   Extracts data from source tables to staging area

Populates Date dimension with comprehensive date ranges

Transforms and loads data into dimension tables with data quality checks

Loads fact table with calculated measures and business logic

Includes comprehensive data validation and integrity checks

3. 03_Business_Reports_Northwind_DWH.sql
   7 Core Business Reports as specified in requirements

Bonus Reports demonstrating advanced analytics

Includes RFM customer segmentation

Advanced statistical analysis using window functions

Growth calculations and trend analysis

4. 04_Validation_Documentation_Northwind_DWH.sql
   Comprehensive data quality validation

Referential integrity checks

Business rule validation

Data profiling and completeness analysis

Performance metrics and documentation

🎯 Business Reports Implemented
1. Sales Trends per Product Category Monthly
   Analyzes Q1 sales performance by category

Shows average sales, quantities, and transaction counts

Includes month-over-month growth calculations

2. Top Products by Transactions and Sales Monthly
   Identifies top 5 products by transactions and sales

Includes category information and performance rankings

Composite performance scoring

3. Top Five Customers by Transactions and Purchases
   Ranks customers by transaction frequency and spending

Includes customer value scoring

Geographic and behavioral analysis

4. Sales Chart for First Week of Each Month
   Analyzes sales performance in initial weeks

Year-over-year growth comparisons

Trend analysis and performance categorization

5. Weekly Sales Report by Product Categories
   Detailed weekly breakdowns with monthly rollups

Running totals and contribution percentages

Comprehensive period analysis

6. Median Sales Value by Product Category and Country
   Advanced statistical analysis using PERCENTILE_CONT

Distribution analysis and outlier detection

Geographic performance insights

7. Sales Ranking by Product Categories
   Comprehensive category performance ranking

Market share calculations

Multi-dimensional performance scoring