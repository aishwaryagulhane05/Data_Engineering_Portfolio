-- ============================================================================
-- SAMPLE DATA GENERATION SCRIPT
-- Marketing Analytics Data Warehouse
-- ============================================================================
-- Purpose: Generate realistic sample data for testing pipelines
-- Target: Bronze tables (simulates data loaded from Parquet files)
-- Volume: ~1K campaigns, 10K customers, 1K products, 100K sales, 50K performance, 20 channels
-- Duration: ~5 minutes to execute
-- ============================================================================

USE ROLE MTLN_ETL_ROLE;
USE WAREHOUSE MTLN_ETL_WH;
USE DATABASE MTLN_PROD;
USE SCHEMA BRONZE;

-- ============================================================================
-- PART 1: CHANNELS (Reference Data)
-- ============================================================================
-- Small reference table - 20 marketing channels
-- ============================================================================

TRUNCATE TABLE IF EXISTS mtln_bronze_channels;

INSERT INTO mtln_bronze_channels (
    channel_id,
    channel_name,
    channel_type,
    category,
    cost_structure,
    last_modified_timestamp,
    load_timestamp,
    source_system
)
VALUES
    ('CH-EMAIL', 'Email Marketing', 'Email', 'Owned', 'Fixed', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-ORGANIC', 'Organic Search', 'Search', 'Earned', 'Free', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-PAID-SEARCH', 'Paid Search - Google', 'Paid Search', 'Paid', 'CPC', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-PAID-BING', 'Paid Search - Bing', 'Paid Search', 'Paid', 'CPC', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-DISPLAY', 'Display Advertising', 'Display', 'Paid', 'CPM', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-SOCIAL-FB', 'Facebook Ads', 'Social', 'Paid', 'CPM', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-SOCIAL-IG', 'Instagram Ads', 'Social', 'Paid', 'CPM', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-SOCIAL-LI', 'LinkedIn Ads', 'Social', 'Paid', 'CPC', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-SOCIAL-TW', 'Twitter Ads', 'Social', 'Paid', 'CPM', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-VIDEO', 'YouTube Ads', 'Video', 'Paid', 'CPV', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-AFFILIATE', 'Affiliate Marketing', 'Affiliate', 'Paid', 'CPA', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-DIRECT', 'Direct Traffic', 'Direct', 'Owned', 'Free', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-REFERRAL', 'Referral Traffic', 'Referral', 'Earned', 'Free', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-SMS', 'SMS Marketing', 'SMS', 'Owned', 'Fixed', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-PUSH', 'Push Notifications', 'Mobile', 'Owned', 'Fixed', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-RETARGET', 'Retargeting Display', 'Display', 'Paid', 'CPM', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-SHOPPING', 'Google Shopping', 'Shopping', 'Paid', 'CPC', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-PODCAST', 'Podcast Advertising', 'Audio', 'Paid', 'CPM', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-INFLUENCER', 'Influencer Marketing', 'Social', 'Paid', 'Fixed', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM'),
    ('CH-CONTENT', 'Content Marketing', 'Content', 'Owned', 'Fixed', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), 'MARKETING_PLATFORM');

SELECT 'Channels loaded: ' || COUNT(*) AS status FROM mtln_bronze_channels;

-- ============================================================================
-- PART 2: CAMPAIGNS
-- ============================================================================
-- 1,000 campaigns spanning last 2 years + next 3 months
-- Mix of active, completed, and future campaigns
-- ============================================================================

TRUNCATE TABLE IF EXISTS mtln_bronze_campaigns;

INSERT INTO mtln_bronze_campaigns (
    campaign_id,
    campaign_name,
    campaign_type,
    start_date,
    end_date,
    budget,
    status,
    objective,
    last_modified_timestamp,
    load_timestamp,
    source_system
)
SELECT
    'CPG-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS campaign_id,
    CASE (UNIFORM(1, 10, RANDOM()) % 10)
        WHEN 0 THEN 'Q' || ((SEQ4() % 4) + 1) || ' ' || (2023 + (SEQ4() % 3)) || ' Brand Awareness'
        WHEN 1 THEN 'Holiday ' || (ARRAY_CONSTRUCT('Spring', 'Summer', 'Fall', 'Winter')[SEQ4() % 4]) || ' Campaign'
        WHEN 2 THEN 'Product Launch - ' || (ARRAY_CONSTRUCT('Widget Pro', 'Gadget Max', 'Tool Elite', 'Device Plus')[SEQ4() % 4])
        WHEN 3 THEN 'Flash Sale - ' || DATEADD(day, SEQ4() % 730, '2023-01-01'::DATE)
        WHEN 4 THEN 'Customer Retention ' || (2023 + (SEQ4() % 3))
        WHEN 5 THEN 'Lead Generation - ' || (ARRAY_CONSTRUCT('Enterprise', 'SMB', 'Consumer')[SEQ4() % 3])
        WHEN 6 THEN 'Re-engagement Campaign ' || (SEQ4() % 12 + 1)
        WHEN 7 THEN 'Webinar Promotion - ' || (ARRAY_CONSTRUCT('Q1', 'Q2', 'Q3', 'Q4')[SEQ4() % 4])
        WHEN 8 THEN 'Partnership - ' || (ARRAY_CONSTRUCT('TechCorp', 'InnovateCo', 'GlobalBrand', 'StartupX')[SEQ4() % 4])
        ELSE 'Acquisition Campaign ' || LPAD((SEQ4() % 100)::VARCHAR, 3, '0')
    END AS campaign_name,
    (ARRAY_CONSTRUCT('Brand', 'Performance', 'Retargeting', 'Product Launch', 'Seasonal', 'Lead Gen')[UNIFORM(0, 5, RANDOM())]) AS campaign_type,
    DATEADD(day, -730 + (SEQ4() % 820), CURRENT_DATE())::DATE AS start_date,
    DATEADD(day, -730 + (SEQ4() % 820) + UNIFORM(14, 90, RANDOM()), CURRENT_DATE())::DATE AS end_date,
    UNIFORM(10000, 200000, RANDOM()) AS budget,
    CASE 
        WHEN DATEADD(day, -730 + (SEQ4() % 820) + UNIFORM(14, 90, RANDOM()), CURRENT_DATE())::DATE < CURRENT_DATE() THEN 'Completed'
        WHEN DATEADD(day, -730 + (SEQ4() % 820), CURRENT_DATE())::DATE > CURRENT_DATE() THEN 'Scheduled'
        WHEN UNIFORM(1, 10, RANDOM()) <= 2 THEN 'Paused'
        ELSE 'Active'
    END AS status,
    (ARRAY_CONSTRUCT(
        'Increase brand awareness by 25%',
        'Generate 500+ qualified leads',
        'Achieve 15% conversion rate',
        'Drive 100K website visits',
        'Boost sales by $500K',
        'Improve ROAS to 4:1',
        'Acquire 1000 new customers',
        'Reduce CAC by 20%',
        'Increase engagement by 50%',
        'Launch new product successfully'
    )[UNIFORM(0, 9, RANDOM())]) AS objective,
    DATEADD(hour, -UNIFORM(1, 48, RANDOM()), CURRENT_TIMESTAMP()) AS last_modified_timestamp,
    CURRENT_TIMESTAMP() AS load_timestamp,
    'MARKETING_PLATFORM' AS source_system
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

SELECT 'Campaigns loaded: ' || COUNT(*) AS status FROM mtln_bronze_campaigns;

-- ============================================================================
-- PART 3: CUSTOMERS
-- ============================================================================
-- 10,000 customers with realistic profiles
-- Mix of segments, tiers, and status
-- ============================================================================

TRUNCATE TABLE IF EXISTS mtln_bronze_customers;

INSERT INTO mtln_bronze_customers (
    customer_id,
    customer_name,
    email,
    phone,
    segment,
    tier,
    status,
    lifetime_value,
    last_modified_timestamp,
    load_timestamp,
    source_system
)
SELECT
    'CUST-' || LPAD(SEQ4()::VARCHAR, 8, '0') AS customer_id,
    (ARRAY_CONSTRUCT(
        'John', 'Jane', 'Michael', 'Sarah', 'David', 'Emily', 'Robert', 'Jennifer', 'William', 'Linda',
        'James', 'Patricia', 'Christopher', 'Barbara', 'Daniel', 'Elizabeth', 'Matthew', 'Susan', 'Anthony', 'Jessica'
    )[UNIFORM(0, 19, RANDOM())]) || ' ' ||
    (ARRAY_CONSTRUCT(
        'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
        'Anderson', 'Taylor', 'Thomas', 'Moore', 'Jackson', 'Martin', 'Lee', 'Thompson', 'White', 'Harris'
    )[UNIFORM(0, 19, RANDOM())]) AS customer_name,
    LOWER(
        (ARRAY_CONSTRUCT('john', 'jane', 'michael', 'sarah', 'david', 'emily', 'robert', 'jennifer', 'william', 'linda')[UNIFORM(0, 9, RANDOM())]) || '.' ||
        (ARRAY_CONSTRUCT('smith', 'johnson', 'williams', 'brown', 'jones', 'garcia', 'miller', 'davis', 'rodriguez', 'martinez')[UNIFORM(0, 9, RANDOM())]) ||
        UNIFORM(1, 999, RANDOM())::VARCHAR || '@example.com'
    ) AS email,
    '+1-' || LPAD(UNIFORM(200, 999, RANDOM())::VARCHAR, 3, '0') || '-' ||
             LPAD(UNIFORM(100, 999, RANDOM())::VARCHAR, 3, '0') || '-' ||
             LPAD(UNIFORM(1000, 9999, RANDOM())::VARCHAR, 4, '0') AS phone,
    (ARRAY_CONSTRUCT('Enterprise', 'SMB', 'Consumer')[UNIFORM(0, 2, RANDOM())]) AS segment,
    (ARRAY_CONSTRUCT('Platinum', 'Gold', 'Silver', 'Bronze')[
        CASE
            WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN 0   -- 5% Platinum
            WHEN UNIFORM(1, 100, RANDOM()) <= 20 THEN 1  -- 15% Gold
            WHEN UNIFORM(1, 100, RANDOM()) <= 50 THEN 2  -- 30% Silver
            ELSE 3                                        -- 50% Bronze
        END
    ]) AS tier,
    CASE
        WHEN UNIFORM(1, 100, RANDOM()) <= 85 THEN 'Active'
        WHEN UNIFORM(1, 100, RANDOM()) <= 10 THEN 'Inactive'
        ELSE 'Churned'
    END AS status,
    CASE 
        WHEN UNIFORM(0, 2, RANDOM()) = 0 THEN UNIFORM(50000, 100000, RANDOM())    -- Platinum: $50K-$100K
        WHEN UNIFORM(0, 2, RANDOM()) = 1 THEN UNIFORM(15000, 50000, RANDOM())     -- Gold: $15K-$50K
        WHEN UNIFORM(0, 2, RANDOM()) = 2 THEN UNIFORM(5000, 15000, RANDOM())      -- Silver: $5K-$15K
        ELSE UNIFORM(100, 5000, RANDOM())                                          -- Bronze: $100-$5K
    END AS lifetime_value,
    DATEADD(hour, -UNIFORM(1, 168, RANDOM()), CURRENT_TIMESTAMP()) AS last_modified_timestamp,
    CURRENT_TIMESTAMP() AS load_timestamp,
    'CRM' AS source_system
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

SELECT 'Customers loaded: ' || COUNT(*) AS status FROM mtln_bronze_customers;

-- ============================================================================
-- PART 4: PRODUCTS
-- ============================================================================
-- 1,000 products across multiple categories
-- Realistic pricing and margins
-- ============================================================================

TRUNCATE TABLE IF EXISTS mtln_bronze_products;

INSERT INTO mtln_bronze_products (
    product_id,
    sku,
    product_name,
    category,
    subcategory,
    brand,
    unit_price,
    cost,
    margin,
    margin_percent,
    product_status,
    last_modified_timestamp,
    load_timestamp,
    source_system
)
SELECT
    'PROD-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS product_id,
    'SKU-' || (ARRAY_CONSTRUCT('ELC', 'APP', 'HOM', 'GAD', 'TOL')[cat_idx]) || '-' ||
              LPAD(SEQ4()::VARCHAR, 5, '0') AS sku,
    prod_prefix || ' ' || prod_model AS product_name,
    category_name AS category,
    subcategory_name AS subcategory,
    (ARRAY_CONSTRUCT('TechBrand', 'InnovateCo', 'QualityMakers', 'PremiumLine', 'ValueChoice', 'EliteProducts')[UNIFORM(0, 5, RANDOM())]) AS brand,
    base_price AS unit_price,
    ROUND(base_price * (1 - margin_pct), 2) AS cost,
    ROUND(base_price * margin_pct, 2) AS margin,
    ROUND(margin_pct * 100, 2) AS margin_percent,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 95 THEN 'Active' ELSE 'Discontinued' END AS product_status,
    DATEADD(day, -UNIFORM(1, 90, RANDOM()), CURRENT_TIMESTAMP()) AS last_modified_timestamp,
    CURRENT_TIMESTAMP() AS load_timestamp,
    'ERP' AS source_system
FROM (
    SELECT
        SEQ4(),
        UNIFORM(0, 4, RANDOM()) AS cat_idx,
        CASE UNIFORM(0, 4, RANDOM())
            WHEN 0 THEN 'Electronics'
            WHEN 1 THEN 'Apparel'
            WHEN 2 THEN 'Home & Garden'
            WHEN 3 THEN 'Gadgets'
            ELSE 'Tools'
        END AS category_name,
        CASE UNIFORM(0, 4, RANDOM())
            WHEN 0 THEN 'Smartphones'
            WHEN 1 THEN 'Mens Clothing'
            WHEN 2 THEN 'Furniture'
            WHEN 3 THEN 'Smart Home'
            ELSE 'Power Tools'
        END AS subcategory_name,
        CASE UNIFORM(0, 9, RANDOM())
            WHEN 0 THEN 'Premium Widget'
            WHEN 1 THEN 'Standard Gadget'
            WHEN 2 THEN 'Elite Tool'
            WHEN 3 THEN 'Pro Device'
            WHEN 4 THEN 'Smart Appliance'
            WHEN 5 THEN 'Classic Item'
            WHEN 6 THEN 'Modern Accessory'
            WHEN 7 THEN 'Deluxe Product'
            WHEN 8 THEN 'Essential Kit'
            ELSE 'Value Pack'
        END AS prod_prefix,
        CASE UNIFORM(0, 4, RANDOM())
            WHEN 0 THEN 'Pro'
            WHEN 1 THEN 'Max'
            WHEN 2 THEN 'Elite'
            WHEN 3 THEN 'Plus'
            ELSE 'Standard'
        END || ' ' || LPAD((UNIFORM(100, 999, RANDOM()))::VARCHAR, 3, '0') AS prod_model,
        UNIFORM(19.99, 599.99, RANDOM()) AS base_price,
        UNIFORM(0.25, 0.65, RANDOM()) AS margin_pct
    FROM TABLE(GENERATOR(ROWCOUNT => 1000))
);

SELECT 'Products loaded: ' || COUNT(*) AS status FROM mtln_bronze_products;

-- ============================================================================
-- PART 5: SALES (TRANSACTIONAL FACT)
-- ============================================================================
-- 100,000 order line items over last 12 months
-- Realistic order patterns with seasonality
-- ============================================================================

TRUNCATE TABLE IF EXISTS mtln_bronze_sales;

INSERT INTO mtln_bronze_sales (
    order_id,
    order_line_id,
    customer_id,
    product_id,
    campaign_id,
    order_date,
    order_timestamp,
    quantity,
    unit_price,
    discount_amount,
    tax_amount,
    line_total,
    revenue,
    last_modified_timestamp,
    load_timestamp,
    source_system
)
SELECT
    'ORD-' || LPAD(order_num::VARCHAR, 10, '0') AS order_id,
    'ORD-' || LPAD(order_num::VARCHAR, 10, '0') || '-' || LPAD(line_num::VARCHAR, 3, '0') AS order_line_id,
    (SELECT customer_id FROM mtln_bronze_customers ORDER BY RANDOM() LIMIT 1) AS customer_id,
    (SELECT product_id FROM mtln_bronze_products WHERE product_status = 'Active' ORDER BY RANDOM() LIMIT 1) AS product_id,
    (SELECT campaign_id FROM mtln_bronze_campaigns WHERE status IN ('Active', 'Completed') ORDER BY RANDOM() LIMIT 1) AS campaign_id,
    order_date,
    order_date + (INTERVAL '1 hour' * UNIFORM(8, 22, RANDOM())) +
                 (INTERVAL '1 minute' * UNIFORM(0, 59, RANDOM())) +
                 (INTERVAL '1 second' * UNIFORM(0, 59, RANDOM())) AS order_timestamp,
    UNIFORM(1, 5, RANDOM()) AS quantity,
    unit_price,
    discount_amount,
    tax_amount,
    line_total,
    line_total + tax_amount AS revenue,
    order_date + (INTERVAL '1 hour' * UNIFORM(1, 24, RANDOM())) AS last_modified_timestamp,
    CURRENT_TIMESTAMP() AS load_timestamp,
    'ECOMMERCE' AS source_system
FROM (
    SELECT
        SEQ4() AS order_num,
        UNIFORM(1, CASE WHEN UNIFORM(1, 10, RANDOM()) <= 7 THEN 1 ELSE 3 END, RANDOM()) AS line_num,
        DATEADD(day, -365 + (SEQ4() % 365), CURRENT_DATE())::DATE AS order_date,
        UNIFORM(29.99, 499.99, RANDOM()) AS unit_price,
        CASE 
            WHEN UNIFORM(1, 100, RANDOM()) <= 30 THEN UNIFORM(5, 50, RANDOM())
            ELSE 0
        END AS discount_amount,
        0 AS tax_amount,
        0 AS line_total
    FROM TABLE(GENERATOR(ROWCOUNT => 100000))
),
LATERAL (
    SELECT 
        (unit_price * UNIFORM(1, 5, RANDOM())) - discount_amount AS line_total
),
LATERAL (
    SELECT
        ROUND(line_total * 0.08, 2) AS tax_amount
);

SELECT 'Sales loaded: ' || COUNT(*) AS status FROM mtln_bronze_sales;

-- ============================================================================
-- PART 6: PERFORMANCE (DAILY SNAPSHOT FACT)
-- ============================================================================
-- 50,000 daily performance records (campaign x channel x date)
-- Realistic metrics with ROAS variation
-- ============================================================================

TRUNCATE TABLE IF EXISTS mtln_bronze_performance;

INSERT INTO mtln_bronze_performance (
    performance_id,
    campaign_id,
    channel_id,
    performance_date,
    impressions,
    clicks,
    cost,
    conversions,
    revenue,
    last_modified_timestamp,
    load_timestamp,
    source_system
)
SELECT
    'PERF-' || LPAD(SEQ4()::VARCHAR, 10, '0') AS performance_id,
    campaign_id,
    channel_id,
    performance_date,
    impressions,
    clicks,
    cost,
    conversions,
    revenue,
    performance_date + INTERVAL '23 hours' AS last_modified_timestamp,
    CURRENT_TIMESTAMP() AS load_timestamp,
    'AD_PLATFORM' AS source_system
FROM (
    SELECT
        (SELECT campaign_id FROM mtln_bronze_campaigns WHERE status IN ('Active', 'Completed') ORDER BY RANDOM() LIMIT 1) AS campaign_id,
        (SELECT channel_id FROM mtln_bronze_channels WHERE category = 'Paid' ORDER BY RANDOM() LIMIT 1) AS channel_id,
        DATEADD(day, -365 + (SEQ4() % 365), CURRENT_DATE())::DATE AS performance_date,
        UNIFORM(10000, 500000, RANDOM()) AS impressions,
        0 AS clicks,
        0 AS cost,
        0 AS conversions,
        0 AS revenue
    FROM TABLE(GENERATOR(ROWCOUNT => 50000))
),
LATERAL (
    SELECT
        ROUND(impressions * UNIFORM(0.01, 0.05, RANDOM())) AS clicks
),
LATERAL (
    SELECT
        ROUND(clicks * UNIFORM(0.50, 5.00, RANDOM()), 2) AS cost
),
LATERAL (
    SELECT
        ROUND(clicks * UNIFORM(0.02, 0.10, RANDOM())) AS conversions
),
LATERAL (
    SELECT
        ROUND(cost * UNIFORM(1.5, 6.0, RANDOM()), 2) AS revenue
);

SELECT 'Performance loaded: ' || COUNT(*) AS status FROM mtln_bronze_performance;

-- ============================================================================
-- SUMMARY
-- ============================================================================

SELECT '========================================' AS summary;
SELECT 'SAMPLE DATA GENERATION COMPLETE' AS summary;
SELECT '========================================' AS summary;

SELECT 'Channels' AS table_name, COUNT(*) AS row_count FROM mtln_bronze_channels
UNION ALL
SELECT 'Campaigns', COUNT(*) FROM mtln_bronze_campaigns
UNION ALL
SELECT 'Customers', COUNT(*) FROM mtln_bronze_customers
UNION ALL
SELECT 'Products', COUNT(*) FROM mtln_bronze_products
UNION ALL
SELECT 'Sales', COUNT(*) FROM mtln_bronze_sales
UNION ALL
SELECT 'Performance', COUNT(*) FROM mtln_bronze_performance
ORDER BY table_name;

SELECT '========================================' AS summary;
SELECT 'Next Steps:' AS summary;
SELECT '1. Run Bronze to Silver transformation pipeline' AS summary;
SELECT '2. Verify Gold layer views reflect data' AS summary;
SELECT '3. Test analytical queries' AS summary;
SELECT '========================================' AS summary;

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================