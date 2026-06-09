/*
Case Study 4 (Data Bank) - Easy Student Style Queries (SSMS / SQL Server)

Assumed tables (from the challenge dataset):
1) nodes(node_id, region_id)
2) customer_nodes(customer_id, region_id, node_id, start_date, end_date)
3) customer_transactions(customer_id, month, txn_type, txn_amount)

Run this file in SSMS.
*/


------------------------------------------------------------
-- A. Customer Nodes Exploration
------------------------------------------------------------

-- A1) How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id) AS unique_nodes
FROM nodes;

-- A2) What is the number of nodes per region?
SELECT 
  region_id,
  COUNT(DISTINCT node_id) AS nodes_per_region
FROM nodes
GROUP BY region_id
ORDER BY region_id;

-- A3) How many customers are allocated to each region?
-- Customer allocation is typically represented by the customer_nodes table.
SELECT 
  region_id,
  COUNT(DISTINCT customer_id) AS customers_per_region
FROM customer_nodes
GROUP BY region_id
ORDER BY region_id;

-- A4) How many days on average are customers reallocated to a different node?
-- Compute reallocation days using consecutive allocations per customer.
-- Reallocation day difference = next_start_date - current_end_date.
WITH allocs AS (
  SELECT
    customer_id,
    region_id,
    node_id,
    start_date,
    end_date,
    LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date, end_date) AS next_start_date,
    LEAD(node_id)    OVER (PARTITION BY customer_id ORDER BY start_date, end_date) AS next_node_id
  FROM customer_nodes
), reallocation_days AS (
  SELECT
    region_id,
    customer_id,
    DATEDIFF(day, end_date, next_start_date) AS realloc_days
  FROM allocs
  WHERE next_start_date IS NOT NULL
    AND next_node_id IS NOT NULL
    AND next_node_id <> node_id
)
SELECT
  region_id,
  AVG(CAST(realloc_days AS FLOAT)) AS avg_reallocation_days
FROM reallocation_days
GROUP BY region_id
ORDER BY region_id;

-- A5) What is the median, 80th and 95th percentile for reallocation days metric for each region?
-- SQL Server percentiles via PERCENTILE_CONT.
WITH allocs AS (
  SELECT
    customer_id,
    region_id,
    node_id,
    start_date,
    end_date,
    LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date, end_date) AS next_start_date,
    LEAD(node_id)    OVER (PARTITION BY customer_id ORDER BY start_date, end_date) AS next_node_id
  FROM customer_nodes
), reallocation_days AS (
  SELECT
    region_id,
    customer_id,
    DATEDIFF(day, end_date, next_start_date) AS realloc_days
  FROM allocs
  WHERE next_start_date IS NOT NULL
    AND next_node_id <> node_id
)
SELECT
  region_id,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY CAST(realloc_days AS FLOAT)) AS median_days,
  PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY CAST(realloc_days AS FLOAT)) AS p80_days,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY CAST(realloc_days AS FLOAT)) AS p95_days
FROM reallocation_days
GROUP BY region_id
ORDER BY region_id;

------------------------------------------------------------
-- B. Customer Transactions
------------------------------------------------------------

-- B1) What is the unique count and total amount for each transaction type?
SELECT
  txn_type,
  COUNT(*) AS txn_rows,
  COUNT(DISTINCT customer_id) AS unique_customers,
  SUM(txn_amount) AS total_amount
FROM customer_transactions
GROUP BY txn_type
ORDER BY txn_type;

-- B2) What is the average total historical deposit counts and amounts for all customers?
-- Historical = all deposit transactions before (or up to) each customer's lifetime.
-- Standard interpretation in this case study:
-- For each customer, count and sum their deposit transactions across all time,
-- then average across customers.
WITH customer_deposits AS (
  SELECT
    customer_id,
    COUNT(*) AS deposit_count,
    SUM(txn_amount) AS deposit_amount
  FROM customer_transactions
  WHERE txn_type = 'deposit'
  GROUP BY customer_id
)
SELECT
  AVG(CAST(deposit_count AS FLOAT)) AS avg_deposit_count_per_customer,
  AVG(CAST(deposit_amount AS FLOAT)) AS avg_deposit_amount_per_customer
FROM customer_deposits;

-- B3) For each month - how many Data Bank customers make more than 1 deposit
--     and either 1 purchase or 1 withdrawal in a single month?
-- Interpretation: in the same month for a customer:
--   deposits > 1
--   and (purchases = 1 OR withdrawals = 1) in that month.
-- If your data has multiple purchases/withdrawals, adjust condition accordingly.
WITH monthly AS (
  SELECT
    month,
    customer_id,
    SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_cnt,
    SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_cnt,
    SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_cnt
  FROM customer_transactions
  GROUP BY month, customer_id
), qualified AS (
  SELECT
    month,
    customer_id
  FROM monthly
  WHERE deposit_cnt > 1
    AND (purchase_cnt = 1 OR withdrawal_cnt = 1)
)
SELECT
  month,
  COUNT(DISTINCT customer_id) AS customers_meeting_criteria
FROM qualified
GROUP BY month
ORDER BY month;

