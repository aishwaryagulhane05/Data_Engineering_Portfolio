-- ============================================================================
-- SAMPLE ANALYTICAL QUERIES
-- Marketing Analytics Data Warehouse - Gold Layer
-- ============================================================================
-- Purpose: Test Gold layer views with realistic analytical queries
-- Target Users: Business analysts, data scientists, executives
-- Complexity: Beginner to Advanced
-- ============================================================================

USE ROLE MTLN_REPORTING_ROLE;
USE WAREHOUSE MTLN_REPORTING_WH;
USE DATABASE MTLN_PROD;
USE SCHEMA GOLD;

-- ============================================================================
-- SECTION 1: CAMPAIGN PERFORMANCE
-- ============================================================================

-- Query 1.1: Top 10 Campaigns by ROAS (Last 90 Days)
-- Business Question: Which campaigns deliver the best return on ad spend?

SELECT 
    c.campaign_name,
    c.campaign_type,
    ch.channel_name,
    SUM(f.impressions) AS total_impressions,
    SUM(f.clicks) AS total_clicks,
    ROUND(SUM(f.cost), 2) AS total_cost,
    ROUND(SUM(f.revenue), 2) AS total_revenue,
    ROUND(SUM(f.revenue) / NULLIF(SUM(f.cost), 0), 2) AS roas,
    ROUND(SUM(f.clicks) * 100.0 / NULLIF(SUM(f.impressions), 0), 2) AS ctr_percent
FROM mtln_fact_performance f
JOIN mtln_dim_campaign c ON f.dim_campaign_sk = c.dim_campaign_sk
JOIN mtln_dim_channel ch ON f.dim_channel_sk = ch.dim_channel_sk
JOIN mtln_dim_date d ON f.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY c.campaign_name, c.campaign_type, ch.channel_name
HAVING SUM(f.cost) >= 1000  -- Minimum $1K spend
ORDER BY roas DESC
LIMIT 10;

-- Query 1.2: Campaign Budget vs Actual Spend
-- Business Question: Are campaigns on track with budget?

SELECT 
    c.campaign_name,
    c.campaign_budget,
    c.campaign_start_date,
    c.campaign_end_date,
    c.campaign_duration_days,
    DATEDIFF(day, c.campaign_start_date, CURRENT_DATE()) AS days_elapsed,
    ROUND(SUM(f.cost), 2) AS actual_spend,
    ROUND((SUM(f.cost) / c.campaign_budget) * 100, 2) AS spend_percent,
    ROUND(c.campaign_budget - SUM(f.cost), 2) AS remaining_budget,
    CASE 
        WHEN SUM(f.cost) > c.campaign_budget * 1.1 THEN '🔴 Over Budget'
        WHEN SUM(f.cost) < c.campaign_budget * 0.5 AND c.campaign_period_status = 'Current' THEN '🟡 Under Pacing'
        WHEN c.campaign_period_status = 'Current' THEN '🟢 On Track'
        ELSE '⚪ Ended'
    END AS status
FROM mtln_dim_campaign c
LEFT JOIN mtln_fact_performance f ON c.dim_campaign_sk = f.dim_campaign_sk
WHERE c.campaign_period_status IN ('Current', 'Past')
GROUP BY 
    c.campaign_name, c.campaign_budget, c.campaign_start_date, 
    c.campaign_end_date, c.campaign_duration_days, c.campaign_period_status
ORDER BY actual_spend DESC
LIMIT 20;

-- Query 1.3: Campaign Performance Trend (Week over Week)
-- Business Question: How are campaigns trending?

SELECT 
    c.campaign_name,
    d.year,
    d.week,
    d.month_name,
    COUNT(DISTINCT f.dim_date_sk) AS days_active,
    SUM(f.impressions) AS weekly_impressions,
    SUM(f.clicks) AS weekly_clicks,
    ROUND(SUM(f.cost), 2) AS weekly_cost,
    ROUND(SUM(f.revenue), 2) AS weekly_revenue,
    ROUND(SUM(f.revenue) / NULLIF(SUM(f.cost), 0), 2) AS weekly_roas
FROM mtln_fact_performance f
JOIN mtln_dim_campaign c ON f.dim_campaign_sk = c.dim_campaign_sk
JOIN mtln_dim_date d ON f.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(day, -60, CURRENT_DATE())
GROUP BY c.campaign_name, d.year, d.week, d.month_name
ORDER BY c.campaign_name, d.year, d.week DESC;

-- ============================================================================
-- SECTION 2: CHANNEL OPTIMIZATION
-- ============================================================================

-- Query 2.1: Channel Performance Comparison
-- Business Question: Which channels drive the best results?

SELECT 
    ch.channel_name,
    ch.channel_type,
    ch.channel_category,
    ch.channel_classification,
    COUNT(DISTINCT f.dim_campaign_sk) AS unique_campaigns,
    SUM(f.impressions) AS total_impressions,
    SUM(f.clicks) AS total_clicks,
    ROUND(SUM(f.clicks) * 100.0 / NULLIF(SUM(f.impressions), 0), 2) AS avg_ctr,
    ROUND(SUM(f.cost), 2) AS total_cost,
    ROUND(SUM(f.cost) / NULLIF(SUM(f.clicks), 0), 2) AS avg_cpc,
    ROUND(SUM(f.revenue), 2) AS total_revenue,
    ROUND(SUM(f.revenue) / NULLIF(SUM(f.cost), 0), 2) AS roas
FROM mtln_fact_performance f
JOIN mtln_dim_channel ch ON f.dim_channel_sk = ch.dim_channel_sk
GROUP BY ch.channel_name, ch.channel_type, ch.channel_category, ch.channel_classification
ORDER BY roas DESC;

-- Query 2.2: Channel Mix Over Time
-- Business Question: How is our channel mix evolving?

SELECT 
    d.year,
    d.month,
    d.month_name,
    ch.channel_name,
    ROUND(SUM(f.cost), 2) AS monthly_spend,
    ROUND(SUM(f.cost) * 100.0 / SUM(SUM(f.cost)) OVER (PARTITION BY d.year, d.month), 2) AS spend_share_percent
FROM mtln_fact_performance f
JOIN mtln_dim_channel ch ON f.dim_channel_sk = ch.dim_channel_sk
JOIN mtln_dim_date d ON f.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(month, -6, CURRENT_DATE())
GROUP BY d.year, d.month, d.month_name, ch.channel_name
ORDER BY d.year DESC, d.month DESC, monthly_spend DESC;

-- Query 2.3: Best Channel by Campaign Type
-- Business Question: Which channels work best for each campaign type?

SELECT 
    c.campaign_type,
    ch.channel_name,
    COUNT(DISTINCT f.dim_campaign_sk) AS campaign_count,
    ROUND(SUM(f.cost), 2) AS total_cost,
    ROUND(SUM(f.revenue), 2) AS total_revenue,
    ROUND(SUM(f.revenue) / NULLIF(SUM(f.cost), 0), 2) AS roas,
    RANK() OVER (PARTITION BY c.campaign_type ORDER BY SUM(f.revenue) / NULLIF(SUM(f.cost), 0) DESC) AS roas_rank
FROM mtln_fact_performance f
JOIN mtln_dim_campaign c ON f.dim_campaign_sk = c.dim_campaign_sk
JOIN mtln_dim_channel ch ON f.dim_channel_sk = ch.dim_channel_sk
GROUP BY c.campaign_type, ch.channel_name
QUALIFY roas_rank <= 3  -- Top 3 channels per campaign type
ORDER BY c.campaign_type, roas_rank;

-- ============================================================================
-- SECTION 3: CUSTOMER ANALYTICS
-- ============================================================================

-- Query 3.1: Customer Segmentation Overview
-- Business Question: How are customers distributed across segments?

SELECT 
    customer_segment,
    customer_tier,
    value_category,
    COUNT(*) AS customer_count,
    ROUND(AVG(customer_lifetime_value), 2) AS avg_ltv,
    ROUND(SUM(customer_lifetime_value), 2) AS total_ltv,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_percent,
    ROUND(SUM(customer_lifetime_value) * 100.0 / SUM(SUM(customer_lifetime_value)) OVER (), 2) AS ltv_percent
FROM mtln_dim_customer
WHERE is_active_customer = TRUE
GROUP BY customer_segment, customer_tier, value_category
ORDER BY total_ltv DESC;

-- Query 3.2: Top Customers by Revenue (Last 12 Months)
-- Business Question: Who are our most valuable customers?

SELECT 
    c.customer_name,
    c.customer_email,
    c.customer_segment,
    c.customer_tier,
    c.customer_lifetime_value,
    COUNT(DISTINCT f.order_id) AS orders_12mo,
    SUM(f.quantity) AS units_purchased,
    ROUND(SUM(f.revenue), 2) AS revenue_12mo,
    ROUND(AVG(f.revenue), 2) AS avg_order_value
FROM mtln_fact_sales f
JOIN mtln_dim_customer c ON f.dim_customer_sk = c.dim_customer_sk
JOIN mtln_dim_date d ON f.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(month, -12, CURRENT_DATE())
GROUP BY 
    c.customer_name, c.customer_email, c.customer_segment, 
    c.customer_tier, c.customer_lifetime_value
ORDER BY revenue_12mo DESC
LIMIT 20;

-- Query 3.3: Customer Purchase Patterns by Tier
-- Business Question: How do purchase patterns differ by customer tier?

SELECT 
    c.customer_tier,
    c.tier_rank,
    COUNT(DISTINCT c.dim_customer_sk) AS unique_customers,
    COUNT(DISTINCT f.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT f.order_id) * 1.0 / NULLIF(COUNT(DISTINCT c.dim_customer_sk), 0), 2) AS orders_per_customer,
    ROUND(AVG(f.revenue), 2) AS avg_order_value,
    ROUND(SUM(f.revenue), 2) AS total_revenue,
    ROUND(SUM(f.revenue) / NULLIF(COUNT(DISTINCT c.dim_customer_sk), 0), 2) AS revenue_per_customer
FROM mtln_fact_sales f
JOIN mtln_dim_customer c ON f.dim_customer_sk = c.dim_customer_sk
GROUP BY c.customer_tier, c.tier_rank
ORDER BY c.tier_rank;

-- ============================================================================
-- SECTION 4: PRODUCT PERFORMANCE
-- ============================================================================

-- Query 4.1: Top Products by Revenue
-- Business Question: What are our best-selling products?

SELECT 
    p.product_name,
    p.product_category,
    p.product_brand,
    p.margin_category,
    p.price_tier,
    COUNT(DISTINCT f.order_id) AS times_ordered,
    SUM(f.quantity) AS units_sold,
    ROUND(AVG(f.unit_price), 2) AS avg_selling_price,
    ROUND(SUM(f.revenue), 2) AS total_revenue,
    ROUND(SUM(f.revenue) / NULLIF(SUM(f.quantity), 0), 2) AS revenue_per_unit
FROM mtln_fact_sales f
JOIN mtln_dim_product p ON f.dim_product_sk = p.dim_product_sk
GROUP BY 
    p.product_name, p.product_category, p.product_brand, 
    p.margin_category, p.price_tier
ORDER BY total_revenue DESC
LIMIT 20;

-- Query 4.2: Product Category Analysis
-- Business Question: Which categories drive the most revenue?

SELECT 
    p.product_category,
    COUNT(DISTINCT p.dim_product_sk) AS unique_products,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.revenue), 2) AS total_revenue,
    ROUND(AVG(f.revenue), 2) AS avg_order_line_value,
    ROUND(SUM(f.revenue) * 100.0 / SUM(SUM(f.revenue)) OVER (), 2) AS revenue_percent
FROM mtln_fact_sales f
JOIN mtln_dim_product p ON f.dim_product_sk = p.dim_product_sk
GROUP BY p.product_category
ORDER BY total_revenue DESC;

-- Query 4.3: High Margin vs High Volume Products
-- Business Question: Should we promote high-margin or high-volume products?

SELECT 
    p.product_name,
    p.margin_category,
    p.product_margin_percent,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.revenue), 2) AS total_revenue,
    ROUND(SUM(f.revenue) - SUM(f.quantity * p.product_cost), 2) AS gross_profit,
    CASE 
        WHEN p.product_margin_percent >= 40 AND SUM(f.quantity) >= 100 THEN '🟢 Star Product'
        WHEN p.product_margin_percent >= 40 THEN '🟡 High Margin, Low Volume'
        WHEN SUM(f.quantity) >= 100 THEN '🟠 Low Margin, High Volume'
        ELSE '⚪ Average'
    END AS product_classification
FROM mtln_fact_sales f
JOIN mtln_dim_product p ON f.dim_product_sk = p.dim_product_sk
GROUP BY 
    p.product_name, p.margin_category, p.product_margin_percent, p.product_cost
HAVING SUM(f.quantity) > 0
ORDER BY gross_profit DESC
LIMIT 30;

-- ============================================================================
-- SECTION 5: SALES TRENDS
-- ============================================================================

-- Query 5.1: Daily Sales Performance (Last 30 Days)
-- Business Question: What are our recent sales trends?

SELECT 
    d.full_date,
    d.day_name,
    d.is_weekend,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(*) AS total_line_items,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.revenue), 2) AS daily_revenue,
    ROUND(AVG(f.revenue), 2) AS avg_line_value,
    ROUND(SUM(f.revenue) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2) AS avg_order_value
FROM mtln_fact_sales f
JOIN mtln_dim_date d ON f.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY d.full_date, d.day_name, d.is_weekend
ORDER BY d.full_date DESC;

-- Query 5.2: Monthly Sales Summary with YoY Comparison
-- Business Question: How do current sales compare to last year?

WITH monthly_sales AS (
    SELECT 
        d.year,
        d.month,
        d.month_name,
        COUNT(DISTINCT f.order_id) AS orders,
        ROUND(SUM(f.revenue), 2) AS revenue
    FROM mtln_fact_sales f
    JOIN mtln_dim_date d ON f.dim_date_sk = d.date_key
    GROUP BY d.year, d.month, d.month_name
)
SELECT 
    curr.year AS current_year,
    curr.month,
    curr.month_name,
    curr.orders AS current_orders,
    curr.revenue AS current_revenue,
    LAG(curr.orders, 12) OVER (ORDER BY curr.year, curr.month) AS prior_year_orders,
    LAG(curr.revenue, 12) OVER (ORDER BY curr.year, curr.month) AS prior_year_revenue,
    curr.orders - LAG(curr.orders, 12) OVER (ORDER BY curr.year, curr.month) AS orders_yoy_change,
    ROUND(curr.revenue - LAG(curr.revenue, 12) OVER (ORDER BY curr.year, curr.month), 2) AS revenue_yoy_change,
    ROUND(
        (curr.revenue - LAG(curr.revenue, 12) OVER (ORDER BY curr.year, curr.month)) * 100.0 / 
        NULLIF(LAG(curr.revenue, 12) OVER (ORDER BY curr.year, curr.month), 0), 2
    ) AS revenue_yoy_growth_percent
FROM monthly_sales curr
ORDER BY curr.year DESC, curr.month DESC;

-- Query 5.3: Weekday vs Weekend Performance
-- Business Question: Should we focus marketing efforts on specific days?

SELECT 
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    d.day_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    ROUND(SUM(f.revenue), 2) AS total_revenue,
    ROUND(AVG(f.revenue), 2) AS avg_line_value,
    ROUND(COUNT(DISTINCT f.order_id) * 100.0 / SUM(COUNT(DISTINCT f.order_id)) OVER (), 2) AS order_percent,
    ROUND(SUM(f.revenue) * 100.0 / SUM(SUM(f.revenue)) OVER (), 2) AS revenue_percent
FROM mtln_fact_sales f
JOIN mtln_dim_date d ON f.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY d.is_weekend, d.day_name
ORDER BY 
    CASE WHEN d.is_weekend THEN 2 ELSE 1 END,
    CASE d.day_name
        WHEN 'Monday' THEN 1
        WHEN 'Tuesday' THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4
        WHEN 'Friday' THEN 5
        WHEN 'Saturday' THEN 6
        WHEN 'Sunday' THEN 7
    END;

-- ============================================================================
-- SECTION 6: EXECUTIVE DASHBOARD QUERIES
-- ============================================================================

-- Query 6.1: Executive Summary - Last 30 Days
-- Business Question: What are our key metrics at a glance?

SELECT 
    'MARKETING PERFORMANCE' AS metric_category,
    SUM(f.impressions) AS total_impressions,
    SUM(f.clicks) AS total_clicks,
    ROUND(SUM(f.clicks) * 100.0 / NULLIF(SUM(f.impressions), 0), 2) AS overall_ctr,
    ROUND(SUM(f.cost), 2) AS marketing_spend,
    SUM(f.conversions) AS total_conversions,
    ROUND(SUM(f.cost) / NULLIF(SUM(f.conversions), 0), 2) AS cost_per_conversion,
    ROUND(SUM(f.revenue), 2) AS marketing_revenue,
    ROUND(SUM(f.revenue) / NULLIF(SUM(f.cost), 0), 2) AS roas
FROM mtln_fact_performance f
JOIN mtln_dim_date d ON f.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(day, -30, CURRENT_DATE())

UNION ALL

SELECT 
    'SALES PERFORMANCE' AS metric_category,
    COUNT(DISTINCT s.order_id) AS total_orders,
    COUNT(*) AS total_line_items,
    NULL AS ctr,
    NULL AS marketing_spend,
    NULL AS conversions,
    NULL AS cost_per_conversion,
    ROUND(SUM(s.revenue), 2) AS total_revenue,
    ROUND(SUM(s.revenue) / NULLIF(COUNT(DISTINCT s.order_id), 0), 2) AS avg_order_value
FROM mtln_fact_sales s
JOIN mtln_dim_date d ON s.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(day, -30, CURRENT_DATE());

-- Query 6.2: Top 5 of Everything
-- Business Question: What are our top performers across all dimensions?

-- Top 5 Campaigns
SELECT 'Top 5 Campaigns by ROAS' AS category, campaign_name AS name, roas AS metric
FROM (
    SELECT 
        c.campaign_name,
        ROUND(SUM(f.revenue) / NULLIF(SUM(f.cost), 0), 2) AS roas
    FROM mtln_fact_performance f
    JOIN mtln_dim_campaign c ON f.dim_campaign_sk = c.dim_campaign_sk
    GROUP BY c.campaign_name
    ORDER BY roas DESC
    LIMIT 5
)

UNION ALL

-- Top 5 Channels
SELECT 'Top 5 Channels by Revenue' AS category, channel_name AS name, total_revenue AS metric
FROM (
    SELECT 
        ch.channel_name,
        ROUND(SUM(f.revenue), 2) AS total_revenue
    FROM mtln_fact_performance f
    JOIN mtln_dim_channel ch ON f.dim_channel_sk = ch.dim_channel_sk
    GROUP BY ch.channel_name
    ORDER BY total_revenue DESC
    LIMIT 5
)

UNION ALL

-- Top 5 Products
SELECT 'Top 5 Products by Revenue' AS category, product_name AS name, total_revenue AS metric
FROM (
    SELECT 
        p.product_name,
        ROUND(SUM(f.revenue), 2) AS total_revenue
    FROM mtln_fact_sales f
    JOIN mtln_dim_product p ON f.dim_product_sk = p.dim_product_sk
    GROUP BY p.product_name
    ORDER BY total_revenue DESC
    LIMIT 5
)

UNION ALL

-- Top 5 Customers
SELECT 'Top 5 Customers by Revenue' AS category, customer_name AS name, total_revenue AS metric
FROM (
    SELECT 
        c.customer_name,
        ROUND(SUM(f.revenue), 2) AS total_revenue
    FROM mtln_fact_sales f
    JOIN mtln_dim_customer c ON f.dim_customer_sk = c.dim_customer_sk
    GROUP BY c.customer_name
    ORDER BY total_revenue DESC
    LIMIT 5
)

ORDER BY category, metric DESC;

-- ============================================================================
-- END OF SAMPLE QUERIES
-- ============================================================================

SELECT '========================================' AS summary;
SELECT 'SAMPLE QUERIES COMPLETE' AS summary;
SELECT '========================================' AS summary;
SELECT 'All queries executed successfully' AS summary;
SELECT 'Results demonstrate Gold layer functionality' AS summary;
SELECT 'Use these as templates for custom analysis' AS summary;
SELECT '========================================' AS summary;