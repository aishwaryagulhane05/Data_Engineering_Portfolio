# Sample Data Guide
# Marketing Analytics Data Warehouse

**Purpose:** Guide for generating and using sample data for testing  
**Created:** 2025-12-21  
**Status:** Ready to Use

---

## Overview

This guide explains how to generate realistic sample data for testing your marketing analytics data warehouse before connecting to production sources.

### What's Included

**Sample Data Scripts:**
- `sql/generate-sample-data.sql` - Generates 161,020 sample records
- `sql/validate-sample-data.sql` - Validates data quality and relationships

**Sample Data Volume:**

| Entity | Records | Description |
|--------|---------|-------------|
| Channels | 20 | Marketing channels (email, paid search, social, etc.) |
| Campaigns | 1,000 | Marketing campaigns over 2 years |
| Customers | 10,000 | Customer profiles with segments and tiers |
| Products | 1,000 | Product catalog with pricing and margins |
| Sales | 100,000 | Order line items over 12 months |
| Performance | 50,000 | Daily campaign performance metrics |
| **Total** | **161,020** | **~50 MB compressed** |

---

## Quick Start

### Step 1: Prerequisites

✅ Bronze tables created (run DDL pipeline first)  
✅ Snowflake connection with MTLN_ETL_ROLE  
✅ 5 minutes execution time

### Step 2: Generate Sample Data

```sql
-- Execute in Snowflake (5 minutes)
USE ROLE MTLN_ETL_ROLE;
USE WAREHOUSE MTLN_ETL_WH;
USE DATABASE MTLN_PROD;

-- Copy/paste entire sql/generate-sample-data.sql
-- OR execute via SnowSQL:
-- snowsql -f sql/generate-sample-data.sql
```

**Expected Output:**
```
Channels loaded: 20
Campaigns loaded: 1000
Customers loaded: 10000
Products loaded: 1000
Sales loaded: 100000
Performance loaded: 50000
```

### Step 3: Validate Data

```sql
-- Execute in Snowflake (2 minutes)
USE ROLE MTLN_REPORTING_ROLE;
USE WAREHOUSE MTLN_REPORTING_WH;

-- Copy/paste entire sql/validate-sample-data.sql
```

**Expected:** All checks show ✅ PASS

### Step 4: Test Pipelines

1. **Bronze → Silver:** Run transformation pipeline
2. **Silver → Gold:** Views automatically updated
3. **Query Gold Layer:** Test analytical queries

---

## Data Characteristics

### Realistic Features

**Campaigns:**
- Mix of statuses: Active (40%), Completed (50%), Paused (5%), Scheduled (5%)
- Date range: 2 years historical + 3 months future
- Budget range: $10K - $200K
- Multiple types: Brand, Performance, Retargeting, Product Launch, Seasonal

**Customers:**
- Segments: Enterprise (33%), SMB (33%), Consumer (34%)
- Tiers: Platinum (5%), Gold (15%), Silver (30%), Bronze (50%)
- Status: Active (85%), Inactive (10%), Churned (5%)
- LTV range: $100 - $100K (tier-based distribution)

**Products:**
- Categories: Electronics, Apparel, Home & Garden, Gadgets, Tools
- Price range: $19.99 - $599.99
- Margins: 25% - 65%
- Status: 95% Active, 5% Discontinued

**Sales:**
- Date range: Last 12 months
- Order patterns: 1-3 line items per order (70% single-item)
- Discounts: 30% of orders have discounts (5-15%)
- Tax rate: 8%
- Seasonality: Random distribution (can enhance if needed)

**Performance:**
- Date range: Last 12 months
- Impressions: 10K - 500K per day
- CTR: 1% - 5%
- CPC: $0.50 - $5.00
- Conversion rate: 2% - 10% of clicks
- ROAS: 1.5:1 to 6.0:1

**Relationships:**
- All foreign keys valid (referential integrity maintained)
- Sales linked to active campaigns
- Performance only for paid channels
- No orphaned records

---

## Sample Queries

### Basic Verification

```sql
-- Check all tables populated
USE DATABASE MTLN_PROD;

SELECT 'Bronze - Channels' AS table_name, COUNT(*) AS rows FROM BRONZE.mtln_bronze_channels
UNION ALL
SELECT 'Bronze - Campaigns', COUNT(*) FROM BRONZE.mtln_bronze_campaigns
UNION ALL
SELECT 'Bronze - Customers', COUNT(*) FROM BRONZE.mtln_bronze_customers
UNION ALL
SELECT 'Bronze - Products', COUNT(*) FROM BRONZE.mtln_bronze_products
UNION ALL
SELECT 'Bronze - Sales', COUNT(*) FROM BRONZE.mtln_bronze_sales
UNION ALL
SELECT 'Bronze - Performance', COUNT(*) FROM BRONZE.mtln_bronze_performance
ORDER BY table_name;
```

### Campaign Analysis

```sql
-- Top 10 campaigns by budget
SELECT 
    campaign_name,
    campaign_type,
    status,
    budget,
    start_date,
    end_date,
    DATEDIFF(day, start_date, end_date) AS duration_days
FROM BRONZE.mtln_bronze_campaigns
ORDER BY budget DESC
LIMIT 10;

-- Campaign status distribution
SELECT 
    status,
    COUNT(*) AS campaign_count,
    SUM(budget) AS total_budget,
    ROUND(AVG(budget), 2) AS avg_budget
FROM BRONZE.mtln_bronze_campaigns
GROUP BY status
ORDER BY campaign_count DESC;
```

### Customer Segmentation

```sql
-- Customer tier analysis
SELECT 
    tier,
    segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(lifetime_value), 2) AS avg_ltv,
    ROUND(SUM(lifetime_value), 2) AS total_ltv
FROM BRONZE.mtln_bronze_customers
WHERE status = 'Active'
GROUP BY tier, segment
ORDER BY avg_ltv DESC;

-- Top 20 customers by LTV
SELECT 
    customer_name,
    email,
    segment,
    tier,
    lifetime_value
FROM BRONZE.mtln_bronze_customers
ORDER BY lifetime_value DESC
LIMIT 20;
```

### Product Performance

```sql
-- Top 10 products by margin percentage
SELECT 
    product_name,
    category,
    brand,
    unit_price,
    cost,
    margin,
    margin_percent
FROM BRONZE.mtln_bronze_products
WHERE product_status = 'Active'
ORDER BY margin_percent DESC
LIMIT 10;

-- Category profitability
SELECT 
    category,
    COUNT(*) AS product_count,
    ROUND(AVG(unit_price), 2) AS avg_price,
    ROUND(AVG(margin_percent), 2) AS avg_margin_pct
FROM BRONZE.mtln_bronze_products
WHERE product_status = 'Active'
GROUP BY category
ORDER BY avg_margin_pct DESC;
```

### Sales Analysis

```sql
-- Daily sales trend (last 30 days)
SELECT 
    order_date,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(*) AS total_line_items,
    SUM(quantity) AS total_units,
    ROUND(SUM(revenue), 2) AS total_revenue,
    ROUND(AVG(revenue), 2) AS avg_line_value
FROM BRONZE.mtln_bronze_sales
WHERE order_date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY order_date
ORDER BY order_date DESC;

-- Top selling products
SELECT 
    s.product_id,
    p.product_name,
    p.category,
    COUNT(*) AS order_count,
    SUM(s.quantity) AS total_quantity,
    ROUND(SUM(s.revenue), 2) AS total_revenue
FROM BRONZE.mtln_bronze_sales s
JOIN BRONZE.mtln_bronze_products p ON s.product_id = p.product_id
GROUP BY s.product_id, p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 10;
```

### Marketing Performance

```sql
-- Channel performance summary
SELECT 
    ch.channel_name,
    ch.channel_type,
    COUNT(*) AS days_active,
    SUM(p.impressions) AS total_impressions,
    SUM(p.clicks) AS total_clicks,
    ROUND(SUM(p.clicks) * 100.0 / NULLIF(SUM(p.impressions), 0), 2) AS ctr,
    ROUND(SUM(p.cost), 2) AS total_cost,
    ROUND(SUM(p.revenue), 2) AS total_revenue,
    ROUND(SUM(p.revenue) / NULLIF(SUM(p.cost), 0), 2) AS roas
FROM BRONZE.mtln_bronze_performance p
JOIN BRONZE.mtln_bronze_channels ch ON p.channel_id = ch.channel_id
GROUP BY ch.channel_name, ch.channel_type
ORDER BY roas DESC;

-- Best performing campaigns (by ROAS)
SELECT 
    c.campaign_name,
    c.campaign_type,
    COUNT(*) AS days_running,
    SUM(p.cost) AS total_cost,
    SUM(p.revenue) AS total_revenue,
    ROUND(SUM(p.revenue) / NULLIF(SUM(p.cost), 0), 2) AS roas
FROM BRONZE.mtln_bronze_performance p
JOIN BRONZE.mtln_bronze_campaigns c ON p.campaign_id = c.campaign_id
GROUP BY c.campaign_name, c.campaign_type
HAVING SUM(p.cost) > 1000  -- Min $1K spend
ORDER BY roas DESC
LIMIT 10;
```

---

## Testing Scenarios

### Scenario 1: End-to-End Pipeline Test

**Objective:** Verify complete data flow from Bronze → Silver → Gold

**Steps:**
1. Generate sample data in Bronze tables
2. Run Bronze → Silver transformation pipeline
3. Verify Silver tables have surrogate keys
4. Query Gold views
5. Validate row counts match across layers

**Success Criteria:**
- All pipelines execute without errors
- Row counts consistent (Bronze ≈ Silver ≈ Gold dimensions)
- Gold views return results
- Surrogate keys generated properly

---

### Scenario 2: Incremental Load Test

**Objective:** Test incremental loading logic

**Steps:**
1. Load initial dataset to Bronze
2. Run Bronze → Silver (initial load)
3. Note max(load_timestamp) in Silver
4. Add new records to Bronze with later timestamps
5. Run Bronze → Silver (incremental)
6. Verify only new records processed

**Success Criteria:**
- Incremental load processes only new/changed records
- No duplicates in Silver layer
- High water mark advances correctly

---

### Scenario 3: Data Quality Validation

**Objective:** Verify data quality rules enforced

**Steps:**
1. Run `validate-sample-data.sql`
2. All checks should show ✅ PASS
3. Intentionally break a rule (e.g., set clicks > impressions)
4. Re-run validation
5. Verify check catches violation

**Success Criteria:**
- All baseline checks pass
- Validation catches intentional violations
- Business rules enforced in Silver layer

---

### Scenario 4: Analytical Query Performance

**Objective:** Measure query response times

**Steps:**
1. Run sample queries from README
2. Note execution times
3. Apply clustering keys on Silver tables
4. Re-run queries
5. Measure improvement

**Success Criteria:**
- Baseline queries < 5 seconds on 100K+ rows
- Clustering improves performance 50-80%
- Complex joins < 30 seconds

---

## Customizing Sample Data

### Adjust Volume

Edit `GENERATOR(ROWCOUNT => N)` in generate-sample-data.sql:

```sql
-- Default: 1,000 campaigns
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- Increase to 5,000 campaigns
FROM TABLE(GENERATOR(ROWCOUNT => 5000));
```

### Adjust Date Ranges

Modify `DATEADD` functions:

```sql
-- Default: Last 12 months
DATEADD(day, -365 + (SEQ4() % 365), CURRENT_DATE())

-- Change to last 24 months
DATEADD(day, -730 + (SEQ4() % 730), CURRENT_DATE())
```

### Add Seasonality

Enhance sales generation with seasonal patterns:

```sql
-- Add 50% boost for Q4 (holiday season)
CASE 
    WHEN MONTH(order_date) IN (11, 12) THEN revenue * 1.5
    ELSE revenue
END AS adjusted_revenue
```

---

## Cleaning Up Sample Data

### Remove Sample Data

```sql
USE ROLE MTLN_ETL_ROLE;
USE DATABASE MTLN_PROD;

-- Truncate all Bronze tables
TRUNCATE TABLE BRONZE.mtln_bronze_channels;
TRUNCATE TABLE BRONZE.mtln_bronze_campaigns;
TRUNCATE TABLE BRONZE.mtln_bronze_customers;
TRUNCATE TABLE BRONZE.mtln_bronze_products;
TRUNCATE TABLE BRONZE.mtln_bronze_sales;
TRUNCATE TABLE BRONZE.mtln_bronze_performance;

-- Truncate all Silver tables
TRUNCATE TABLE SILVER.mtln_ods_channels;
TRUNCATE TABLE SILVER.mtln_ods_campaigns;
TRUNCATE TABLE SILVER.mtln_ods_customers;
TRUNCATE TABLE SILVER.mtln_ods_products;
TRUNCATE TABLE SILVER.mtln_ods_sales;
TRUNCATE TABLE SILVER.mtln_ods_performance;

-- Reset sequences
ALTER SEQUENCE SILVER.mtln_ods_campaigns_seq RESTART WITH 1;
ALTER SEQUENCE SILVER.mtln_ods_customers_seq RESTART WITH 1;
ALTER SEQUENCE SILVER.mtln_ods_products_seq RESTART WITH 1;
ALTER SEQUENCE SILVER.mtln_ods_sales_seq RESTART WITH 1;
ALTER SEQUENCE SILVER.mtln_ods_performance_seq RESTART WITH 1;
ALTER SEQUENCE SILVER.mtln_ods_channels_seq RESTART WITH 1;

-- Gold views will automatically be empty (they're views)
```

---

## Troubleshooting

### Issue: Script Times Out

**Solution:** Increase warehouse size temporarily

```sql
ALTER WAREHOUSE MTLN_ETL_WH SET WAREHOUSE_SIZE = 'LARGE';
-- Run generation script
ALTER WAREHOUSE MTLN_ETL_WH SET WAREHOUSE_SIZE = 'MEDIUM';
```

---

### Issue: Referential Integrity Errors

**Solution:** Ensure generation order

1. Channels (no dependencies)
2. Campaigns (no dependencies)
3. Customers (no dependencies)
4. Products (no dependencies)
5. Sales (depends on Campaigns, Customers, Products)
6. Performance (depends on Campaigns, Channels)

---

### Issue: Duplicate Keys

**Solution:** Truncate and regenerate

```sql
TRUNCATE TABLE BRONZE.mtln_bronze_<table>;
-- Re-run generation for that table only
```

---

## Next Steps

After successfully generating and validating sample data:

1. ✅ **Build transformation pipelines** - Bronze → Silver → Gold
2. ✅ **Test analytical queries** - Verify Gold layer usability
3. ✅ **Measure performance** - Baseline query times
4. ✅ **Document findings** - Note any issues or optimizations
5. ✅ **Clean up** - Remove sample data before production

---

## Additional Resources

- [README.md](./README.md) - Project overview
- [data-dictionary.md](./data-dictionary.md) - Complete schema documentation
- [deployment-guide.md](./deployment-guide.md) - Production deployment steps
- [ARCHITECTURE-LLD.md](./ARCHITECTURE-LLD.md) - Technical implementation details

---

**Document Version:** 1.0  
**Last Updated:** 2025-12-21  
**Status:** ✅ Ready to Use

---

*For questions or issues, contact the data engineering team.*