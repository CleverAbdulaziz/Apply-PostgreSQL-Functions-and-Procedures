-- Task_02.sql
-- Enhanced phone number formatting with better readability

WITH cleaned_phones AS (
    SELECT 
        customer_id,
        company_name,
        phone AS original_phone,
        -- Remove all non-digit characters
        REGEXP_REPLACE(phone, '[^0-9]', '') AS digits_only,
        LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '')) AS digit_count
    FROM customers
    WHERE phone IS NOT NULL
),
formatted_phones AS (
    SELECT 
        customer_id,
        company_name,
        original_phone,
        CASE 
            -- Handle numbers longer than 10 digits (take last 10)
            WHEN digit_count > 10 THEN 
                SUBSTRING(digits_only FROM digit_count - 9 FOR 10)
            -- Handle numbers shorter than 10 digits (pad with zeros)
            WHEN digit_count < 10 THEN 
                digits_only || REPEAT('0', 10 - digit_count)
            -- Exact 10 digits
            ELSE digits_only
        END AS standardized_digits
    FROM cleaned_phones
)
SELECT 
    customer_id,
    company_name,
    original_phone,
    -- Format as (XXX) XXX-XXXX
    '(' || SUBSTRING(standardized_digits FROM 1 FOR 3) || ') ' ||
    SUBSTRING(standardized_digits FROM 4 FOR 3) || '-' ||
    SUBSTRING(standardized_digits FROM 7 FOR 4) AS formatted_phone
FROM formatted_phones
LIMIT 10;