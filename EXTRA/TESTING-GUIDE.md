# Testing Guide - Sample Data
# Marketing Analytics Data Warehouse

**Status:** Ready to Execute  
**Duration:** 15 minutes total  
**Date:** 2025-12-21

---

## Overview

This guide walks you through testing your marketing analytics data warehouse with sample data - **no pipelines required**.

### What You'll Do

1. ✅ Create Bronze tables (1 min)
2. ✅ Generate 161K sample records (5 min)
3. ✅ Validate data quality (2 min)
4. ✅ Run analytical queries (5 min)
5. ✅ Review results (2 min)

### Prerequisites

- ☑️ Snowflake account access
- ☑️ MTLN_PROD database created
- ☑️ BRONZE schema created
- ☑️ MTLN_ETL_WH warehouse created
- ☑️ Appropriate role (MTLN_ADMIN or ACCOUNTADMIN)

---

## Step 1: Create Bronze Tables (1 min)

### 1.1 Open Snowflake Web UI

1. Navigate to your Snowflake account: `https://<your-account>.snowflakecomputing.com`
2. Login with your credentials
3. Click **Worksheets** in the left navigation
4. Create a new worksheet

### 1.2 Execute DDL Script

**File:** `sql/create-bronze-tables.sql`

1. Copy the **entire contents** of `sql/create-bronze-tables.sql`
2. Paste into Snowflake worksheet
3. Click **Run All** (or press Ctrl+Enter)

**Expected Output:**
```
Table created: mtln_bronze_channels
Table created: mtln_bronze_campaigns
Table created: mtln_bronze_customers
Table created: mtln_bronze_products
Table created: mtln_bronze_sales
Table created: mtln_bronze_performance

BRONZE TABLES CREATED SUCCESSFULLY

[Shows 6 tables listed]
```

### 1.3 Verify Tables Created

```sql
USE DATABASE MTLN_PROD;
USE SCHEMA BRONZE;

SHOW TABLES;
```

**Expected:** 6 tables starting with `MTLN_BRONZE_`

✅ **Checkpoint:** Bronze tables created

---

## Step 2: Generate Sample Data (5 min)

### 2.1 Open New Worksheet

1. Create a new worksheet in Snowflake
2. Name it: "Generate Sample Data"

### 2.2 Execute Generation Script

**File:** `sql/generate-sample-data.sql`

1. Copy the **entire contents** of `sql/generate-sample-data.sql`
2. Paste into worksheet
3. Click **Run All**
4. Wait ~5 minutes (Snowflake will show progress)

**Expected Output:**
```
Channels loaded: 20
Campaigns loaded: 1000
Customers loaded: 10000
Products loaded: 1000
Sales loaded: 100000
Performance loaded: 50000

SAMPLE DATA GENERATION COMPLETE

Table Name          Row Count
─────────────────  ──────────
Channels                   20
Campaigns               1,000
Customers              10,000
Products                1,000
Sales                 100,000
Performance            50,000
```

### 2.3 Quick Verification

```sql
-- Check all tables have data
SELECT 'Channels' AS table_name, COUNT(*) AS rows FROM mtln_bronze_channels
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
```

✅ **Checkpoint:** 161,020 records generated

---

## Step 3: Validate Data Quality (2 min)

### 3.1 Run Validation Script

**File:** `sql/validate-sample-data.sql`

1. Create new worksheet: "Validate Sample Data"
2. Copy **entire contents** of `sql/validate-sample-data.sql`
3. Paste and **Run All**

### 3.2 Review Validation Results

**All checks should show:** ✅ PASS

**Key Validation Sections:**

#### Section 1: Row Counts
```
Layer/Table              Row Count  Expected  Status
─────────────────────  ──────────  ────────  ──────
Bronze - Channels              20        20  ✅ PASS
Bronze - Campaigns          1,000     1,000  ✅ PASS
Bronze - Customers         10,000    10,000  ✅ PASS
Bronze - Products           1,000     1,000  ✅ PASS
Bronze - Sales            100,000   100,000  ✅ PASS
Bronze - Performance       50,000    50,000  ✅ PASS
```

#### Section 2: NULL Checks
```
Check Name                      Null Count  Status
─────────────────────────────  ──────────  ──────
Campaigns - NULL campaign_id            0  ✅ PASS
Customers - NULL customer_id            0  ✅ PASS
Products - NULL product_id              0  ✅ PASS
Sales - NULL order_line_id              0  ✅ PASS
Performance - NULL performance_id       0  ✅ PASS
```

#### Section 3: Referential Integrity
```
Check Name                       Orphan Count  Status
──────────────────────────────  ────────────  ──────
Sales - Orphaned customer_id               0  ✅ PASS
Sales - Orphaned product_id                0  ✅ PASS
Sales - Orphaned campaign_id               0  ✅ PASS
Performance - Orphaned campaign_id         0  ✅ PASS
Performance - Orphaned channel_id          0  ✅ PASS
```

#### Section 4: Business Rules
```
Check Name                           Violation Count  Status
──────────────────────────────────  ───────────────  ──────
Campaigns - Negative budget                       0  ✅ PASS
Campaigns - Invalid date range                    0  ✅ PASS
Products - Non-positive unit_price                0  ✅ PASS
Sales - Non-positive quantity                     0  ✅ PASS
Performance - Clicks > Impressions                0  ✅ PASS
Performance - Conversions > Clicks                0  ✅ PASS
```

### 3.3 Review Data Distribution

**Campaign Status:**
- Active: ~40%
- Completed: ~50%
- Paused: ~5%
- Scheduled: ~5%

**Customer Tiers:**
- Platinum: ~5%
- Gold: ~15%
- Silver: ~30%
- Bronze: ~50%

✅ **Checkpoint:** All validations pass

---

## Step 4: Run Analytical Queries (5 min)

### 4.1 Execute Sample Queries

**File:** `sql/sample-analytical-queries.sql`

1. Create new worksheet: "Analytical Queries"
2. Copy sections you want to test (or entire file)
3. Run queries individually or in groups

### 4.2 Key Queries to Test

#### Query 1: Top 10 Campaigns by ROAS

```sql
SELECT 
    c.campaign_name,
    ch.channel_name,
    ROUND(SUM(p.cost), 2) AS total_cost,
    ROUND(SUM(p.revenue), 2) AS total_revenue,
    ROUND(SUM(p.revenue) / NULLIF(SUM(p.cost), 0), 2) AS roas
FROM BRONZE.mtln_bronze_performance p
JOIN BRONZE.mtln_bronze_campaigns c ON p.campaign_id = c.campaign_id
JOIN BRONZE.mtln_bronze_channels ch ON p.channel_id = ch.channel_id
GROUP BY c.campaign_name, ch.channel_name
HAVING SUM(p.cost) >= 1000
ORDER BY roas DESC
LIMIT 10;
```

**Expected Output:**
- 10 rows showing campaign name, channel, cost, revenue, ROAS
- ROAS values between 1.5 and 6.0
- Execution time: < 5 seconds

#### Query 2: Customer Tier Analysis

```sql
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
```

**Expected Output:**
- 12 rows (4 tiers × 3 segments)
- Platinum customers have highest avg_ltv
- Execution time: < 2 seconds

#### Query 3: Daily Sales Trend (Last 30 Days)

```sql
SELECT 
    order_date,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(quantity) AS units_sold,
    ROUND(SUM(revenue), 2) AS daily_revenue,
    ROUND(AVG(revenue), 2) AS avg_line_value
FROM BRONZE.mtln_bronze_sales
WHERE order_date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY order_date
ORDER BY order_date DESC;
```

**Expected Output:**
- Up to 30 rows (one per day)
- Daily revenue varies by day
- Execution time: < 3 seconds

#### Query 4: Channel Performance Summary

```sql
SELECT 
    ch.channel_name,
    ch.channel_type,
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
```

**Expected Output:**
- ~20 rows (one per channel)
- Email typically has highest ROAS
- Execution time: < 3 seconds

✅ **Checkpoint:** Queries execute successfully with realistic results

---

## Step 5: Review Results (2 min)

### 5.1 Success Criteria

**Data Generation:**
- ✅ All 6 tables populated
- ✅ 161,020 total records
- ✅ No errors during generation

**Data Quality:**
- ✅ All validation checks pass
- ✅ No NULL primary keys
- ✅ No duplicate records
- ✅ No orphaned foreign keys
- ✅ All business rules satisfied

**Query Performance:**
- ✅ Simple queries < 3 seconds
- ✅ Complex joins < 5 seconds
- ✅ All queries return results
- ✅ Results are realistic and consistent

### 5.2 Sample Data Characteristics

**Volume:**
- 20 channels
- 1,000 campaigns
- 10,000 customers
- 1,000 products
- 100,000 sales transactions
- 50,000 performance records

**Date Ranges:**
- Campaigns: 2 years historical + 3 months future
- Sales: Last 12 months
- Performance: Last 12 months

**Realistic Features:**
- Valid foreign key relationships
- Proper data distributions (tiers, segments, statuses)
- Business rule compliance
- Realistic metric values (ROAS, CTR, margins)

---

## What You've Accomplished

✅ **Proven the data model works** - Tables created, data loaded, queries run  
✅ **Validated data quality** - All checks pass  
✅ **Tested analytical capabilities** - Business questions answered  
✅ **Established baseline performance** - Query execution times measured  
✅ **Ready for pipeline development** - Foundation in place

---

## Next Steps

### Option 1: Build Transformation Pipelines

Now that you have Bronze data, build pipelines to:
1. Transform Bronze → Silver (add surrogate keys, cleanse, deduplicate)
2. Create Gold views (star schema)
3. Test end-to-end data flow

### Option 2: Develop More Analytical Queries

Use sample data to:
1. Test additional business questions
2. Build BI dashboards
3. Train business users
4. Document query patterns

### Option 3: Clean Up and Document

1. Document what worked well
2. Note any issues or improvements
3. Clean up sample data (optional)
4. Prepare for production data

---

## Troubleshooting

### Issue: Tables Don't Exist

**Solution:** Re-run `sql/create-bronze-tables.sql`

```sql
-- Check if tables exist
SHOW TABLES IN SCHEMA BRONZE;

-- If missing, run create script again
```

---

### Issue: Data Generation Fails

**Possible Causes:**
1. Warehouse too small
2. Tables not empty (has existing data)
3. Permission issues

**Solution:**

```sql
-- Option 1: Increase warehouse size
ALTER WAREHOUSE MTLN_ETL_WH SET WAREHOUSE_SIZE = 'LARGE';
-- Re-run generation
ALTER WAREHOUSE MTLN_ETL_WH SET WAREHOUSE_SIZE = 'MEDIUM';

-- Option 2: Truncate tables first
TRUNCATE TABLE mtln_bronze_channels;
TRUNCATE TABLE mtln_bronze_campaigns;
TRUNCATE TABLE mtln_bronze_customers;
TRUNCATE TABLE mtln_bronze_products;
TRUNCATE TABLE mtln_bronze_sales;
TRUNCATE TABLE mtln_bronze_performance;
-- Re-run generation

-- Option 3: Check permissions
SHOW GRANTS ON SCHEMA BRONZE;
```

---

### Issue: Validation Checks Fail

**Solution:** Review specific failure

```sql
-- If referential integrity fails, check for orphans
SELECT s.customer_id
FROM mtln_bronze_sales s
LEFT JOIN mtln_bronze_customers c ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL
LIMIT 10;

-- Regenerate data if needed
```

---

### Issue: Queries Too Slow

**Solution:** Add clustering keys

```sql
-- Cluster sales table by date
ALTER TABLE mtln_bronze_sales CLUSTER BY (order_date);

-- Cluster performance table by date
ALTER TABLE mtln_bronze_performance CLUSTER BY (performance_date);

-- Re-run queries
```

---

## Clean Up (Optional)

When done testing:

```sql
USE DATABASE MTLN_PROD;
USE SCHEMA BRONZE;

-- Option 1: Truncate tables (keep structure)
TRUNCATE TABLE mtln_bronze_channels;
TRUNCATE TABLE mtln_bronze_campaigns;
TRUNCATE TABLE mtln_bronze_customers;
TRUNCATE TABLE mtln_bronze_products;
TRUNCATE TABLE mtln_bronze_sales;
TRUNCATE TABLE mtln_bronze_performance;

-- Option 2: Drop tables (remove completely)
DROP TABLE IF EXISTS mtln_bronze_channels;
DROP TABLE IF EXISTS mtln_bronze_campaigns;
DROP TABLE IF EXISTS mtln_bronze_customers;
DROP TABLE IF EXISTS mtln_bronze_products;
DROP TABLE IF EXISTS mtln_bronze_sales;
DROP TABLE IF EXISTS mtln_bronze_performance;
```

---

## Additional Resources

- **[README.md](./README.md)** - Project overview
- **[SAMPLE-DATA-GUIDE.md](./SAMPLE-DATA-GUIDE.md)** - Detailed sample data documentation
- **[data-dictionary.md](./data-dictionary.md)** - Complete schema reference
- **[ARCHITECTURE-LLD.md](./ARCHITECTURE-LLD.md)** - Technical specifications

---

## Quick Reference Commands

```sql
-- Check table row counts
SELECT 'Channels', COUNT(*) FROM mtln_bronze_channels
UNION ALL SELECT 'Campaigns', COUNT(*) FROM mtln_bronze_campaigns
UNION ALL SELECT 'Customers', COUNT(*) FROM mtln_bronze_customers
UNION ALL SELECT 'Products', COUNT(*) FROM mtln_bronze_products
UNION ALL SELECT 'Sales', COUNT(*) FROM mtln_bronze_sales
UNION ALL SELECT 'Performance', COUNT(*) FROM mtln_bronze_performance;

-- View sample records
SELECT * FROM mtln_bronze_campaigns LIMIT 5;
SELECT * FROM mtln_bronze_customers LIMIT 5;
SELECT * FROM mtln_bronze_sales LIMIT 5;

-- Check data freshness
SELECT MAX(load_timestamp) FROM mtln_bronze_sales;

-- View table details
DESC TABLE mtln_bronze_sales;
```

---

**Document Version:** 1.0  
**Last Updated:** 2025-12-21  
**Status:** ✅ Ready to Execute

**Estimated Time:** 15 minutes total  
**Difficulty:** Beginner  
**Prerequisites:** Snowflake access only

---

*Ready to start? Begin with Step 1: Create Bronze Tables*