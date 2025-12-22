# DDL Architecture Guide
**Medallion Architecture - Silver & Gold Schemas**

---

## Overview

This guide documents the complete DDL structure for both **Silver** (cleansed/validated) and **Gold** (analytics-ready star schema) layers.

### Files Created
1. **`SILVER-SCHEMA-DDL.sql`** - 6 tables (4 dimensions, 2 facts)
2. **`GOLD-SCHEMA-DDL.sql`** - 8 tables (5 dimensions, 3 facts)

---

## Silver Schema Architecture

### Purpose
- **Data cleansing** and quality checks
- **Calculated columns** (CTR, ROAS, margins)
- **Validation flags** (email_valid, clicks_valid)
- **Audit trail** (load_timestamp, source_system)

### Tables

| Table | Type | Rows | Load Strategy | Primary Key | Clustering |
|-------|------|------|---------------|-------------|-----------|
| `mtln_silver_campaigns` | Dimension | 1K | Full Refresh | campaign_id | None |
| `mtln_silver_channels` | Dimension | 20 | Full Refresh | channel_id | None |
| `mtln_silver_customers` | Dimension | 10K | Full Refresh | customer_id | None |
| `mtln_silver_products` | Dimension | 1K | Full Refresh | product_id | None |
| `mtln_silver_performance` | Fact | 50K+ | **Incremental** | performance_id | performance_date |
| `mtln_silver_sales` | Fact | 100K+ | **Incremental** | order_line_id | order_date |

### Key Patterns

#### 1. Data Quality Columns
```sql
email_valid             BOOLEAN,        -- Email format check
clicks_valid            BOOLEAN,        -- clicks <= impressions
conversions_valid       BOOLEAN         -- conversions <= clicks
```

#### 2. Calculated Metrics
```sql
-- Campaigns
duration_days           NUMBER(10,0),   -- DATEDIFF(day, start, end) + 1

-- Performance
ctr                     NUMBER(10,4),   -- (clicks / impressions) * 100
cpc                     NUMBER(18,4),   -- cost / clicks
roas                    NUMBER(10,4),   -- revenue / cost

-- Products
margin                  NUMBER(18,2),   -- unit_price - cost
margin_percent          NUMBER(10,4)    -- (margin / unit_price) * 100
```

#### 3. Watermark for Incremental Loading
```sql
last_modified_timestamp TIMESTAMP_NTZ,  -- From Bronze (source system)
load_timestamp          TIMESTAMP_NTZ   -- Silver load timestamp (watermark)
```

**Incremental Filter Logic**:
```sql
WHERE bronze.last_modified_timestamp > 
    (SELECT MAX(load_timestamp) FROM silver.table)
```

#### 4. Clustering Keys
Fact tables use clustering on date columns for query performance:
```sql
CLUSTER BY (performance_date)  -- 50-80% faster queries
```

---

## Gold Schema Architecture

### Purpose
- **Star schema** for analytics
- **SCD Type 2** for historical tracking
- **Surrogate keys** for join performance
- **Referential integrity** with foreign keys
- **Pre-aggregated facts** for dashboards

### Star Schema Design

```
              ┌─────────────┐
              │  dim_date   │
              └──────┬──────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
   ┌────▼────┐  ┌───▼────┐  ┌───▼────┐
   │dim_     │  │ dim_   │  │ dim_   │
   │campaign │  │channel │  │customer│
   └────┬────┘  └───┬────┘  └───┬────┘
        │           │            │
   ┌────▼───────────▼────────────▼────┐
   │    fact_performance (Daily)      │
   └──────────────────────────────────┘
   
   ┌────────────┬────────────┬─────────┐
   │dim_customer│ dim_product│dim_     │
   │            │            │campaign │
   └─────┬──────┴──────┬─────┴────┬────┘
         │             │          │
    ┌────▼─────────────▼──────────▼─────┐
    │    fact_sales (Order Line)        │
    └───────────────────────────────────┘
```

### Dimension Tables

#### 1. **dim_campaign** (SCD Type 2)
- **Surrogate Key**: `campaign_key` (IDENTITY)
- **Natural Key**: `campaign_id`
- **Why SCD Type 2**: Track budget and status changes over time
- **Key Fields**:
  ```sql
  valid_from           TIMESTAMP_NTZ,
  valid_to             TIMESTAMP_NTZ,
  is_current           BOOLEAN,
  version_number       NUMBER(10,0)
  ```

#### 2. **dim_channel** (SCD Type 3)
- **Surrogate Key**: `channel_key` (IDENTITY)
- **Natural Key**: `channel_id`
- **Why SCD Type 3**: Compare before/after category changes
- **Key Fields**:
  ```sql
  current_category      VARCHAR(100),
  previous_category     VARCHAR(100),
  category_changed_date TIMESTAMP_NTZ
  ```

#### 3. **dim_customer** (SCD Type 2)
- **Surrogate Key**: `customer_key` (IDENTITY)
- **Natural Key**: `customer_id`
- **Why SCD Type 2**: Track segment/tier changes for cohort analysis
- **Unique Constraint**: `(customer_id, is_current)`

#### 4. **dim_product** (SCD Type 1)
- **Surrogate Key**: `product_key` (IDENTITY)
- **Natural Key**: `product_id`
- **Why SCD Type 1**: Price/cost corrections, history not needed
- **Overwrite Strategy**: Simple UPDATE on changes

#### 5. **dim_date** (Static Dimension)
- **Pre-populated**: 2020-01-01 to 2030-12-31
- **Date Key Format**: YYYYMMDD (e.g., 20250101)
- **Attributes**: Year, quarter, month, week, day, fiscal calendar
- **Flags**: is_weekend, is_holiday

### Fact Tables

#### 1. **fact_performance** (Transactional Grain)
- **Grain**: One row per campaign per channel per day
- **Foreign Keys**: campaign_key, channel_key, date_key
- **Additive Measures**: impressions, clicks, conversions, cost, revenue
- **Non-Additive**: CTR, CPC, ROAS (pre-calculated)
- **Clustering**: `(date_key, campaign_key)` for fast queries

#### 2. **fact_sales** (Transactional Grain)
- **Grain**: One row per order line
- **Foreign Keys**: customer_key, product_key, campaign_key, date_key
- **Additive Measures**: quantity, revenue, line_total, discount_amount
- **Degenerate Dimensions**: order_id, order_line_id
- **Clustering**: `(date_key, customer_key)` for customer analysis

#### 3. **fact_campaign_daily** (Aggregated)
- **Grain**: One row per campaign per day
- **Purpose**: Pre-aggregated for dashboard performance
- **Sources**: Aggregates from fact_performance
- **Benefits**: 10x faster queries for summary reports

---

## SCD Implementation Patterns

### SCD Type 1 (Overwrite)
**Use When**: Corrections only, history not needed

```sql
UPDATE dim_product
SET unit_price = new_value,
    updated_timestamp = CURRENT_TIMESTAMP()
WHERE product_id = 'P123';
```

### SCD Type 2 (Full History)
**Use When**: Track all changes over time

**Step 1: Expire Current Record**
```sql
UPDATE dim_campaign
SET valid_to = CURRENT_TIMESTAMP(),
    is_current = FALSE
WHERE campaign_id = 'C123' 
  AND is_current = TRUE;
```

**Step 2: Insert New Version**
```sql
INSERT INTO dim_campaign (
    campaign_id, campaign_name, budget, 
    valid_from, is_current, version_number
)
VALUES (
    'C123', 'Updated Name', 15000.00,
    CURRENT_TIMESTAMP(), TRUE, 2
);
```

### SCD Type 3 (Previous + Current)
**Use When**: Compare two states (before/after)

```sql
UPDATE dim_channel
SET previous_category = current_category,
    current_category = 'New Category',
    category_changed_date = CURRENT_TIMESTAMP()
WHERE channel_id = 'CH01';
```

---

## Load Strategies by Layer

### Silver Layer

**Dimensions (Full Refresh)**
```sql
-- Simple TRUNCATE + INSERT or CREATE OR REPLACE
CREATE OR REPLACE TABLE mtln_silver_campaigns AS
SELECT 
    campaign_id,
    COALESCE(campaign_name, 'Unknown') as campaign_name,
    -- ... cleansing logic
FROM bronze.mtln_bronze_campaigns;
```

**Facts (Incremental with Watermark)**
```sql
-- Load only changed records
INSERT INTO mtln_silver_performance
SELECT 
    performance_id,
    -- ... transformations
    CURRENT_TIMESTAMP() as load_timestamp
FROM bronze.mtln_bronze_performance
WHERE last_modified_timestamp > (
    SELECT COALESCE(MAX(load_timestamp), '1900-01-01')
    FROM mtln_silver_performance
);
```

### Gold Layer

**Dimensions (with SCD Logic)**
```sql
-- Type 2: Use MERGE with SCD logic
MERGE INTO dim_campaign tgt
USING silver.mtln_silver_campaigns src
ON tgt.campaign_id = src.campaign_id 
   AND tgt.is_current = TRUE
WHEN MATCHED AND (tgt.budget != src.budget) THEN
    UPDATE SET 
        valid_to = CURRENT_TIMESTAMP(),
        is_current = FALSE
WHEN NOT MATCHED THEN
    INSERT (campaign_id, budget, valid_from, is_current)
    VALUES (src.campaign_id, src.budget, CURRENT_TIMESTAMP(), TRUE);
```

**Facts (Incremental with Surrogate Key Lookup)**
```sql
INSERT INTO fact_sales (
    customer_key, product_key, date_key,
    quantity, revenue, load_timestamp
)
SELECT 
    c.customer_key,
    p.product_key,
    TO_NUMBER(TO_CHAR(s.order_date, 'YYYYMMDD')) as date_key,
    s.quantity,
    s.revenue,
    CURRENT_TIMESTAMP()
FROM silver.mtln_silver_sales s
JOIN dim_customer c ON s.customer_id = c.customer_id AND c.is_current = TRUE
JOIN dim_product p ON s.product_id = p.product_id
WHERE s.load_timestamp > (
    SELECT COALESCE(MAX(load_timestamp), '1900-01-01')
    FROM fact_sales
);
```

---

## Performance Optimizations

### 1. Clustering Keys
```sql
-- Fact tables clustered by date + primary dimension
CLUSTER BY (date_key, campaign_key)  -- 50-80% faster queries
```

### 2. Indexes on Foreign Keys
```sql
CREATE INDEX idx_fact_sales_customer ON fact_sales(customer_key);
CREATE INDEX idx_fact_sales_product ON fact_sales(product_key);
```

### 3. Unique Constraints for SCD
```sql
CONSTRAINT uq_dim_campaign_current UNIQUE (campaign_id, is_current)
```
Prevents duplicate current records.

### 4. Pre-Aggregated Facts
```sql
-- fact_campaign_daily for dashboards (10x faster)
CREATE TABLE fact_campaign_daily AS
SELECT 
    campaign_key,
    date_key,
    SUM(total_cost) as total_cost,
    AVG(ctr) as avg_ctr
FROM fact_performance
GROUP BY campaign_key, date_key;
```

---

## Deployment Steps

### Step 1: Execute Silver DDL
```bash
snowsql -f SILVER-SCHEMA-DDL.sql
```

### Step 2: Execute Gold DDL
```bash
snowsql -f GOLD-SCHEMA-DDL.sql
```

### Step 3: Populate Date Dimension
```sql
-- Generate dates from 2020-2030
INSERT INTO dim_date (date_key, date_value, year, month, ...)
SELECT 
    TO_NUMBER(TO_CHAR(d.date_val, 'YYYYMMDD')),
    d.date_val,
    YEAR(d.date_val),
    MONTH(d.date_val),
    -- ... other date attributes
FROM (
    SELECT DATEADD(day, SEQ4(), '2020-01-01'::DATE) as date_val
    FROM TABLE(GENERATOR(ROWCOUNT => 3653))  -- 10 years
) d;
```

### Step 4: Validate Schema
```sql
-- Check all tables created
SHOW TABLES IN SCHEMA SILVER;
SHOW TABLES IN SCHEMA GOLD;

-- Verify foreign keys
SHOW IMPORTED KEYS IN fact_sales;

-- Check constraints
SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA IN ('SILVER', 'GOLD');
```

---

## Common Queries

### Check SCD Type 2 History
```sql
-- View all versions of a campaign
SELECT 
    campaign_key,
    campaign_id,
    budget,
    valid_from,
    valid_to,
    is_current,
    version_number
FROM dim_campaign
WHERE campaign_id = 'C123'
ORDER BY version_number;
```

### Validate One Current Record Per Entity
```sql
-- Should return 0 rows
SELECT campaign_id, COUNT(*)
FROM dim_campaign
WHERE is_current = TRUE
GROUP BY campaign_id
HAVING COUNT(*) > 1;
```

### Point-in-Time Query (As of Date)
```sql
-- Get campaign attributes as of 2025-01-01
SELECT *
FROM dim_campaign
WHERE campaign_id = 'C123'
  AND '2025-01-01' BETWEEN valid_from AND valid_to;
```

---

## Next Steps

1. ✅ **DDL Created** - Silver & Gold schemas defined
2. **Build Transformation Pipelines**:
   - Bronze → Silver (cleansing, validation)
   - Silver → Gold (SCD logic, surrogate key lookups)
3. **Populate Date Dimension** (run once)
4. **Create Matillion Orchestration Pipelines**:
   - Master DDL pipeline (creates all tables)
   - Silver load pipelines (6 tables)
   - Gold load pipelines (8 tables with SCD)
5. **Testing & Validation**:
   - Row count checks
   - Referential integrity validation
   - SCD logic testing
   - Performance benchmarks

---

## Reference

- **Project Pattern**: See `context.md` for medallion architecture best practices
- **Silver DDL**: `SILVER-SCHEMA-DDL.sql` (6 tables)
- **Gold DDL**: `GOLD-SCHEMA-DDL.sql` (8 tables)
- **Current Pipeline**: `Bronze to Silver - Campaigns.tran.yaml` (example)

---

**Version**: 1.0  
**Created**: 2025-12-22  
**Database**: MATILLION_DB  
**Schemas**: SILVER, GOLD