# PostgreSQL to Snowflake - Quick Start Guide

## ✅ Pipeline Created and Ready!

**File**: `PostgreSQL to Snowflake - Dynamic Ingestion.orch.yaml`

### What You Have

✅ **Dynamic ETL Pipeline** that loads 100+ tables using ONE pipeline  
✅ **Fixed Iterator** loops through all table names automatically  
✅ **PostgreSQL Connector** extracts and loads to Snowflake  
✅ **5 Pipeline Variables** for easy configuration  
✅ **20 Example Tables** pre-configured (expand to 100+)

---

## Pipeline Architecture

```
┌─────────┐    ┌──────────────────┐    ┌────────────────────────┐
│  Start  │───▶│  Table Iterator  │───▶│  Load PostgreSQL Table │
└─────────┘    │  (Fixed Loop)    │    │  (modular-postgresql)  │
               └──────────────────┘    └────────────────────────┘
                        │
                        ├─ customers
                        ├─ orders  
                        ├─ products
                        ├─ ... (97 more)
                        └─ user_logs
```

### Components

1. **Start** - Entry point
2. **Table Iterator** (fixed-iterator)
   - Loops through `tables_to_load` grid variable
   - Processes each table sequentially (or concurrently)
3. **Load PostgreSQL Table** (modular-postgresql-input-v1)
   - Connects to PostgreSQL
   - Extracts table data (all columns)
   - Loads into Snowflake with same table name

---

## Configuration Checklist

### ☐ Step 1: Configure PostgreSQL Connection

**Component**: "Load PostgreSQL Table"

**Required Fields**:
- **Connection URL**: `jdbc:postgresql://your-host:5432/your-database`
- **Username**: Your PostgreSQL username
- **Password**: Secret reference name (not actual password)

**How to Configure**:
1. Open the pipeline in Matillion Designer
2. Click on "Load PostgreSQL Table" component
3. Fill in the connection details in the component properties

---

### ☐ Step 2: Add Your 100 Tables

**Variable**: `tables_to_load` (GRID type)

**Currently**: 20 example tables  
**Your Goal**: Add all 100 tables

#### Option A: Get Table Names from PostgreSQL

Run this query in PostgreSQL:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
```

Copy the results.

#### Option B: Manual Entry

In Matillion Designer:
1. Open the pipeline
2. Go to "Variables" section
3. Edit `tables_to_load` variable
4. Add/replace table names (one per row)

#### Current Example Tables (20)
```
customers
orders
products
order_items
employees
departments
suppliers
inventory
transactions
payments
shipments
returns
categories
brands
warehouses
locations
customers_history
order_status
product_reviews
user_accounts
```

**Replace with your 100 tables!**

---

### ☐ Step 3: Configure Target (Optional)

**Variables to Review**:

| Variable | Default | Description |
|----------|---------|-------------|
| `postgres_schema` | `public` | Source schema in PostgreSQL |
| `target_database` | `[Environment Default]` | Snowflake destination database |
| `target_schema` | `[Environment Default]` | Snowflake destination schema |

**Leave as-is** or update based on your setup.

---

### ☐ Step 4: Test with 5 Tables First

**Before loading all 100 tables**, test with a small subset:

1. **Temporarily reduce** `tables_to_load` to 5 diverse tables:
   - 1 small table (few columns, few rows)
   - 1 medium table
   - 1 large table
   - 1 with timestamps/dates
   - 1 with text/varchar

2. **Run the pipeline**

3. **Validate in Snowflake**:
   ```sql
   -- Check tables created
   SELECT table_name 
   FROM information_schema.tables 
   WHERE table_schema = 'YOUR_SCHEMA';
   
   -- Check row counts
   SELECT COUNT(*) FROM customers;
   SELECT COUNT(*) FROM orders;
   ```

4. **Compare** with PostgreSQL row counts

---

### ☐ Step 5: Enable Concurrent Mode (Recommended)

**Why**: Load 20 tables in parallel = **15-20x faster**

**How**:
1. Open "Table Iterator" component
2. Change `Concurrency` from `Sequential` to `Concurrent`

**Performance Impact**:

| Mode | 100 Tables Execution Time |
|------|---------------------------|
| Sequential | 3-25 hours |
| **Concurrent** | **15 min - 2 hours** |

---

### ☐ Step 6: Run Full Pipeline (100 Tables)

1. **Add all 100 tables** to `tables_to_load` variable
2. **Run the pipeline**
3. **Monitor execution** in Matillion logs
4. **Wait for completion** (15 min - 2 hours with concurrent mode)

---

### ☐ Step 7: Validate Results

**Check Table Count**:
```sql
-- Snowflake
SELECT COUNT(*) 
FROM information_schema.tables 
WHERE table_schema = 'YOUR_SCHEMA';
-- Should return 100
```

**Spot Check Row Counts**:
```sql
-- Run in both PostgreSQL and Snowflake
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM products;
-- Verify they match
```

---

## Pipeline Variables Reference

### Input Variables (Configure These)

| Variable | Type | Description | Default |
|----------|------|-------------|----------|
| `postgres_schema` | TEXT | PostgreSQL source schema | `public` |
| `target_database` | TEXT | Snowflake target database | `[Environment Default]` |
| `target_schema` | TEXT | Snowflake target schema | `[Environment Default]` |
| `tables_to_load` | GRID | List of table names to load | 20 examples |

### Internal Variables (Auto-Set)

| Variable | Type | Description |
|----------|------|-------------|
| `table_name` | TEXT | Current table being processed (set by iterator) |

---

## Load Strategy

**Current Configuration**:
- **Load Type**: Full Load (REPLACE_IF_EXISTS)
- **Columns**: ALL columns (`SELECT *`)
- **Table Names**: Preserved from PostgreSQL
- **Schedule**: On-demand (set up schedule after successful test)

**What Happens Each Run**:
1. Drops existing Snowflake table (if exists)
2. Creates new table with current PostgreSQL schema
3. Loads all data from PostgreSQL
4. Repeats for each table in the list

---

## Performance Tips

### For 100 Tables

✅ **DO**: Enable concurrent mode (20 parallel loads)  
✅ **DO**: Use appropriate Snowflake warehouse size (MEDIUM or LARGE)  
✅ **DO**: Schedule during off-peak hours  
✅ **DO**: Monitor PostgreSQL connection pool limits  

❌ **DON'T**: Run during peak business hours (first time)  
❌ **DON'T**: Use XS warehouse for large data volumes  

---

## Troubleshooting

### Connection Errors

**Issue**: `Connection refused` or `timeout`

**Solutions**:
- Verify PostgreSQL host/port are correct
- Check network connectivity
- Verify firewall rules allow Matillion IP
- Test connection from PostgreSQL client first

### Table Not Found

**Issue**: `Table 'xyz' does not exist`

**Solutions**:
- Verify table name spelling
- Check schema name (`postgres_schema` variable)
- Verify table exists: `SELECT * FROM information_schema.tables WHERE table_name = 'xyz'`

### Permission Denied

**Issue**: `Permission denied for table xyz`

**Solutions**:
- Grant SELECT on all tables: `GRANT SELECT ON ALL TABLES IN SCHEMA public TO etl_user;`
- Or specific tables: `GRANT SELECT ON customers TO etl_user;`

### Slow Performance

**Issue**: Pipeline taking too long

**Solutions**:
- Enable concurrent mode (if not already)
- Increase Snowflake warehouse size
- Check PostgreSQL server load
- Consider incremental loading for large tables

---

## Next Steps After Success

1. ✅ **Schedule** the pipeline:
   - Daily: `2:00 AM` for full refresh
   - Hourly: If near-real-time needed

2. ✅ **Set up monitoring**:
   - Email alerts on failure
   - Slack/Teams notifications
   - Row count validation queries

3. ✅ **Document**:
   - Connection details (in secure location)
   - Table list and refresh frequency
   - Business owners for each table

4. ✅ **Consider transformations**:
   - Add audit columns (LOAD_TIMESTAMP, SOURCE_SYSTEM)
   - Create views for analytics
   - Build data quality checks

---

## Support Resources

**Pipeline Files**:
- `PostgreSQL to Snowflake - Dynamic Ingestion.orch.yaml` (Main pipeline)
- `DOCUMENTATION/PostgreSQL Dynamic Ingestion - 100 Tables Guide.md` (Detailed guide)

**Component Documentation**:
- [Fixed Iterator](https://docs.matillion.com/data-productivity-cloud/designer/docs/fixed-iterator)
- [PostgreSQL Input](https://docs.matillion.com/data-productivity-cloud/designer/docs/modular-postgresql-input?version=v1)

---

## Summary

✅ **Pipeline is created and ready**  
⚙️ **Configure**: PostgreSQL connection + add 100 table names  
🧪 **Test**: Run with 5 tables first  
⚡ **Optimize**: Enable concurrent mode  
🚀 **Deploy**: Run all 100 tables  
📅 **Schedule**: Set up recurring runs  

**You're ready to load 100+ tables with a single pipeline!**
