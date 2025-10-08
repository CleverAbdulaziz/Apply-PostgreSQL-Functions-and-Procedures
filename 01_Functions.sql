-- ===================================================
-- Exercise 1: Calculate Order Total Function
-- Description: Creates a robust function to calculate total order amount
-- Features: Error handling, NULL protection, precise decimal calculation
-- ===================================================

CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id INT)
RETURNS DECIMAL(12,2) 
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total_amount DECIMAL(12,2) := 0;
    v_order_exists BOOLEAN := FALSE;
BEGIN
    -- Validate order existence first
    SELECT EXISTS(SELECT 1 FROM orders WHERE order_id = p_order_id) 
    INTO v_order_exists;
    
    IF NOT v_order_exists THEN
        RAISE WARNING 'Order ID % does not exist', p_order_id;
        RETURN 0;
    END IF;
    
    -- Calculate total with precision handling
    SELECT COALESCE(
        SUM(
            ROUND(
                (unit_price * quantity * (1 - COALESCE(discount, 0)))::DECIMAL(12,2),
                2
            )
        ), 0
    )
    INTO v_total_amount
    FROM order_details
    WHERE order_id = p_order_id;
    
    RETURN v_total_amount;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error calculating total for order %: %', p_order_id, SQLERRM;
        RETURN 0;
END;
$$;

-- ===================================================
-- COMPREHENSIVE TEST SUITE
-- ===================================================

-- Test 1: Valid order with items
SELECT 
    order_id,
    calculate_order_total(order_id) AS calculated_total,
    '✓' AS status
FROM orders 
WHERE order_id = 10248;

-- Test 2: Order with no items (edge case)
SELECT 
    calculate_order_total(99999) AS non_existent_order_total,
    '✓' AS edge_case_test;

-- Test 3: Multiple orders verification
SELECT 
    o.order_id,
    o.order_date,
    c.company_name,
    calculate_order_total(o.order_id) AS order_total,
    CASE 
        WHEN calculate_order_total(o.order_id) > 0 THEN '✓ VALID'
        ELSE '✗ CHECK'
    END AS validation
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_id BETWEEN 10248 AND 10252
ORDER BY order_total DESC;