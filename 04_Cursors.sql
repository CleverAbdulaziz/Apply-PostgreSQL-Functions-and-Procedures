-- ===================================================
-- Exercise 4: Advanced Cursor Processing System
-- Description: Sophisticated order processing with multiple cursor strategies
-- Features: Multiple cursor types, performance optimization, comprehensive reporting
-- ===================================================

-- Create advanced order analytics table
CREATE TABLE IF NOT EXISTS order_analytics (
    analytics_id BIGSERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    customer_id VARCHAR(10),
    order_date DATE,
    total_amount DECIMAL(12,2),
    item_count INT,
    avg_item_value DECIMAL(10,2),
    processing_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    processing_batch_id UUID DEFAULT gen_random_uuid(),
    status VARCHAR(20) DEFAULT 'PROCESSED',
    
    UNIQUE(order_id, processing_batch_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Method 1: Sophisticated SCROLL Cursor with bidirectional processing
DO $$
DECLARE
    -- Declare scroll cursor for flexible navigation
    order_cursor SCROLL CURSOR FOR 
        SELECT 
            o.order_id,
            o.customer_id,
            o.order_date,
            c.company_name,
            COUNT(od.product_id) as total_items
        FROM orders o
        JOIN customers c ON o.customer_id = c.customer_id
        LEFT JOIN order_details od ON o.order_id = od.order_id
        WHERE o.order_date BETWEEN '1997-01-01' AND '1997-12-31'
        GROUP BY o.order_id, o.customer_id, o.order_date, c.company_name
        ORDER BY o.order_date DESC, total_items DESC;
    
    rec RECORD;
    v_batch_id UUID := gen_random_uuid();
    v_processed_count INT := 0;
    v_total_amount_sum DECIMAL(14,2) := 0;
    v_start_time TIMESTAMPTZ := clock_timestamp();
BEGIN
    RAISE NOTICE '=== ORDER PROCESSING BATCH: % ===', v_batch_id;
    RAISE NOTICE 'Started at: %', v_start_time;
    RAISE NOTICE '%-12s %-15s %-12s %-10s %-12s', 
        'Order ID', 'Customer', 'Date', 'Items', 'Total';
    RAISE NOTICE '%-12s %-15s %-12s %-10s %-12s', 
        '---------', '-------', '----', '-----', '-----';
    
    OPEN order_cursor;
    
    -- Process in forward direction
    LOOP
        FETCH order_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        
        -- Calculate order total using our robust function
        DECLARE
            v_order_total DECIMAL(12,2) := calculate_order_total(rec.order_id);
        BEGIN
            -- Insert into analytics table
            INSERT INTO order_analytics (
                order_id, customer_id, order_date, 
                total_amount, item_count, processing_batch_id
            ) VALUES (
                rec.order_id, rec.customer_id, rec.order_date,
                v_order_total, rec.total_items, v_batch_id
            );
            
            -- Display progress
            RAISE NOTICE '%-12s %-15s %-12s %-10s $%-11.2f', 
                rec.order_id,
                rec.customer_id,
                rec.order_date,
                rec.total_items,
                v_order_total;
            
            v_processed_count := v_processed_count + 1;
            v_total_amount_sum := v_total_amount_sum + v_order_total;
            
            -- Performance optimization: Commit every 5 records in real scenario
            -- In production, you might want to use COMMIT here
        END;
        
        -- Safety limit for demonstration
        IF v_processed_count >= 15 THEN
            EXIT;
        END IF;
    END LOOP;
    
    -- Demonstrate scroll capability by going backwards
    IF v_processed_count > 0 THEN
        RAISE NOTICE '--- Processing Summary (Scroll Demonstration) ---';
        MOVE BACKWARD 3 IN order_cursor; -- Move back 3 records
        
        FOR i IN 1..3 LOOP
            FETCH BACKWARD FROM order_cursor INTO rec;
            IF FOUND THEN
                RAISE NOTICE 'Scroll Back %: Order ID %', i, rec.order_id;
            END IF;
        END LOOP;
    END IF;
    
    CLOSE order_cursor;
    
    -- Performance metrics
    DECLARE
        v_end_time TIMESTAMPTZ := clock_timestamp();
        v_processing_time INTERVAL := v_end_time - v_start_time;
    BEGIN
        RAISE NOTICE '=== PROCESSING COMPLETE ===';
        RAISE NOTICE 'Records Processed: %', v_processed_count;
        RAISE NOTICE 'Total Amount: $%', v_total_amount_sum;
        RAISE NOTICE 'Average Order: $%', 
            ROUND(v_total_amount_sum / NULLIF(v_processed_count, 0), 2);
        RAISE NOTICE 'Processing Time: % milliseconds', 
            EXTRACT(EPOCH FROM v_processing_time) * 1000;
        RAISE NOTICE 'Performance: % records/second', 
            ROUND(v_processed_count / NULLIF(EXTRACT(EPOCH FROM v_processing_time), 0));
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Comprehensive error handling
        IF order_cursor%ISOPEN THEN
            CLOSE order_cursor;
        END IF;
        RAISE EXCEPTION 'Batch processing failed at record %: %', 
            v_processed_count, SQLERRM;
END $$;

-- Method 2: Fast FOR loop cursor for bulk processing
DO $$
DECLARE
    v_batch_id UUID := gen_random_uuid();
    v_bulk_count INT := 0;
BEGIN
    RAISE NOTICE '=== BULK ORDER PROCESSING STARTED ===';
    
    -- Implicit cursor with automatic opening/closing
    FOR rec IN (
        SELECT 
            o.order_id,
            o.customer_id,
            o.order_date
        FROM orders o
        WHERE o.order_date BETWEEN '1997-01-01' AND '1997-03-31'
        ORDER BY o.order_date
        LIMIT 20  -- Controlled processing for demonstration
    ) LOOP
        -- Efficient bulk insertion
        INSERT INTO order_analytics (
            order_id, customer_id, order_date, 
            total_amount, processing_batch_id
        ) VALUES (
            rec.order_id, rec.customer_id, rec.order_date,
            calculate_order_total(rec.order_id), v_batch_id
        )
        ON CONFLICT (order_id, processing_batch_id) DO UPDATE
        SET processing_timestamp = CURRENT_TIMESTAMP;
        
        v_bulk_count := v_bulk_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Bulk processing completed: % records', v_bulk_count;
END $$;

-- ===================================================
-- COMPREHENSIVE RESULTS ANALYSIS
-- ===================================================

-- Analytics Report 1: Batch Processing Summary
SELECT 
    processing_batch_id AS batch_id,
    COUNT(*) AS orders_processed,
    TO_CHAR(MIN(processing_timestamp), 'YYYY-MM-DD HH24:MI:SS') AS started_at,
    TO_CHAR(MAX(processing_timestamp), 'YYYY-MM-DD HH24:MI:SS') AS completed_at,
    SUM(total_amount) AS total_volume,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    MAX(total_amount) AS largest_order,
    MIN(total_amount) AS smallest_order
FROM order_analytics 
GROUP BY processing_batch_id
ORDER BY started_at DESC;

-- Analytics Report 2: Customer Order Analysis
SELECT 
    customer_id,
    COUNT(*) AS order_count,
    SUM(total_amount) AS total_spent,
    ROUND(AVG(total_amount), 2) AS avg_order_value,
    ROUND(SUM(total_amount) / COUNT(*), 2) AS customer_lifetime_value
FROM order_analytics 
WHERE customer_id IS NOT NULL
GROUP BY customer_id
ORDER BY total_spent DESC
LIMIT 10;

-- Analytics Report 3: Performance Metrics
SELECT 
    'Cursor Processing' AS metric_type,
    COUNT(*) AS total_records_processed,
    TO_CHAR(MIN(processing_timestamp), 'YYYY-MM-DD') AS first_processing_date,
    TO_CHAR(MAX(processing_timestamp), 'YYYY-MM-DD') AS last_processing_date,
    ROUND(SUM(total_amount), 2) AS total_processed_value
FROM order_analytics;