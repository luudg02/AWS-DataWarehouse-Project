-- AWS Data Warehouse Creation Script for Amazon Athena
-- Created: June 23, 2025

-- Create schema if it doesn't exist
CREATE DATABASE IF NOT EXISTS dw;

-- Fact tables will be created using the existing dimension tables in Athena
-- Reference to existing dimension tables
-- Using existing dimension tables from Athena database 'luvutu-database':
-- customers: contains customer information
-- accounts: contains account information
-- dates: contains date dimension data
-- channels: contains channel information
-- transaction_types: contains transaction types
-- locations: contains location information
-- currencies: contains currency information
-- loans: contains loan information
-- investment_types: contains investment type information

-- Now create the fact tables based on the ERD

-- Fact: Transaction
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_transaction (
    transaction_id INT,
    customer_id INT,
    transaction_date_id INT,
    channel_id INT,
    account_id INT,
    transaction_type_id INT,
    location_id INT,
    currency_id INT,
    loan_id INT,
    investment_type_id INT,
    transaction_amount DECIMAL(18, 2),
    transaction_status VARCHAR(50)
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_transaction/';

-- Fact: Daily Balance
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_daily_balance (
    balance_id INT,
    date_id INT,
    account_id INT,
    opening_balance DECIMAL(18, 2),
    closing_balance DECIMAL(18, 2)
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_daily_balance/';

-- Fact: Customer Interaction
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_customer_interaction (
    balance_id INT,
    date_id INT,
    account_id INT,
    channel_id INT,
    interaction_type VARCHAR(50),
    interaction_rating INT
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_customer_interaction/';

-- Fact: Loan Payment
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_loan_payment (
    payment_id INT,
    date_id INT,
    loan_id INT,
    customer_id INT,
    payment_amount DECIMAL(18, 2),
    payment_status VARCHAR(50)
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_loan_payment/';

-- Fact: Investment
CREATE EXTERNAL TABLE IF NOT EXISTS dw.fact_investment (
    investment_id INT,
    date_id INT,
    investment_type_id INT,
    account_id INT,
    investment_amount DECIMAL(18, 2),
    return_amount DECIMAL(18, 2)
)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_investment/';

-- Populate fact tables using existing dimension tables in Athena
-- Note: You'll need to replace 'luvutu-database' with the actual database name if different

-- Example queries to populate the fact tables from the dimension tables in Athena:

-- Example 1: Populate fact_transaction table
-- Note: Athena doesn't support RAND() directly, using alternative approach
INSERT INTO dw.fact_transaction
SELECT 
    CAST(100000 + d.date_id + c.customer_id AS INT) as transaction_id,  -- Using deterministic values instead of ROW_NUMBER
    c.customer_id,
    d.date_id,
    ch.channel_id,
    a.account_id,
    tt.transaction_type_id,
    l.location_id,
    cu.currency_id,
    ln.loan_id,
    it.investment_type_id,
    CAST(5000 + (a.account_balance % 5000) AS DECIMAL(18,2)) as transaction_amount,  -- Using deterministic formula instead of RAND
    CASE 
        WHEN (c.customer_id % 5) > 1 THEN 'Completed' 
        ELSE 'Pending' 
    END as transaction_status
FROM 
    "luvutu-database"."customers" c
    CROSS JOIN "luvutu-database"."dates" d
    CROSS JOIN "luvutu-database"."channels" ch
    JOIN "luvutu-database"."accounts" a ON c.customer_id = a.customer_id
    CROSS JOIN "luvutu-database"."transaction_types" tt
    CROSS JOIN "luvutu-database"."locations" l
    CROSS JOIN "luvutu-database"."currencies" cu
    LEFT JOIN "luvutu-database"."loans" ln ON ln.loan_id = CASE WHEN tt.transaction_type_id = 4 THEN MOD(c.customer_id, 50) + 1 ELSE NULL END
    LEFT JOIN "luvutu-database"."investment_types" it ON it.investment_type_id = CASE WHEN tt.transaction_type_id = 3 THEN MOD(c.customer_id, 7) + 1 ELSE NULL END
WHERE 
    MOD(d.date_id + c.customer_id, 100) = 1  -- Limiting the number of rows using deterministic approach
LIMIT 1000;

-- Example 2: Populate fact_daily_balance table
INSERT INTO dw.fact_daily_balance
SELECT 
    200000 + a.account_id + d.date_id as balance_id,  -- Deterministic ID generation
    d.date_id,
    a.account_id,
    a.account_balance - CAST(MOD(a.account_id * d.date_id, 1000) AS DECIMAL(18,2)) as opening_balance,  -- Deterministic value instead of RAND
    a.account_balance as closing_balance
FROM 
    "luvutu-database"."accounts" a
    CROSS JOIN "luvutu-database"."dates" d
WHERE 
    MOD(d.date_id + a.account_id, 100) = 2  -- Limiting rows deterministically
LIMIT 1000;

-- Example 3: Populate fact_customer_interaction table
INSERT INTO dw.fact_customer_interaction
SELECT 
    300000 + a.account_id + d.date_id + ch.channel_id as balance_id,  -- Deterministic ID generation
    d.date_id,
    a.account_id,
    ch.channel_id,
    CASE 
        WHEN MOD(a.account_id * d.date_id, 3) = 0 THEN 'Inquiry'
        WHEN MOD(a.account_id * d.date_id, 3) = 1 THEN 'Complaint'
        ELSE 'Feedback'
    END as interaction_type,
    MOD(a.account_id + d.date_id, 5) + 1 as interaction_rating  -- Rating between 1 and 5
FROM 
    "luvutu-database"."accounts" a
    CROSS JOIN "luvutu-database"."dates" d
    CROSS JOIN "luvutu-database"."channels" ch
WHERE 
    MOD(d.date_id + a.account_id + ch.channel_id, 100) = 3  -- Limiting rows deterministically
LIMIT 500;

-- Example 4: Populate fact_loan_payment table
INSERT INTO dw.fact_loan_payment
SELECT 
    400000 + l.loan_id + d.date_id + c.customer_id as payment_id,  -- Deterministic ID generation
    d.date_id,
    l.loan_id,
    c.customer_id,
    CAST(l.loan_amount * (MOD(l.loan_id * d.date_id, 10) / 100.0) AS DECIMAL(18,2)) as payment_amount,  -- Deterministic payment calculation
    CASE 
        WHEN MOD(l.loan_id + d.date_id, 20) > 1 THEN 'Paid'
        ELSE 'Late'
    END as payment_status
FROM 
    "luvutu-database"."loans" l
    CROSS JOIN "luvutu-database"."dates" d
    CROSS JOIN "luvutu-database"."customers" c
WHERE 
    MOD(l.loan_id + d.date_id + c.customer_id, 20) = 0  -- Limiting rows deterministically
LIMIT 200;

-- Example 5: Populate fact_investment table
INSERT INTO dw.fact_investment
SELECT 
    500000 + it.investment_type_id + d.date_id + a.account_id as investment_id,  -- Deterministic ID generation
    d.date_id,
    it.investment_type_id,
    a.account_id,
    CAST(10000 + (a.account_balance % 40000) AS DECIMAL(18,2)) as investment_amount,  -- Deterministic investment amount
    CAST(12000 + (a.account_balance % 48000) AS DECIMAL(18,2)) as return_amount       -- Deterministic return amount with slight profit
FROM 
    "luvutu-database"."investment_types" it
    CROSS JOIN "luvutu-database"."dates" d
    CROSS JOIN "luvutu-database"."accounts" a
WHERE 
    a.account_type = 'Investment'
    AND MOD(it.investment_type_id + d.date_id + a.account_id, 20) = 0  -- Limiting rows deterministically
LIMIT 300;

-- Note: Amazon Athena doesn't support explicit index creation since it's a serverless 
-- query service working on data in S3. Partitioning is the equivalent technique used for performance.

-- Example of how to create partitioned tables if needed:
/*
CREATE EXTERNAL TABLE dw.fact_transaction_partitioned (
    transaction_id INT,
    customer_id INT,
    transaction_date_id INT,
    channel_id INT,
    account_id INT,
    transaction_type_id INT,
    location_id INT,
    currency_id INT,
    loan_id INT,
    investment_type_id INT,
    transaction_amount DECIMAL(18, 2),
    transaction_status VARCHAR(50)
)
PARTITIONED BY (year INT, month INT)
STORED AS PARQUET
LOCATION 's3://luvutu-s3/fact_transaction_partitioned/';

-- Then, populate with INSERT statement
INSERT INTO dw.fact_transaction_partitioned
SELECT 
    transaction_id, 
    customer_id,
    transaction_date_id,
    channel_id,
    account_id,
    transaction_type_id,
    location_id,
    currency_id,
    loan_id,
    investment_type_id,
    transaction_amount,
    transaction_status,
    EXTRACT(year FROM dates.date) AS year,
    EXTRACT(month FROM dates.date) AS month
FROM 
    dw.fact_transaction ft
JOIN 
    "luvutu-database"."dates" dates ON ft.transaction_date_id = dates.date_id;
*/

-- Create Athena Views for common analytical queries:

-- View: Monthly Transaction Summary
CREATE OR REPLACE VIEW dw.vw_monthly_transaction_summary AS
SELECT 
    d.year,
    d.month,
    tt.description as transaction_type,
    COUNT(*) as transaction_count,
    SUM(ft.transaction_amount) as total_amount
FROM 
    dw.fact_transaction ft
JOIN 
    "luvutu-database"."dates" d ON ft.transaction_date_id = d.date_id
JOIN 
    "luvutu-database"."transaction_types" tt ON ft.transaction_type_id = tt.transaction_type_id
GROUP BY 
    d.year, d.month, tt.description;

-- View: Customer Account Summary
CREATE OR REPLACE VIEW dw.vw_customer_account_summary AS
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT a.account_id) as account_count,
    SUM(a.account_balance) as total_balance,
    AVG(a.credit_score) as avg_credit_score
FROM 
    "luvutu-database"."customers" c
JOIN 
    "luvutu-database"."accounts" a ON c.customer_id = a.customer_id
GROUP BY 
    c.customer_id, c.first_name, c.last_name;

-- View: Channel Effectiveness
CREATE OR REPLACE VIEW dw.vw_channel_effectiveness AS
SELECT 
    ch.channel_name,
    COUNT(*) as interaction_count,
    AVG(fci.interaction_rating) as avg_rating
FROM 
    dw.fact_customer_interaction fci
JOIN 
    "luvutu-database"."channels" ch ON fci.channel_id = ch.channel_id
GROUP BY 
    ch.channel_name;

-- View: Investment Performance
CREATE OR REPLACE VIEW dw.vw_investment_performance AS
SELECT 
    it.investment_type_name,
    COUNT(*) as investment_count,
    SUM(fi.investment_amount) as total_invested,
    SUM(fi.return_amount) as total_return,
    SUM(fi.return_amount - fi.investment_amount) as total_profit,
    (SUM(fi.return_amount) / NULLIF(SUM(fi.investment_amount), 0) - 1) * 100 as roi_percentage
FROM 
    dw.fact_investment fi
JOIN 
    "luvutu-database"."investment_types" it ON fi.investment_type_id = it.investment_type_id
GROUP BY 
    it.investment_type_name;
