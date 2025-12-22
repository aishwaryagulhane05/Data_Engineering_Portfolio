# DDL Quick Reference
**Fast lookup for table structures and relationships**

---

## 📁 Files Created

1. **`SILVER-SCHEMA-DDL.sql`** - 6 tables for cleansed data
2. **`GOLD-SCHEMA-DDL.sql`** - 8 tables for analytics (star schema)
3. **`DDL-ARCHITECTURE-GUIDE.md`** - Complete documentation

---

## 🥈 Silver Schema (6 Tables)

### Dimensions
| Table | Primary Key | Rows | Strategy | Purpose |
|-------|-------------|------|----------|----------|
| `mtln_silver_campaigns` | campaign_id | 1K | Full Refresh | Marketing campaigns |
| `mtln_silver_channels` | channel_id | 20 | Full Refresh | Marketing channels |
| `mtln_silver_customers` | customer_id | 10K | Full Refresh | Customer master |
| `mtln_silver_products` | product_id | 1K | Full Refresh | Product catalog |

### Facts
| Table | Primary Key | Rows | Strategy | Clustering | Purpose |
|-------|-------------|------|----------|------------|----------|
| `mtln_silver_performance` | performance_id | 50K+ | **Incremental** | performance_date | Marketing metrics |
| `mtln_silver_sales` | order_line_id | 100K+ | **Incremental** | order_date | Sales transactions |

**Key Columns in All Tables**:
- `load_timestamp` - For incremental loading watermark
- `last_modified_timestamp` - From source system
- `source_system` - Data lineage

---

## 🥇 Gold Schema (8 Tables)

### Dimensions (5)

| Table | Surrogate Key | Natural Key | SCD Type | Purpose |
|-------|---------------|-------------|----------|----------|
| `dim_campaign` | campaign_key | campaign_id | **Type 2** | Track budget/status changes |
| `dim_channel` | channel_key | channel_id | **Type 3** | Track category changes |
| `dim_customer` | customer_key | customer_id | **Type 2** | Track segment/tier changes |
| `dim_product` | product_key | product_id | **Type 1** | Overwrite price changes |
| `dim_date` | date_key | date_value | Static | Pre-built 2020-2030 |

#### SCD Type 2 Key Columns
```sql
valid_from          TIMESTAMP_NTZ,
valid_to            TIMESTAMP_NTZ,
is_current          BOOLEAN,
version_number      NUMBER(10,0)
```

### Facts (3)

| Table | Primary Key | Grain | Foreign Keys | Clustering |
|-------|-------------|-------|--------------|------------|
| `fact_performance` | performance_key | Campaign/Channel/Day | campaign_key, channel_key, date_key | (date_key, campaign_key) |
| `fact_sales` | sales_key | Order Line | customer_key, product_key, campaign_key, date_key | (date_key, customer_key) |
| `fact_campaign_daily` | (campaign_key, date_key) | Campaign/Day | campaign_key, date_key | date_key |

---

## 🔗 Star Schema Relationships

```
fact_performance
  ├── dim_campaign (campaign_key)
  ├── dim_channel (channel_key)
  └── dim_date (date_key)

fact_sales
  ├── dim_customer (customer_key)
  ├── dim_product (product_key)
  ├── dim_campaign (campaign_key)
  └── dim_date (date_key)

fact_campaign_daily
  ├── dim_campaign (campaign_key)
  └── dim_date (date_key)
```

---

## 📊 Table Comparison

| Feature | Silver | Gold |
|---------|--------|------|
| **Purpose** | Cleansed data | Analytics-ready |
| **Keys** | Natural (business keys) | Surrogate (auto-increment) |
| **History** | Current state only | Full history (SCD Type 2) |
| **Schema** | Normalized | Star schema (denormalized) |
| **Foreign Keys** | None | Enforced with constraints |
| **Load Complexity** | Medium | High (SCD logic) |
| **Query Performance** | Good | Excellent (optimized for BI) |

---

## 🚀 Deployment Commands

```bash
# 1. Create Silver tables
snowsql -f SILVER-SCHEMA-DDL.sql

# 2. Create Gold tables
snowsql -f GOLD-SCHEMA-DDL.sql

# 3. Verify
snowsql -q "SHOW TABLES IN SCHEMA MATILLION_DB.SILVER;"
snowsql -q "SHOW TABLES IN SCHEMA MATILLION_DB.GOLD;"

# 4. Check foreign keys
snowsql -q "SHOW IMPORTED KEYS IN MATILLION_DB.GOLD.fact_sales;"
```

---

## 🔍 Validation Queries

### Check All Tables Created
```sql
SELECT table_schema, table_name, row_count, bytes
FROM INFORMATION_SCHEMA.TABLES
WHERE table_schema IN ('SILVER', 'GOLD')
ORDER BY table_schema, table_name;
```

### Validate SCD Type 2 (No Duplicates)
```sql
-- Should return 0 rows
SELECT campaign_id, COUNT(*)
FROM dim_campaign
WHERE is_current = TRUE
GROUP BY campaign_id
HAVING COUNT(*) > 1;
```

### Check Foreign Key Integrity
```sql
-- Should return 0 rows (orphan check)
SELECT COUNT(*)
FROM fact_sales f
LEFT JOIN dim_customer c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;
```

---

## 🎯 Common Use Cases

### Silver → Gold Load Pattern
```sql
-- Load dimension with SCD Type 2
MERGE INTO dim_campaign tgt
USING silver.mtln_silver_campaigns src
ON tgt.campaign_id = src.campaign_id AND tgt.is_current = TRUE
WHEN MATCHED AND (tgt.budget != src.budget) THEN
  UPDATE SET valid_to = CURRENT_TIMESTAMP(), is_current = FALSE
WHEN NOT MATCHED THEN
  INSERT VALUES (src.campaign_id, src.budget, CURRENT_TIMESTAMP(), TRUE);

-- Load fact with surrogate key lookups
INSERT INTO fact_sales
SELECT 
  c.customer_key,
  p.product_key,
  TO_NUMBER(TO_CHAR(s.order_date, 'YYYYMMDD')),
  s.quantity, s.revenue
FROM silver.mtln_silver_sales s
JOIN dim_customer c ON s.customer_id = c.customer_id AND c.is_current = TRUE
JOIN dim_product p ON s.product_id = p.product_id;
```

### Point-in-Time Query
```sql
-- Get campaign attributes as of specific date
SELECT c.campaign_name, c.budget
FROM fact_performance f
JOIN dim_campaign c 
  ON f.campaign_key = c.campaign_key
  AND f.date_key BETWEEN 
    TO_NUMBER(TO_CHAR(c.valid_from, 'YYYYMMDD')) AND 
    TO_NUMBER(TO_CHAR(c.valid_to, 'YYYYMMDD'))
WHERE f.date_key = 20250101;
```

---

## 📝 Column Naming Conventions

| Type | Silver | Gold | Example |
|------|--------|------|----------|
| Natural Key | `{entity}_id` | `{entity}_id` | campaign_id |
| Surrogate Key | N/A | `{entity}_key` | campaign_key |
| Foreign Key | `{entity}_id` | `{entity}_key` | customer_key |
| Date Key | `{name}_date` | `date_key` | order_date → date_key |
| Timestamp | `{name}_timestamp` | `{name}_timestamp` | load_timestamp |
| Flag | `{name}_valid` | `is_{name}` | email_valid → is_current |

---

## ⚡ Performance Tips

1. **Cluster fact tables by date + primary dimension**
   ```sql
   CLUSTER BY (date_key, campaign_key)
   ```

2. **Index foreign keys in facts**
   ```sql
   CREATE INDEX idx_fact_sales_customer ON fact_sales(customer_key);
   ```

3. **Use unique constraints on SCD**
   ```sql
   CONSTRAINT uq_dim_campaign_current UNIQUE (campaign_id, is_current)
   ```

4. **Pre-aggregate for dashboards**
   - Use `fact_campaign_daily` instead of `fact_performance` for summaries
   - 10x faster for daily/weekly/monthly reports

---

## 🔄 Load Sequence

### Recommended Order
1. **Date Dimension** (once) - Pre-populate 2020-2030
2. **Gold Dimensions** (daily) - Load with SCD logic
3. **Gold Facts** (daily) - Load with surrogate key lookups
4. **Aggregate Facts** (daily) - Rebuild from detailed facts

### Dependencies
```
dim_date (once)
  ↓
dim_campaign, dim_channel, dim_customer, dim_product
  ↓
fact_performance, fact_sales
  ↓
fact_campaign_daily (aggregated)
```

---

## 📚 Additional Resources

- **Full Documentation**: `DDL-ARCHITECTURE-GUIDE.md`
- **SQL Scripts**: `SILVER-SCHEMA-DDL.sql`, `GOLD-SCHEMA-DDL.sql`
- **Project Pattern**: `.matillion/maia/rules/context.md`
- **Current Pipeline**: `Bronze to Silver - Campaigns.tran.yaml`

---

**Quick Stats**:
- **Silver**: 6 tables (4 dim + 2 facts)
- **Gold**: 8 tables (5 dim + 3 facts)
- **Total Columns**: ~150 across both schemas
- **SCD Types Used**: Type 1, Type 2, Type 3
- **Foreign Keys**: 12 relationships

---

**Version**: 1.0  
**Updated**: 2025-12-22