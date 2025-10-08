-- ===================================================
-- Exercise 2: Stock Update Procedure
-- Description: Advanced stock management with validation and audit trail
-- Features: Input validation, transaction safety, comprehensive logging
-- ===================================================

CREATE OR REPLACE PROCEDURE update_stock(
    p_product_id INT, 
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_stock INT;
    v_product_name VARCHAR(100);
    v_updated_stock INT;
    v_operation_type TEXT;
BEGIN
    -- Input validation
    IF p_quantity = 0 THEN
        RAISE NOTICE 'Quantity change is zero - no operation performed for product ID %', p_product_id;
        RETURN;
    END IF;
    
    -- Get current product information
    SELECT product_name, units_in_stock 
    INTO v_product_name, v_current_stock
    FROM products 
    WHERE product_id = p_product_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product with ID % not found in inventory', p_product_id;
    END IF;
    
    -- Determine operation type for logging
    v_operation_type := CASE 
        WHEN p_quantity > 0 THEN 'STOCK_ADDITION'
        ELSE 'STOCK_REDUCTION'
    END;
    
    -- Perform stock update with bounds checking
    UPDATE products 
    SET units_in_stock = GREATEST(0, units_in_stock + p_quantity) -- Prevent negative stock
    WHERE product_id = p_product_id
    RETURNING units_in_stock INTO v_updated_stock;
    
    -- Comprehensive success logging
    RAISE NOTICE 'SUCCESS: Product "%" (ID: %) stock updated: % → % [Operation: %]',
        v_product_name,
        p_product_id,
        v_current_stock,
        v_updated_stock,
        v_operation_type;
        
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to update stock for product ID %: %', p_product_id, SQLERRM;
END;
$$;

-- ===================================================
-- COMPREHENSIVE TESTING PROCEDURE
-- ===================================================

-- Test 1: Initial state check
SELECT 
    product_id,
    product_name,
    units_in_stock AS current_stock,
    'Baseline' AS note
FROM products 
WHERE product_id = 11;

-- Test 2: Positive stock addition
CALL update_stock(11, 25);

-- Test 3: Stock reduction (valid)
CALL update_stock(11, -10);

-- Test 4: Edge case - zero quantity
CALL update_stock(11, 0);

-- Test 5: Final verification with enhanced details
SELECT 
    p.product_id,
    p.product_name,
    p.units_in_stock AS final_stock,
    p.reorder_level,
    CASE 
        WHEN p.units_in_stock <= p.reorder_level THEN '⚠ REORDER NEEDED'
        ELSE '✓ STOCK OK'
    END AS stock_status,
    p.unit_price,
    (p.units_in_stock * p.unit_price) AS stock_value
FROM products p
WHERE p.product_id = 11;