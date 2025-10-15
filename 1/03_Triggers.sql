-- ===================================================
-- Exercise 3: Price Update Audit Trigger System
-- Description: Comprehensive price change tracking with advanced features
-- Features: Change detection, user context, price history analysis
-- ===================================================

-- Advanced audit table with enhanced tracking
CREATE TABLE IF NOT EXISTS price_update_log (
    log_id BIGSERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    category_id INT,
    old_price DECIMAL(10,2) NOT NULL,
    new_price DECIMAL(10,2) NOT NULL,
    price_change DECIMAL(10,2) GENERATED ALWAYS AS (new_price - old_price) STORED,
    change_percentage DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN old_price > 0 THEN ROUND(((new_price - old_price) / old_price * 100)::NUMERIC, 2)
            ELSE NULL 
        END
    ) STORED,
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('INSERT', 'UPDATE', 'DELETE')),
    updated_by VARCHAR(100) DEFAULT CURRENT_USER,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    session_info JSONB DEFAULT NULL,
    
    CONSTRAINT valid_price_change CHECK (new_price >= 0 AND old_price >= 0),
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_price_log_product ON price_update_log(product_id);
CREATE INDEX IF NOT EXISTS idx_price_log_timestamp ON price_update_log(updated_at DESC);

-- Advanced trigger function with comprehensive logging
CREATE OR REPLACE FUNCTION log_price_changes()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_name VARCHAR(100);
    v_category_id INT;
BEGIN
    -- Determine operation type and handle accordingly
    CASE TG_OP
        WHEN 'INSERT' THEN
            -- Log initial price setting for new products
            INSERT INTO price_update_log (
                product_id, product_name, category_id,
                old_price, new_price, operation_type,
                session_info
            ) VALUES (
                NEW.product_id, NEW.product_name, NEW.category_id,
                0, COALESCE(NEW.unit_price, 0), 'INSERT',
                jsonb_build_object(
                    'action', 'initial_price_set',
                    'session_user', session_user,
                    'current_time', CURRENT_TIMESTAMP
                )
            );
            
        WHEN 'UPDATE' THEN
            -- Only log if price actually changed and is significant
            IF OLD.unit_price IS DISTINCT FROM NEW.unit_price AND
               ABS(COALESCE(OLD.unit_price, 0) - COALESCE(NEW.unit_price, 0)) > 0.001 THEN
               
                INSERT INTO price_update_log (
                    product_id, product_name, category_id,
                    old_price, new_price, operation_type,
                    session_info
                ) VALUES (
                    OLD.product_id, OLD.product_name, OLD.category_id,
                    COALESCE(OLD.unit_price, 0), COALESCE(NEW.unit_price, 0), 'UPDATE',
                    jsonb_build_object(
                        'action', 'price_adjustment',
                        'price_difference', (NEW.unit_price - OLD.unit_price),
                        'session_user', session_user
                    )
                );
            END IF;
            
        WHEN 'DELETE' THEN
            -- Log product deletion with price information
            INSERT INTO price_update_log (
                product_id, product_name, category_id,
                old_price, new_price, operation_type,
                session_info
            ) VALUES (
                OLD.product_id, OLD.product_name, OLD.category_id,
                COALESCE(OLD.unit_price, 0), 0, 'DELETE',
                jsonb_build_object(
                    'action', 'product_removal',
                    'session_user', session_user
                )
            );
    END CASE;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Create sophisticated trigger
DROP TRIGGER IF EXISTS trg_price_audit ON products CASCADE;
CREATE TRIGGER trg_price_audit
    AFTER INSERT OR UPDATE OF unit_price OR DELETE ON products
    FOR EACH ROW
    EXECUTE FUNCTION log_price_changes();

-- ===================================================
-- COMPREHENSIVE TRIGGER TESTING
-- ===================================================

-- Test 1: Check initial audit log state
SELECT 
    COUNT(*) AS existing_logs,
    'Pre-test baseline' AS note
FROM price_update_log 
WHERE product_id = 11;

-- Test 2: Price update with significant change
UPDATE products 
SET unit_price = unit_price * 1.15  -- 15% increase
WHERE product_id = 11;

-- Test 3: Minor price adjustment (should still log)
UPDATE products 
SET unit_price = unit_price + 0.50
WHERE product_id = 11;

-- Test 4: Verify trigger logging results
SELECT 
    log_id,
    product_id,
    product_name,
    old_price,
    new_price,
    price_change,
    change_percentage || '%' AS change_pct,
    operation_type,
    updated_by,
    TO_CHAR(updated_at, 'YYYY-MM-DD HH24:MI:SS') AS updated_time,
    session_info->>'action' as audit_action
FROM price_update_log 
WHERE product_id = 11
ORDER BY log_id DESC;

-- Test 5: Price change analysis report
SELECT 
    product_id,
    product_name,
    COUNT(*) AS change_count,
    MIN(old_price) AS min_old_price,
    MAX(new_price) AS max_new_price,
    SUM(price_change) AS total_change,
    AVG(change_percentage) AS avg_change_pct,
    TO_CHAR(MIN(updated_at), 'YYYY-MM-DD') AS first_change,
    TO_CHAR(MAX(updated_at), 'YYYY-MM-DD') AS last_change
FROM price_update_log 
WHERE product_id = 11
GROUP BY product_id, product_name;