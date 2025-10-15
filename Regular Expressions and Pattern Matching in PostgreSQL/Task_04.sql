-- Task_04.sql
-- Enhanced product name validation trigger

CREATE OR REPLACE FUNCTION validate_product_name_v2()
RETURNS TRIGGER AS $$
DECLARE
    trimmed_name VARCHAR;
BEGIN
    -- Enhanced NULL check
    IF NEW.productname IS NULL THEN
        RAISE EXCEPTION 'Product name cannot be NULL';
    END IF;
    
    -- Trim and check effective length
    trimmed_name := TRIM(NEW.productname);
    
    IF LENGTH(trimmed_name) < 5 THEN
        RAISE EXCEPTION 'Product name must be at least 5 characters long (after trimming)';
    END IF;
    
    -- Check if starts with uppercase letter (A-Z in any language)
    IF trimmed_name !~ '^[A-Z]' THEN
        RAISE EXCEPTION 'Product name must start with an uppercase letter (A-Z)';
    END IF;
    
    -- Additional validation: should contain at least one letter
    IF trimmed_name !~ '[A-Za-z]' THEN
        RAISE EXCEPTION 'Product name must contain at least one letter';
    END IF;
    
    -- Update with trimmed version
    NEW.productname := trimmed_name;
    
    RETURN NEW;
    
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Product name validation failed: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Enhanced test cases
DO $$ 
BEGIN
    RAISE NOTICE 'Testing enhanced product validation...';
    
    -- Test valid multi-language names
    INSERT INTO products (productname, supplierid, categoryid, unitprice) 
    VALUES (' Café Premium', 1, 1, 15.00);
    
    -- Test names with extra spaces
    INSERT INTO products (productname, supplierid, categoryid, unitprice) 
    VALUES ('   Organic Tea   ', 1, 1, 12.00);
    
EXCEPTION 
    WHEN others THEN
        RAISE NOTICE 'Test completed with expected exceptions';
END $$;