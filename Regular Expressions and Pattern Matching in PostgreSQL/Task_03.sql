-- Task_03.sql
-- Enhanced postal code classification with international support

CREATE OR REPLACE FUNCTION classify_customer_by_postal_code_v2(postal_code VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    cleaned_code VARCHAR;
BEGIN
    -- Enhanced input validation
    IF postal_code IS NULL OR TRIM(postal_code) = '' THEN
        RETURN 'Unknown';
    END IF;
    
    -- Clean the input: remove spaces and convert to uppercase
    cleaned_code := UPPER(REGEXP_REPLACE(postal_code, '\s', '', 'g'));
    
    -- Classification logic with enhanced patterns
    IF cleaned_code ~ '^\d{5}$' THEN
        RETURN 'Local';  -- US ZIP format: 12345
    ELSIF cleaned_code ~ '^\d{5}-\d{4}$' THEN
        RETURN 'Local';  -- US ZIP+4 format: 12345-6789
    ELSIF cleaned_code ~ '^\d{3}-\d{3}$' THEN
        RETURN 'National';  -- Japanese format: 123-456
    ELSIF cleaned_code ~ '^[A-Z]\d[A-Z]\s?\d[A-Z]\d$' THEN
        RETURN 'International';  -- Canadian format: A1A 1A1
    ELSIF cleaned_code ~ '^[A-Z]{1,2}\d{1,2}[A-Z]?\s?\d[A-Z]{2}$' THEN
        RETURN 'International';  -- UK format: SW1A 1AA
    ELSE
        RETURN 'International';  -- All other formats
    END IF;
    
EXCEPTION
    WHEN others THEN
        -- Log error (in real scenario, use proper logging)
        RAISE NOTICE 'Error classifying postal code: %', SQLERRM;
        RETURN 'Unknown';
END;
$$ LANGUAGE plpgsql;