-- =============================================
-- FACT TABLES CREATION SCRIPT
-- Purpose: Create all fact tables for the data warehouse
-- =============================================

-- Main Sales Fact Table
CREATE TABLE IF NOT EXISTS FactSales (
    FactSalesID SERIAL PRIMARY KEY,
    DateID INT NOT NULL,
    CustomerID VARCHAR(5) NOT NULL,
    ProductID INT NOT NULL,
    EmployeeID INT NOT NULL,
    CategoryID INT NOT NULL,
    ShipperID INT NOT NULL,
    SupplierID INT NOT NULL,
    OrderID INT NOT NULL,
    QuantitySold INT NOT NULL CHECK (QuantitySold > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    Discount DECIMAL(3,2) NOT NULL CHECK (Discount BETWEEN 0 AND 1),
    LineTotal DECIMAL(15,2) NOT NULL CHECK (LineTotal >= 0),
    TaxAmount DECIMAL(15,2) NOT NULL CHECK (TaxAmount >= 0),
    FreightCost DECIMAL(10,2) NOT NULL CHECK (FreightCost >= 0),
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID),
    FOREIGN KEY (CustomerID) REFERENCES DimCustomer(CustomerID),
    FOREIGN KEY (ProductID) REFERENCES DimProduct(ProductID),
    FOREIGN KEY (EmployeeID) REFERENCES DimEmployee(EmployeeID),
    FOREIGN KEY (CategoryID) REFERENCES DimCategory(CategoryID),
    FOREIGN KEY (ShipperID) REFERENCES DimShipper(ShipperID),
    FOREIGN KEY (SupplierID) REFERENCES DimSupplier(SupplierID)
);

-- Supplier Purchases Fact Table
CREATE TABLE IF NOT EXISTS FactSupplierPurchases (
    PurchaseID SERIAL PRIMARY KEY,
    SupplierID INT NOT NULL,
    DateID INT NOT NULL,
    TotalPurchaseAmount DECIMAL(15,2) NOT NULL CHECK (TotalPurchaseAmount >= 0),
    NumberOfProducts INT NOT NULL CHECK (NumberOfProducts > 0),
    AverageUnitPrice DECIMAL(10,2) NOT NULL CHECK (AverageUnitPrice >= 0),
    TotalQuantity INT NOT NULL CHECK (TotalQuantity > 0),
    FOREIGN KEY (SupplierID) REFERENCES DimSupplier(SupplierID),
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID)
);

-- Product Sales Fact Table
CREATE TABLE IF NOT EXISTS FactProductSales (
    FactProductSalesID SERIAL PRIMARY KEY,
    DateID INT NOT NULL,
    ProductID INT NOT NULL,
    CategoryID INT NOT NULL,
    SupplierID INT NOT NULL,
    QuantitySold INT NOT NULL CHECK (QuantitySold > 0),
    TotalSales DECIMAL(15,2) NOT NULL CHECK (TotalSales >= 0),
    AverageUnitPrice DECIMAL(10,2) NOT NULL CHECK (AverageUnitPrice >= 0),
    NumberOfOrders INT NOT NULL CHECK (NumberOfOrders > 0),
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID),
    FOREIGN KEY (ProductID) REFERENCES DimProduct(ProductID),
    FOREIGN KEY (CategoryID) REFERENCES DimCategory(CategoryID),
    FOREIGN KEY (SupplierID) REFERENCES DimSupplier(SupplierID)
);

-- Customer Sales Fact Table
CREATE TABLE IF NOT EXISTS FactCustomerSales (
    FactCustomerSalesID SERIAL PRIMARY KEY,
    DateID INT NOT NULL,
    CustomerID VARCHAR(5) NOT NULL,
    TotalAmount DECIMAL(15,2) NOT NULL CHECK (TotalAmount >= 0),
    TotalQuantity INT NOT NULL CHECK (TotalQuantity > 0),
    NumberOfTransactions INT NOT NULL CHECK (NumberOfTransactions > 0),
    AverageTransactionValue DECIMAL(15,2) NOT NULL CHECK (AverageTransactionValue >= 0),
    DaysSinceFirstPurchase INT NOT NULL CHECK (DaysSinceFirstPurchase >= 0),
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID),
    FOREIGN KEY (CustomerID) REFERENCES DimCustomer(CustomerID)
);

-- Inventory Fact Table
CREATE TABLE IF NOT EXISTS FactInventory (
    InventoryID SERIAL PRIMARY KEY,
    DateID INT NOT NULL,
    ProductID INT NOT NULL,
    UnitsInStock INT NOT NULL CHECK (UnitsInStock >= 0),
    UnitsOnOrder INT NOT NULL CHECK (UnitsOnOrder >= 0),
    ReorderLevel INT NOT NULL CHECK (ReorderLevel >= 0),
    StockValue DECIMAL(15,2) NOT NULL CHECK (StockValue >= 0),
    IsBelowReorderLevel BOOLEAN NOT NULL,
    DaysOfSupply INT,
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID),
    FOREIGN KEY (ProductID) REFERENCES DimProduct(ProductID)
);

-- Create indexes for optimal query performance
CREATE INDEX IF NOT EXISTS idx_factsales_date ON FactSales(DateID);
CREATE INDEX IF NOT EXISTS idx_factsales_customer ON FactSales(CustomerID);
CREATE INDEX IF NOT EXISTS idx_factsales_product ON FactSales(ProductID);
CREATE INDEX IF NOT EXISTS idx_factsales_employee ON FactSales(EmployeeID);
CREATE INDEX IF NOT EXISTS idx_factsales_category ON FactSales(CategoryID);
CREATE INDEX IF NOT EXISTS idx_factsales_supplier ON FactSales(SupplierID);
CREATE INDEX IF NOT EXISTS idx_factsales_order ON FactSales(OrderID);

CREATE INDEX IF NOT EXISTS idx_factsupplierpurchases_supplier ON FactSupplierPurchases(SupplierID);
CREATE INDEX IF NOT EXISTS idx_factsupplierpurchases_date ON FactSupplierPurchases(DateID);

CREATE INDEX IF NOT EXISTS idx_factproductsales_product ON FactProductSales(ProductID);
CREATE INDEX IF NOT EXISTS idx_factproductsales_date ON FactProductSales(DateID);

CREATE INDEX IF NOT EXISTS idx_factcustomersales_customer ON FactCustomerSales(CustomerID);
CREATE INDEX IF NOT EXISTS idx_factcustomersales_date ON FactCustomerSales(DateID);

CREATE INDEX IF NOT EXISTS idx_factinventory_product ON FactInventory(ProductID);
CREATE INDEX IF NOT EXISTS idx_factinventory_date ON FactInventory(DateID);

-- Comments for documentation
COMMENT ON TABLE FactSales IS 'Main sales fact table with granular transaction data for comprehensive analysis';
COMMENT ON TABLE FactSupplierPurchases IS 'Supplier performance fact table for procurement analysis';
COMMENT ON TABLE FactProductSales IS 'Product performance fact table for sales and inventory analysis';
COMMENT ON TABLE FactCustomerSales IS 'Customer behavior fact table for segmentation and CLV analysis';
COMMENT ON TABLE FactInventory IS 'Inventory tracking fact table for stock level and valuation analysis';