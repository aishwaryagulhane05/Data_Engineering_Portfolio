# Incremental Loading Guide - Smart First Run & Incremental Updates

## Overview

The PostgreSQL to Snowflake Dynamic Ingestion pipeline is configured to **intelligently handle both initial table creation and incremental updates**.

### Smart Loading Strategy

✅ **First Run**: Creates tables (if they don't exist) + Loads ALL data  
✅ **Subsequent Runs**: Can be configured for incremental loading (only new/changed records)  
✅ **No Manual Table Creation**: Pipeline automatically creates tables on first run  
✅ **Flexible**: Switch between full refresh and incremental modes

## Current Configuration

### Load Strategy: APPEND Mode

```yaml
createTableMode: "APPEND"
loadType: "FULL_LOAD"
```

**What This Means:**

| Run | Table Exists? | Behavior |
|-----|---------------|----------|
| **First Run** | ❌ No | Creates table + Loads all data |
| **Second Run** | ✅ Yes | Appends all data (duplicates possible) |
| **Third Run** | ✅ Yes | Appends all data (duplicates possible) |

⚠️ **Current Mode Issue**: Full Load with APPEND will create duplicates on subsequent runs.

## Recommended Configurations

### Option 1: Full Refresh (Current - Simple, Safe)

**When to Use**: 
- Small to medium tables (< 10M rows)
- Data changes frequently
- Don't need historical data preservation
- Simplicity over performance

**Configuration**:
```yaml
createTableMode: "APPEND"      # Creates if not exists
loadType: "FULL_LOAD"          # Loads all data every time
```

**Change to**:
```yaml
createTableMode: "REPLACE_IF_EXISTS"  # Drops and recreates
loadType: "FULL_LOAD"                  # Loads all data
```

**Behavior**:
- First run: Creates table + Loads all data
- Subsequent runs: Drops table + Recreates + Loads all data
- ✅ No duplicates
- ❌ Slower for large tables

---

### Option 2: Incremental Loading (Recommended for 100 Tables)

**When to Use**:
- Large tables (> 10M rows)
- Most data doesn't change
- Only new/updated records needed
- **97% faster** than full refresh

**Prerequisites**:
- All tables MUST have a timestamp column (e.g., `updated_at`, `created_at`, `modified_date`)
- Timestamp column updated whenever record changes

**Configuration Steps**:

#### Step 1: Ensure Tables Have Timestamp Column

**In PostgreSQL**, verify all 100 tables have a timestamp column:
```sql
-- Check if tables have updated_at column
SELECT 
  table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name IN ('updated_at', 'created_at', 'modified_date', 'last_modified')
ORDER BY table_name;
```

**If missing**, add to tables:
```sql
-- Add updated_at column to tables that don't have it
ALTER TABLE your_table 
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add trigger to update timestamp on record changes (optional but recommended)
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_table_timestamp
BEFORE UPDATE ON your_table
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();
```

#### Step 2: Run Full Load First (Initial Load)

**Keep current configuration** for the first run:
```yaml
createTableMode: "APPEND"
loadType: "FULL_LOAD"
```

**Run the pipeline** - This will:
1. Create all 100 tables in Snowflake
2. Load ALL data from PostgreSQL
3. Establish baseline for incremental loading

#### Step 3: Switch to Incremental Mode

**After successful first run**, update the component configuration:

**In "Load PostgreSQL Table" component**, change:

```yaml
snowflake-output-connector-v0:
  warehouse: "[Environment Default]"
  database: "${target_database}"
  schema: "${target_schema}"
  tableName: "${table_name}"
  createTableMode: "APPEND"              # Keep APPEND
  primaryKeys:                            # Add if you want merge behavior
    - "id"                                # Your primary key column
  cleanStagedFiles: "Yes"
  stagePlatform: "SNOWFLAKE"
  snowflake#internalStageType: "USER"

dataLoading:
  loadType: "INCREMENTAL_LOAD"           # Change to INCREMENTAL
  incrementalLoading:
    highWaterMarkSelection: "updated_at"  # Your timestamp column
```

#### Step 4: Configure Primary Keys (If Using Merge)

**Without Primary Key**:
- Incremental load **APPENDS** new records only
- Updated records create duplicates
- Good for append-only tables (logs, events)

**With Primary Key**:
- Incremental load **MERGES** (UPSERT)
- Updates existing records, inserts new ones
- No duplicates
- Good for transactional tables (orders, customers)

**To add primary key** in configuration:
```yaml
primaryKeys:
  - "customer_id"        # Single key
# OR
primaryKeys:
  - "order_id"           # Composite key
  - "line_number"
```

---

### Option 3: Truncate and Insert (Alternative)

**When to Use**:
- Medium tables
- Want to keep table structure (no drop/recreate)
- Full refresh but preserve table metadata

**Configuration**:
```yaml
createTableMode: "TRUNCATE_AND_INSERT"
loadType: "FULL_LOAD"
```

**Behavior**:
- First run: Creates table + Loads all data
- Subsequent runs: Deletes all rows + Loads all data
- Table structure preserved
- Faster than REPLACE for large tables

---

## Configuration Matrix

| Scenario | createTableMode | loadType | Primary Keys | Result |
|----------|-----------------|----------|--------------|--------|
| **Initial Load** | APPEND | FULL_LOAD | No | Creates table + Loads all | |
| **Full Refresh (Small Tables)** | REPLACE_IF_EXISTS | FULL_LOAD | No | Drops/recreates + Loads all |
| **Full Refresh (Keep Structure)** | TRUNCATE_AND_INSERT | FULL_LOAD | No | Deletes rows + Loads all |
| **Incremental Append** | APPEND | INCREMENTAL_LOAD | No | Appends new records only |
| **Incremental Merge** | APPEND | INCREMENTAL_LOAD | Yes | Upserts (updates + inserts) |

---

## How Incremental Loading Works

### High Water Mark Concept

```
PostgreSQL Table:
+----+----------+---------------------+
| ID | Name     | updated_at          |
+----+----------+---------------------+
| 1  | Alice    | 2025-01-01 10:00:00 |
| 2  | Bob      | 2025-01-01 11:00:00 |
| 3  | Charlie  | 2025-01-02 09:00:00 | ← New
| 4  | David    | 2025-01-02 10:00:00 | ← New
+----+----------+---------------------+

Snowflake Table (after first load):
+----+----------+---------------------+
| ID | Name     | updated_at          |
+----+----------+---------------------+
| 1  | Alice    | 2025-01-01 10:00:00 |
| 2  | Bob      | 2025-01-01 11:00:00 |
+----+----------+---------------------+

High Water Mark = MAX(updated_at) = 2025-01-01 11:00:00

Next Run Query:
SELECT * FROM table 
WHERE updated_at > '2025-01-01 11:00:00'

Result: Only Charlie and David loaded
```

### Incremental Load Process

1. **Check Snowflake**: `SELECT MAX(updated_at) FROM target_table`
2. **Query PostgreSQL**: `WHERE updated_at > <max_value>`
3. **Load Only New/Changed**: APPEND or MERGE into Snowflake
4. **Update High Water Mark**: Automatically tracked

---

## Variables Reference

### Incremental Column Variable

```yaml
incremental_column: "updated_at"
```

**Purpose**: Specifies which timestamp column to use for incremental loading

**Common Column Names**:
- `updated_at`
- `created_at`
- `modified_date`
- `last_modified`
- `load_timestamp`

**Requirement**: ALL 100 tables must have this column with the same name, or you need to customize per table.

---

## Handling Tables with Different Timestamp Columns

### Problem
Not all tables use the same column name for timestamps.

### Solution 1: Standardize in PostgreSQL (Recommended)

Add alias columns:
```sql
ALTER TABLE orders ADD COLUMN updated_at TIMESTAMP;
UPDATE orders SET updated_at = order_date;

ALTER TABLE products ADD COLUMN updated_at TIMESTAMP; 
UPDATE products SET updated_at = last_modified_date;
```

### Solution 2: Use Grid Variable with Table-Specific Columns

**Modify `tables_to_load` variable** to include timestamp column:

```yaml
tables_to_load:
  columns:
    - table_name
    - timestamp_column
  defaultValue:
    - ["customers", "updated_at"]
    - ["orders", "order_date"]
    - ["products", "modified_date"]
```

**Update iterator** to pass both variables.

**Update Load component** to use `${timestamp_column}` instead of `${incremental_column}`.

---

## Performance Comparison

### Full Refresh vs Incremental

**Example: 100 tables, 10M rows each, 1% daily change**

| Strategy | Data Processed | Time | Cost |
|----------|----------------|------|------|
| **Full Refresh** | 1 billion rows | 3-8 hours | $$$ |
| **Incremental** | 10 million rows | 10-30 min | $ |

**Incremental = 97% faster, 97% cheaper**

---

## Best Practices

### 1. Initial Load Strategy

✅ **DO**:
- Run full load first to establish baseline
- Test with 5-10 tables before all 100
- Verify all tables have timestamp columns
- Document which column each table uses

❌ **DON'T**:
- Start with incremental on non-existent tables
- Mix full and incremental randomly
- Skip timestamp column validation

### 2. Timestamp Column Best Practices

✅ **DO**:
- Use `TIMESTAMP` or `TIMESTAMP_NTZ` data type
- Add default value: `DEFAULT CURRENT_TIMESTAMP`
- Update on every record change (use triggers)
- Index the timestamp column for performance

❌ **DON'T**:
- Use `VARCHAR` or `TEXT` for timestamps
- Leave NULL values
- Forget to update timestamp on changes

### 3. Primary Key for Merge

✅ **DO**:
- Use natural business keys (customer_id, order_id)
- Ensure keys are truly unique
- Use composite keys when needed

❌ **DON'T**:
- Use auto-increment IDs from destination
- Skip primary keys for transactional tables
- Use non-unique columns

### 4. Monitoring Incremental Loads

**Track high water marks**:
```sql
CREATE VIEW incremental_load_status AS
SELECT 
  table_name,
  MAX(updated_at) as last_loaded_timestamp,
  COUNT(*) as total_rows,
  MAX(updated_at)::DATE as last_load_date
FROM (
  SELECT 'customers' as table_name, updated_at FROM customers
  UNION ALL
  SELECT 'orders', updated_at FROM orders
  -- Add all tables
) all_tables
GROUP BY table_name;
```

**Check for stale tables** (not updating):
```sql
SELECT 
  table_name,
  last_loaded_timestamp,
  DATEDIFF(day, last_loaded_timestamp, CURRENT_TIMESTAMP()) as days_since_update
FROM incremental_load_status
WHERE days_since_update > 7  -- No updates in 7 days
ORDER BY days_since_update DESC;
```

---

## Migration Path: Full Refresh → Incremental

### Week 1: Initial Load (Full Refresh)

1. Configure pipeline with APPEND + FULL_LOAD
2. Run pipeline for all 100 tables
3. Verify all tables created successfully
4. Validate row counts match PostgreSQL

### Week 2: Testing Incremental

1. Pick 5 test tables
2. Verify they have timestamp columns
3. Switch those 5 to INCREMENTAL_LOAD
4. Run pipeline and validate
5. Compare data before/after

### Week 3: Full Migration

1. Switch all 100 tables to INCREMENTAL_LOAD
2. Run pipeline
3. Monitor execution time (should be 10-20x faster)
4. Validate data quality

### Week 4: Optimization

1. Add primary keys for merge behavior
2. Fine-tune warehouse sizes
3. Enable concurrent mode
4. Set up monitoring dashboards

---

## Troubleshooting

### Issue: Duplicates in Snowflake

**Cause**: Using APPEND without primary keys

**Solution**:
```yaml
primaryKeys:
  - "id"  # Add your primary key
```

### Issue: No New Data Loaded

**Cause**: High water mark not advancing

**Check**:
```sql
-- Check if timestamp column is updating
SELECT MAX(updated_at), COUNT(*)
FROM your_table
WHERE updated_at > CURRENT_DATE() - 7;
```

**Solution**: Ensure triggers/applications update timestamp on changes

### Issue: "High-water mark must be included in data selection"

**Cause**: Timestamp column not in `dataSelection`

**Solution**: If using column selection (not `*`), explicitly add:
```yaml
dataSelection:
  - "id"
  - "name"
  - "updated_at"  # Must include this
```

### Issue: Table Creation Fails

**Cause**: Insufficient permissions

**Solution**: Grant CREATE TABLE permission:
```sql
GRANT CREATE TABLE ON SCHEMA your_schema TO your_role;
```

---

## Summary

### Current Configuration ✅

- **Mode**: CREATE IF NOT EXISTS (APPEND)
- **First Run**: Creates tables + Loads all data
- **Strategy**: Full Load (configurable to incremental)

### To Enable Incremental Loading:

1. ✅ Run full load once (already configured)
2. ✅ Verify all tables have timestamp column
3. ✅ Update configuration to INCREMENTAL_LOAD
4. ✅ Set `highWaterMarkSelection` to your timestamp column
5. ✅ Add primary keys for merge behavior (optional)
6. ✅ Run and validate

### Performance Gains:

- **97% faster** execution
- **97% lower** compute costs  
- **Real-time** data freshness
- **Scalable** to 1000+ tables

---

**Version**: 1.0  
**Last Updated**: 2025-12-25  
**Pipeline**: PostgreSQL to Snowflake - Dynamic Ingestion  
**Feature**: Smart First Run + Incremental Updates
