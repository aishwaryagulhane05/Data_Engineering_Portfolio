# PostgreSQL to Snowflake - 100+ Tables with 1 Pipeline

**Pipeline**: `PostgreSQL to Snowflake - Dynamic Ingestion.orch.yaml`

## Overview

This dynamic ETL pipeline loads **100+ tables** from PostgreSQL to Snowflake using **ONE reusable pipeline**. 

✅ No need to create 100 separate pipelines  
✅ Just add table names to a variable and run  
✅ Supports sequential or concurrent (parallel) loading  
✅ Automatic error handling and retry logic

## Architecture

```
Start → Fixed Iterator (loops 100 tables) → PostgreSQL Connector (loads to Snowflake)
         ├─ customers
         ├─ orders  
         ├─ products
         ├─ ... (97 more tables)
         └─ user_logs
```

## Quick Start

### 1. Configure PostgreSQL Connection

Open "Load PostgreSQL Table" component and set:

- **Connection URL**: `jdbc:postgresql://your-host:5432/your-database`
- **Username**: Your PostgreSQL username
- **Password**: Secret reference name (not actual password)

### 2. Add Your 100 Tables

Get table list from PostgreSQL:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
```

Add results to the `tables_to_load` grid variable (currently has 20 examples).

### 3. Configure Target

Set these variables:

- `postgres_schema`: Source schema (default: `public`)
- `target_database`: Snowflake database (default: Environment Default)
- `target_schema`: Snowflake schema (default: Environment Default)

### 4. Run the Pipeline

Execute once - loads all 100 tables automatically!

## Performance

### Sequential Mode (Default)

- Loads one table at a time
- Safer for connection limits
- **Time**: 3-25 hours for 100 tables

### Concurrent Mode (Recommended for 100 Tables)

Edit iterator component, change:
```yaml
concurrency: "Concurrent"
```

- Loads 20 tables simultaneously
- **Time**: 15 minutes - 2 hours for 100 tables  
- **15-20x faster** than sequential

### Execution Time Estimates

| Data Volume | Sequential | Concurrent |
|-------------|-----------|------------|
| Small (< 100M rows) | 3-8 hours | 15-30 min |
| Medium (100M-1B rows) | 8-15 hours | 30-60 min |
| Large (> 1B rows) | 15-25 hours | 1-2 hours |

## Load Strategy

**Current**: Full Refresh (REPLACE_IF_EXISTS)
- Replaces Snowflake table on each run
- Loads all columns from PostgreSQL
- Preserves table names

**Alternative**: Incremental Loading
- Load only new/changed records
- 97% faster for subsequent runs
- Requires timestamp column (e.g., `updated_at`)

## Example: 100 E-commerce Tables

```yaml
tables_to_load:
  # Customer Domain
  - customers
  - customer_addresses  
  - customer_preferences
  - customer_segments
  - customer_loyalty_points
  - customer_wishlists
  - customer_reviews
  - customer_support_tickets
  - customer_feedback
  - customer_referrals
  
  # Order Domain
  - orders
  - order_items
  - order_status_history
  - order_shipments
  - order_tracking
  - order_returns
  - order_refunds
  - order_payments
  - order_invoices
  - order_taxes
  
  # Product Domain  
  - products
  - product_variants
  - product_categories
  - product_brands
  - product_suppliers
  - product_inventory
  - product_prices
  - product_reviews
  - product_images
  - product_specifications
  
  # Marketing Domain
  - campaigns
  - promotions
  - promotion_codes
  - email_campaigns
  - email_sends
  - email_opens
  - email_clicks
  - sms_campaigns
  - push_notifications
  - ab_test_results
  
  # Inventory Domain
  - warehouses
  - warehouse_locations
  - inventory_levels
  - inventory_movements
  - stock_transfers
  - purchase_orders
  - purchase_order_items
  - receiving_logs
  - inventory_counts
  - inventory_adjustments
  
  # Finance Domain
  - payments
  - payment_transactions
  - payment_methods
  - refunds
  - chargebacks
  - invoices
  - credit_notes
  - accounting_entries
  - tax_records
  - financial_reports
  
  # Analytics Domain
  - web_sessions
  - web_page_views
  - web_events
  - web_conversions
  - app_sessions
  - app_events
  - app_crashes
  - search_queries
  - search_results
  - user_behavior_logs
  
  # Additional 30 tables...
  - users
  - roles
  - permissions
  - audit_logs
  - error_logs
  - api_calls
  - notifications
  - messages
  - attachments
  - comments
  # ... continue to 100
```

## Validation

### Before Running

```sql
-- Count tables in PostgreSQL
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'public';
```

### After Running

```sql
-- Count tables in Snowflake
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'YOUR_SCHEMA';

-- Compare row counts (example)
SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders;
```

## Pre-Flight Checklist

- [ ] PostgreSQL connection configured
- [ ] 100 table names added to `tables_to_load` variable
- [ ] Target Snowflake database/schema created
- [ ] Test run with 5 tables successful
- [ ] Concurrent mode enabled (optional, for speed)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection timeout | Reduce concurrency or increase timeout |
| Table not found | Verify table exists in PostgreSQL |
| Permission denied | Grant SELECT on all tables in PostgreSQL |
| Out of memory | Use larger Snowflake warehouse |

## Next Steps

1. ✅ **Configure** PostgreSQL connection details
2. ✅ **Add** your 100 table names to variable
3. ✅ **Test** with 5 tables first
4. ✅ **Enable** concurrent mode for faster loading
5. ✅ **Run** full pipeline with all 100 tables
6. ✅ **Schedule** for daily/hourly automated runs

---

**Capacity**: 100+ tables (iterator limit: 5,000 tables)  
**Performance**: 15 min - 2 hours (concurrent mode)  
**Pattern**: Dynamic ETL with Fixed Iterator  
**Updated**: 2025-12-25
