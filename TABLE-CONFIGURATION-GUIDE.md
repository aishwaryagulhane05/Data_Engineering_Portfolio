# Table Configuration Guide for Dynamic PostgreSQL Ingestion

## 📋 Purpose

This guide helps you configure 100+ tables for the dynamic PostgreSQL to Snowflake ingestion pipeline.

## 📁 Files Included

- `table-configuration-template.csv` - 100-row template with common table patterns
- `PostgreSQL to Snowflake - Dynamic Ingestion.orch.yaml` - The main pipeline

---

## 🚀 Quick Start

### Step 1: Edit the CSV Template

1. **Open** `table-configuration-template.csv` in Excel, Google Sheets, or any text editor
2. **Replace** placeholder values with your actual PostgreSQL table names
3. **Configure** the incremental column and primary key for each table

### Step 2: Add Tables to Pipeline Variable

**Option A: Manual Entry (Small Changes)**
1. Open the pipeline in Matillion Designer
2. Click on `tables_to_load` variable
3. Add/edit rows directly in the grid editor

**Option B: Bulk Import (100+ Tables)**
1. Copy all rows from CSV (excluding header)
2. In the pipeline variable grid editor, paste the data
3. Or use the import feature if available in your Matillion version

---

## 📊 CSV Template Structure

### Columns

| Column | Description | Example |
|--------|-------------|----------|
| **table_name** | PostgreSQL table name (case-sensitive if your DB requires it) | `customers` |
| **incremental_column** | Timestamp/date column used for tracking changes | `updated_at` |
| **primary_key** | Primary key column for merge/upsert operations | `customer_id` |

### Example Rows

```csv
table_name,incremental_column,primary_key
customers,updated_at,customer_id
orders,order_date,order_id
products,last_modified,product_id
```

---

## 🎯 Configuration Requirements

### Incremental Column Requirements

✅ **Must be:**
- A timestamp or date column
- Present in every table
- Automatically updated when records change
- Indexed for performance (recommended)

✅ **Common column names:**
- `updated_at`
- `last_modified`
- `modified_date`
- `last_updated_timestamp`
- `sync_timestamp`

### Primary Key Requirements

✅ **Must be:**
- Unique identifier for each row
- Not null
- Stable (doesn't change)

✅ **Common patterns:**
- `id`, `customer_id`, `order_id`
- `uuid`, `guid`
- Composite keys: Configure as single column or modify pipeline for multi-column keys

---

## 📝 Template Patterns Included

The template includes 100 common table types:

### E-Commerce (25 tables)
- Customers, orders, products, inventory
- Shopping carts, wishlists, reviews
- Payments, invoices, refunds, returns

### Marketing (15 tables)
- Campaigns, email marketing, social media
- Web analytics, A/B testing, conversions
- Customer segments, engagement tracking

### Operations (20 tables)
- Employees, departments, locations, warehouses
- Suppliers, purchase orders, stock management
- Shipping, tracking, logistics

### Finance (15 tables)
- Accounts, transactions, journal entries
- General ledger, budgets, forecasts
- Revenue recognition, tax records

### System/Admin (25 tables)
- User accounts, roles, permissions
- Audit logs, API usage, webhooks
- ETL logs, data quality, configuration

---

## 🔧 Customization Examples

### Example 1: Different Column Names

**Your PostgreSQL Schema:**
```sql
CREATE TABLE user_activity (
  activity_id SERIAL PRIMARY KEY,
  user_id INT,
  event_type VARCHAR,
  created_timestamp TIMESTAMP  -- Your incremental column
);
```

**CSV Configuration:**
```csv
user_activity,created_timestamp,activity_id
```

### Example 2: Date Columns (Not Timestamps)

**Your PostgreSQL Schema:**
```sql
CREATE TABLE daily_sales (
  sale_id INT PRIMARY KEY,
  sale_date DATE,  -- Date only, not timestamp
  amount DECIMAL
);
```

**CSV Configuration:**
```csv
daily_sales,sale_date,sale_id
```

✅ **Works fine!** The pipeline handles both DATE and TIMESTAMP columns.

### Example 3: No Incremental Column Available

**Problem:** Some tables don't have an updated_at column.

**Solutions:**

**Option 1: Add the column (Recommended)**
```sql
ALTER TABLE my_table 
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE TRIGGER set_updated_at
BEFORE UPDATE ON my_table
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();
```

**Option 2: Use created_at for append-only tables**
```csv
log_table,created_at,log_id
```

**Option 3: Full refresh (modify pipeline)**
- For tables without any timestamp column
- Remove incremental loading for that specific table
- See "Advanced Configuration" section below

---

## 🎯 Real-World Scenario Examples

### Scenario 1: SaaS Application

```csv
table_name,incremental_column,primary_key
tenants,updated_at,tenant_id
users,last_modified,user_uuid
subscriptions,modified_timestamp,subscription_id
usage_metrics,recorded_at,metric_id
billing_events,event_time,event_id
```

### Scenario 2: Retail System

```csv
table_name,incremental_column,primary_key
pos_transactions,transaction_time,txn_id
store_inventory,last_counted,sku
employee_shifts,updated_at,shift_id
customer_loyalty,last_activity,member_id
sales_daily_summary,business_date,summary_id
```

### Scenario 3: Healthcare System

```csv
table_name,incremental_column,primary_key
patients,last_updated,patient_id
appointments,modified_date,appointment_id
medical_records,updated_timestamp,record_id
prescriptions,prescription_date,prescription_id
billing_claims,claim_date,claim_id
```

---

## ⚡ Performance Optimization Tips

### 1. Index Your Incremental Columns

```sql
CREATE INDEX idx_customers_updated 
ON customers(updated_at);
```

✅ **Benefit:** 10-100x faster queries for incremental loading

### 2. Order Tables by Load Priority

In your CSV, order tables so that:
1. **Lookup/reference tables first** (small, static)
2. **Dimension tables** (moderate size, occasional updates)
3. **Fact tables last** (large, frequent updates)

### 3. Group Related Tables

Keep related tables together for easier troubleshooting:
```csv
# Customer Domain
customers,updated_at,customer_id
customer_addresses,updated_at,address_id
customer_contacts,updated_at,contact_id

# Order Domain
orders,order_date,order_id
order_items,updated_at,item_id
order_status_history,status_date,status_id
```

---

## 🔍 Validation Checklist

Before running the pipeline, verify:

- [ ] All table names exist in PostgreSQL
- [ ] All table names match exact case (if PostgreSQL is case-sensitive)
- [ ] All incremental columns exist in their respective tables
- [ ] All incremental columns are timestamp/date type
- [ ] All primary key columns exist
- [ ] All primary key columns are unique and not null
- [ ] No duplicate table names in the list
- [ ] CSV has no empty rows
- [ ] Column names don't have extra spaces

---

## 🛠️ Troubleshooting

### Issue: "Column not found" error

**Cause:** Incremental column or primary key doesn't exist in table

**Solution:**
1. Check column name spelling
2. Verify column exists: `SELECT * FROM table LIMIT 1;`
3. Check case sensitivity

### Issue: "High water mark not advancing"

**Cause:** Incremental column isn't being updated

**Solution:**
1. Verify the column has a trigger or default value
2. Check if updates are happening: 
   ```sql
   SELECT MAX(updated_at) FROM my_table;
   ```
3. Consider adding trigger (see Example 3 above)

### Issue: "Duplicate key violations"

**Cause:** Primary key column is not unique

**Solution:**
1. Verify uniqueness:
   ```sql
   SELECT primary_key, COUNT(*) 
   FROM my_table 
   GROUP BY primary_key 
   HAVING COUNT(*) > 1;
   ```
2. Fix duplicates or choose different primary key

---

## 📈 Monitoring & Maintenance

### Check Pipeline Success

Query the error log table:
```sql
SELECT * 
FROM PIPELINE_ERROR_LOG 
ORDER BY ERROR_TIMESTAMP DESC 
LIMIT 10;
```

### Monitor Data Freshness

```sql
SELECT 
  'customers' as table_name,
  MAX(updated_at) as last_update,
  DATEDIFF('hour', MAX(updated_at), CURRENT_TIMESTAMP()) as hours_old
FROM customers;
```

### Weekly Maintenance Tasks

- [ ] Review error log for failed tables
- [ ] Check data freshness for all tables
- [ ] Verify row counts match expectations
- [ ] Monitor Snowflake warehouse usage
- [ ] Review execution times (add indexes if slow)

---

## 🚀 Advanced Configuration

### Parallel Processing

To load tables in parallel (faster):

1. Open the pipeline
2. Find the **Table Iterator** component
3. Change `concurrency` from `Sequential` to `Concurrent`
4. Set max concurrent executions (e.g., 5-10)

⚠️ **Note:** Ensure your PostgreSQL and Snowflake can handle concurrent connections

### Different Source Schemas

To load from multiple PostgreSQL schemas:

1. **Add a schema column** to the grid variable
2. **Update the iterator** to include schema variable
3. **Update the Load component** to use `${schema_name}`

---

## ✅ Next Steps

1. **Review the CSV template** - Familiarize yourself with the 100 example tables
2. **Identify your tables** - List all PostgreSQL tables you need to load
3. **Map your columns** - Identify incremental and primary key columns
4. **Update the CSV** - Replace template values with your actual configuration
5. **Add to pipeline** - Import the configuration into the `tables_to_load` variable
6. **Configure connection** - Set PostgreSQL connection details
7. **Test with 1-2 tables** - Verify configuration works
8. **Run full load** - Execute for all 100 tables
9. **Schedule** - Set up daily/hourly runs
10. **Monitor** - Check error logs and data freshness

---

## 💡 Pro Tips

1. **Start small:** Test with 5-10 tables before loading all 100
2. **Document differences:** Note any tables with special requirements
3. **Version control:** Keep CSV in version control alongside pipeline
4. **Backup strategy:** Know how to rebuild tables from PostgreSQL
5. **Cost monitoring:** Track Snowflake credits usage during initial loads
6. **Incremental advantage:** After first load, subsequent runs are 97% faster
7. **Business hours:** Run large initial loads during off-peak hours
8. **Stakeholder communication:** Set expectations on data freshness

---

**Last Updated:** 2025-12-25  
**Pipeline Version:** 1.0