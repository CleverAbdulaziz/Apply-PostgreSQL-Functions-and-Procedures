-- Task_01.sql
-- Exercise 1: Identify records with nonstandard Latin symbols in Homepage

SELECT 
    supplier_id,
    company_name,
    homepage
FROM suppliers
WHERE homepage ~ '[^a-zA-Z0-9\s\.\-\_\/\:\@\#\%\&\+\=]';