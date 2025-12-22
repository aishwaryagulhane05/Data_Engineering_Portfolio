-- ============================================================================
-- SAMPLE DATA VALIDATION SCRIPT
-- Marketing Analytics Data Warehouse
-- ============================================================================
-- Purpose: Validate sample data quality and relationships
-- Run after: generate-sample-data.sql
-- Expected: All checks should pass (return 0 or expected values)
-- ============================================================================

USE ROLE MTLN_REPORTING_ROLE;
USE WAREHOUSE MTLN_REPORTING_WH;
USE DATABASE MTLN_PROD;

SELECT '========================================' AS validation_section;
SELECT 'DATA VALIDATION CHECKS' AS validation_section;
SELECT '========================================' AS validation_section;

-- ============================================================================
-- CHECK 1: ROW COUNTS
-- ============================================================================
SELECT '1. ROW COUNT VALIDATION' AS check_name;

SELECT 
    'Bronze - Channels' AS layer_table,
    COUNT(*) AS row_count,
    20 AS expected_min,
    CASE WHEN COUNT(*) >= 20 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_channels
UNION ALL
SELECT 
    'Bronze - Campaigns',
    COUNT(*),
    1000,
    CASE WHEN COUNT(*) >= 1000 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM BRONZE.mtln_bronze_campaigns
UNION ALL
SELECT 
    'Bronze - Customers',
    COUNT(*),
    10000,
    CASE WHEN COUNT(*) >= 10000 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM BRONZE.mtln_bronze_customers
UNION ALL
SELECT 
    'Bronze - Products',
    COUNT(*),
    1000,
    CASE WHEN COUNT(*) >= 1000 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM BRONZE.mtln_bronze_products
UNION ALL
SELECT 
    'Bronze - Sales',
    COUNT(*),
    100000,
    CASE WHEN COUNT(*) >= 100000 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM BRONZE.mtln_bronze_sales
UNION ALL
SELECT 
    'Bronze - Performance',
    COUNT(*),
    50000,
    CASE WHEN COUNT(*) >= 50000 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM BRONZE.mtln_bronze_performance
ORDER BY layer_table;

-- ============================================================================
-- CHECK 2: NULL VALUE CHECKS
-- ============================================================================
SELECT '2. NULL VALUE CHECKS (should return 0)' AS check_name;

-- Campaigns: Primary key should not be NULL
SELECT 
    'Campaigns - NULL campaign_id' AS check_name,
    COUNT(*) AS null_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_campaigns
WHERE campaign_id IS NULL;

-- Customers: Primary key should not be NULL
SELECT 
    'Customers - NULL customer_id' AS check_name,
    COUNT(*) AS null_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_customers
WHERE customer_id IS NULL;

-- Products: Primary key should not be NULL
SELECT 
    'Products - NULL product_id' AS check_name,
    COUNT(*) AS null_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_products
WHERE product_id IS NULL;

-- Sales: All key fields should not be NULL
SELECT 
    'Sales - NULL order_line_id' AS check_name,
    COUNT(*) AS null_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_sales
WHERE order_line_id IS NULL;

-- Performance: Primary key should not be NULL
SELECT 
    'Performance - NULL performance_id' AS check_name,
    COUNT(*) AS null_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_performance
WHERE performance_id IS NULL;

-- ============================================================================
-- CHECK 3: DUPLICATE CHECKS
-- ============================================================================
SELECT '3. DUPLICATE CHECKS (should return 0)' AS check_name;

-- Check for duplicate campaign_ids
SELECT 
    'Campaigns - Duplicates' AS check_name,
    COUNT(*) AS duplicate_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM (
    SELECT campaign_id, COUNT(*) as cnt
    FROM BRONZE.mtln_bronze_campaigns
    GROUP BY campaign_id
    HAVING COUNT(*) > 1
);

-- Check for duplicate customer_ids
SELECT 
    'Customers - Duplicates' AS check_name,
    COUNT(*) AS duplicate_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM (
    SELECT customer_id, COUNT(*) as cnt
    FROM BRONZE.mtln_bronze_customers
    GROUP BY customer_id
    HAVING COUNT(*) > 1
);

-- Check for duplicate product_ids
SELECT 
    'Products - Duplicates' AS check_name,
    COUNT(*) AS duplicate_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM (
    SELECT product_id, COUNT(*) as cnt
    FROM BRONZE.mtln_bronze_products
    GROUP BY product_id
    HAVING COUNT(*) > 1
);

-- ============================================================================
-- CHECK 4: REFERENTIAL INTEGRITY
-- ============================================================================
SELECT '4. REFERENTIAL INTEGRITY (should return 0)' AS check_name;

-- Sales: Check for orphaned customer_id
SELECT 
    'Sales - Orphaned customer_id' AS check_name,
    COUNT(*) AS orphan_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_sales s
LEFT JOIN BRONZE.mtln_bronze_customers c ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL AND s.customer_id IS NOT NULL;

-- Sales: Check for orphaned product_id
SELECT 
    'Sales - Orphaned product_id' AS check_name,
    COUNT(*) AS orphan_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_sales s
LEFT JOIN BRONZE.mtln_bronze_products p ON s.product_id = p.product_id
WHERE p.product_id IS NULL AND s.product_id IS NOT NULL;

-- Sales: Check for orphaned campaign_id
SELECT 
    'Sales - Orphaned campaign_id' AS check_name,
    COUNT(*) AS orphan_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_sales s
LEFT JOIN BRONZE.mtln_bronze_campaigns c ON s.campaign_id = c.campaign_id
WHERE c.campaign_id IS NULL AND s.campaign_id IS NOT NULL;

-- Performance: Check for orphaned campaign_id
SELECT 
    'Performance - Orphaned campaign_id' AS check_name,
    COUNT(*) AS orphan_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_performance p
LEFT JOIN BRONZE.mtln_bronze_campaigns c ON p.campaign_id = c.campaign_id
WHERE c.campaign_id IS NULL AND p.campaign_id IS NOT NULL;

-- Performance: Check for orphaned channel_id
SELECT 
    'Performance - Orphaned channel_id' AS check_name,
    COUNT(*) AS orphan_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_performance p
LEFT JOIN BRONZE.mtln_bronze_channels ch ON p.channel_id = ch.channel_id
WHERE ch.channel_id IS NULL AND p.channel_id IS NOT NULL;

-- ============================================================================
-- CHECK 5: BUSINESS RULE VALIDATION
-- ============================================================================
SELECT '5. BUSINESS RULE VALIDATION (should return 0)' AS check_name;

-- Campaigns: Budget should be positive
SELECT 
    'Campaigns - Negative budget' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_campaigns
WHERE budget < 0;

-- Campaigns: End date should be after start date
SELECT 
    'Campaigns - Invalid date range' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_campaigns
WHERE end_date < start_date;

-- Products: Unit price should be positive
SELECT 
    'Products - Non-positive unit_price' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_products
WHERE unit_price <= 0;

-- Products: Cost should be positive
SELECT 
    'Products - Non-positive cost' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_products
WHERE cost <= 0;

-- Products: Margin should be non-negative
SELECT 
    'Products - Negative margin' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_products
WHERE margin < 0;

-- Sales: Quantity should be positive
SELECT 
    'Sales - Non-positive quantity' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_sales
WHERE quantity <= 0;

-- Sales: Revenue calculation check
SELECT 
    'Sales - Invalid revenue calculation' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_sales
WHERE ABS(revenue - (line_total + tax_amount)) > 0.01;

-- Performance: Clicks should not exceed impressions
SELECT 
    'Performance - Clicks > Impressions' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_performance
WHERE clicks > impressions;

-- Performance: Conversions should not exceed clicks
SELECT 
    'Performance - Conversions > Clicks' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_performance
WHERE conversions > clicks;

-- Performance: Negative cost
SELECT 
    'Performance - Negative cost' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_performance
WHERE cost < 0;

-- Performance: Negative revenue
SELECT 
    'Performance - Negative revenue' AS check_name,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) = 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS status
FROM BRONZE.mtln_bronze_performance
WHERE revenue < 0;

-- ============================================================================
-- CHECK 6: DATA DISTRIBUTION
-- ============================================================================
SELECT '6. DATA DISTRIBUTION CHECKS' AS check_name;

-- Campaign status distribution
SELECT 
    'Campaign Status Distribution' AS metric_name,
    status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM BRONZE.mtln_bronze_campaigns
GROUP BY status
ORDER BY count DESC;

-- Customer segment distribution
SELECT 
    'Customer Segment Distribution' AS metric_name,
    segment,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM BRONZE.mtln_bronze_customers
GROUP BY segment
ORDER BY count DESC;

-- Customer tier distribution
SELECT 
    'Customer Tier Distribution' AS metric_name,
    tier,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM BRONZE.mtln_bronze_customers
GROUP BY tier
ORDER BY count DESC;

-- Product category distribution
SELECT 
    'Product Category Distribution' AS metric_name,
    category,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM BRONZE.mtln_bronze_products
GROUP BY category
ORDER BY count DESC;

-- ============================================================================
-- CHECK 7: DATE RANGE VALIDATION
-- ============================================================================
SELECT '7. DATE RANGE VALIDATION' AS check_name;

-- Campaigns date range
SELECT 
    'Campaigns Date Range' AS table_name,
    MIN(start_date) AS earliest_start,
    MAX(end_date) AS latest_end,
    DATEDIFF(day, MIN(start_date), MAX(end_date)) AS total_days_covered
FROM BRONZE.mtln_bronze_campaigns;

-- Sales date range
SELECT 
    'Sales Date Range' AS table_name,
    MIN(order_date) AS earliest_order,
    MAX(order_date) AS latest_order,
    DATEDIFF(day, MIN(order_date), MAX(order_date)) AS total_days_covered
FROM BRONZE.mtln_bronze_sales;

-- Performance date range
SELECT 
    'Performance Date Range' AS table_name,
    MIN(performance_date) AS earliest_date,
    MAX(performance_date) AS latest_date,
    DATEDIFF(day, MIN(performance_date), MAX(performance_date)) AS total_days_covered
FROM BRONZE.mtln_bronze_performance;

-- ============================================================================
-- CHECK 8: AGGREGATE METRICS
-- ============================================================================
SELECT '8. AGGREGATE METRICS SUMMARY' AS check_name;

-- Campaign budget summary
SELECT 
    'Campaign Budget Summary' AS metric_category,
    COUNT(*) AS total_campaigns,
    ROUND(SUM(budget), 2) AS total_budget,
    ROUND(AVG(budget), 2) AS avg_budget,
    ROUND(MIN(budget), 2) AS min_budget,
    ROUND(MAX(budget), 2) AS max_budget
FROM BRONZE.mtln_bronze_campaigns;

-- Customer LTV summary
SELECT 
    'Customer LTV Summary' AS metric_category,
    COUNT(*) AS total_customers,
    ROUND(SUM(lifetime_value), 2) AS total_ltv,
    ROUND(AVG(lifetime_value), 2) AS avg_ltv,
    ROUND(MIN(lifetime_value), 2) AS min_ltv,
    ROUND(MAX(lifetime_value), 2) AS max_ltv
FROM BRONZE.mtln_bronze_customers;

-- Product pricing summary
SELECT 
    'Product Pricing Summary' AS metric_category,
    COUNT(*) AS total_products,
    ROUND(AVG(unit_price), 2) AS avg_price,
    ROUND(AVG(margin_percent), 2) AS avg_margin_pct,
    ROUND(MIN(unit_price), 2) AS min_price,
    ROUND(MAX(unit_price), 2) AS max_price
FROM BRONZE.mtln_bronze_products;

-- Sales revenue summary
SELECT 
    'Sales Revenue Summary' AS metric_category,
    COUNT(*) AS total_orders,
    ROUND(SUM(revenue), 2) AS total_revenue,
    ROUND(AVG(revenue), 2) AS avg_order_value,
    ROUND(MIN(revenue), 2) AS min_order_value,
    ROUND(MAX(revenue), 2) AS max_order_value
FROM BRONZE.mtln_bronze_sales;

-- Performance metrics summary
SELECT 
    'Performance Metrics Summary' AS metric_category,
    COUNT(*) AS total_records,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    ROUND(SUM(cost), 2) AS total_cost,
    ROUND(SUM(revenue), 2) AS total_revenue,
    ROUND(SUM(revenue) / NULLIF(SUM(cost), 0), 2) AS overall_roas,
    ROUND(SUM(clicks) * 100.0 / NULLIF(SUM(impressions), 0), 2) AS overall_ctr
FROM BRONZE.mtln_bronze_performance;

-- ============================================================================
-- SUMMARY
-- ============================================================================

SELECT '========================================' AS summary;
SELECT 'VALIDATION COMPLETE' AS summary;
SELECT '========================================' AS summary;
SELECT 'Review all checks above - all should show ✅ PASS' AS summary;
SELECT 'If any checks show ❌ FAIL, investigate before proceeding' AS summary;
SELECT '========================================' AS summary;

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================