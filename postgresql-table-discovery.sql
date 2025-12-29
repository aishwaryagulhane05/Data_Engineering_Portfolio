-- PostgreSQL Table Discovery Script
-- Run this in your PostgreSQL database to identify tables and their key columns
-- This helps you build the table configuration CSV for the dynamic ingestion pipeline

-- ============================================================================
-- 1. LIST ALL TABLES IN A SCHEMA
-- ============================================================================
-- Replace 'public' with your schema name

SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size
FROM pg_tables
WHERE schemaname = 'public'  -- Change schema name here
ORDER BY tablename;


-- ============================================================================
-- 2. IDENTIFY TIMESTAMP/DATE COLUMNS (Potential Incremental Columns)
-- ============================================================================
-- This finds all timestamp and date columns in your schema

SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'  -- Change schema name here
  AND data_type IN (
      'timestamp', 
      'timestamp with time zone', 
      'timestamp without time zone',
      'timestamptz',
      'date'
  )
ORDER BY table_name, column_name;


-- ============================================================================
-- 3. IDENTIFY PRIMARY KEYS
-- ============================================================================
-- This finds all primary key columns in your schema

SELECT 
    tc.table_name,
    kcu.column_name as primary_key_column,
    c.data_type
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.columns c
  ON kcu.table_name = c.table_name
  AND kcu.column_name = c.column_name
  AND kcu.table_schema = c.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema = 'public'  -- Change schema name here
ORDER BY tc.table_name;


-- ============================================================================
-- 4. COMPREHENSIVE TABLE ANALYSIS (CSV-Ready Output)
-- ============================================================================
-- This generates a CSV-like output with table name, suggested incremental column, and primary key
-- Copy the results directly into your CSV template!

WITH timestamp_cols AS (
    -- Find timestamp/date columns (prefer updated_at, last_modified, etc.)
    SELECT 
        table_name,
        column_name,
        CASE 
            WHEN column_name ILIKE '%updated_at%' THEN 1
            WHEN column_name ILIKE '%last_modified%' THEN 2
            WHEN column_name ILIKE '%modified_date%' THEN 3
            WHEN column_name ILIKE '%last_updated%' THEN 4
            WHEN column_name ILIKE '%updated%' THEN 5
            WHEN column_name ILIKE '%modified%' THEN 6
            WHEN column_name ILIKE '%timestamp%' THEN 7
            WHEN column_name ILIKE '%date%' THEN 8
            ELSE 9
        END as priority
    FROM information_schema.columns
    WHERE table_schema = 'public'  -- Change schema name here
      AND data_type IN ('timestamp', 'timestamp with time zone', 'timestamp without time zone', 'timestamptz', 'date')
),
ranked_timestamps AS (
    SELECT 
        table_name,
        column_name as incremental_column,
        ROW_NUMBER() OVER (PARTITION BY table_name ORDER BY priority) as rn
    FROM timestamp_cols
),
primary_keys AS (
    SELECT 
        tc.table_name,
        STRING_AGG(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) as primary_key
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema = 'public'  -- Change schema name here
    GROUP BY tc.table_name
)
SELECT 
    t.tablename as table_name,
    COALESCE(ts.incremental_column, 'NO_TIMESTAMP_COLUMN') as incremental_column,
    COALESCE(pk.primary_key, 'NO_PRIMARY_KEY') as primary_key
FROM pg_tables t
LEFT JOIN ranked_timestamps ts ON t.tablename = ts.table_name AND ts.rn = 1
LEFT JOIN primary_keys pk ON t.tablename = pk.table_name
WHERE t.schemaname = 'public'  -- Change schema name here
ORDER BY t.tablename;

-- Copy the output above and paste into your CSV file!
-- Note: Tables with 'NO_TIMESTAMP_COLUMN' will need manual configuration or full refresh
-- Note: Tables with 'NO_PRIMARY_KEY' may have issues with incremental loading


-- ============================================================================
-- 5. CHECK FOR COMMON INCREMENTAL COLUMN PATTERNS
-- ============================================================================
-- Helps you understand what naming patterns exist in your database

SELECT 
    column_name,
    COUNT(*) as table_count,
    STRING_AGG(table_name, ', ' ORDER BY table_name) as tables
FROM information_schema.columns
WHERE table_schema = 'public'  -- Change schema name here
  AND data_type IN ('timestamp', 'timestamp with time zone', 'timestamp without time zone', 'timestamptz', 'date')
  AND column_name IN (
      'updated_at', 'last_modified', 'modified_date', 'last_updated', 
      'updated_timestamp', 'modified_timestamp', 'created_at', 'created_date'
  )
GROUP BY column_name
ORDER BY table_count DESC;


-- ============================================================================
-- 6. IDENTIFY TABLES WITHOUT INCREMENTAL COLUMNS
-- ============================================================================
-- These tables will need special handling (full refresh or add timestamp column)

SELECT DISTINCT
    t.tablename
FROM pg_tables t
WHERE t.schemaname = 'public'  -- Change schema name here
  AND NOT EXISTS (
      SELECT 1 
      FROM information_schema.columns c
      WHERE c.table_schema = t.schemaname
        AND c.table_name = t.tablename
        AND c.data_type IN ('timestamp', 'timestamp with time zone', 'timestamp without time zone', 'timestamptz', 'date')
  )
ORDER BY t.tablename;


-- ============================================================================
-- 7. VALIDATE EXISTING TIMESTAMP COLUMNS
-- ============================================================================
-- Check if timestamp columns are actually being populated
-- Replace 'your_table' and 'your_column' with actual values

-- Example: Check if updated_at is NULL for any rows
SELECT 
    'customers' as table_name,
    COUNT(*) as total_rows,
    COUNT(updated_at) as non_null_updated_at,
    COUNT(*) - COUNT(updated_at) as null_count,
    MIN(updated_at) as oldest_update,
    MAX(updated_at) as newest_update
FROM customers;

-- Run this for each table to verify timestamp columns are usable


-- ============================================================================
-- 8. ESTIMATE ROW COUNTS (Helps with load planning)
-- ============================================================================

SELECT 
    schemaname,
    tablename,
    n_live_tup as estimated_rows,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_stat_user_tables
WHERE schemaname = 'public'  -- Change schema name here
ORDER BY n_live_tup DESC;


-- ============================================================================
-- 9. CHECK FOR COMPOSITE PRIMARY KEYS
-- ============================================================================
-- Matillion typically works better with single-column primary keys
-- This identifies tables with multi-column primary keys

SELECT 
    tc.table_name,
    COUNT(kcu.column_name) as pk_column_count,
    STRING_AGG(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) as pk_columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema = 'public'  -- Change schema name here
GROUP BY tc.table_name
HAVING COUNT(kcu.column_name) > 1
ORDER BY pk_column_count DESC, tc.table_name;


-- ============================================================================
-- 10. GENERATE ADD TIMESTAMP COLUMN STATEMENTS
-- ============================================================================
-- For tables without a timestamp column, this generates ALTER TABLE statements

SELECT 
    'ALTER TABLE ' || tablename || ' ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;' as add_column_sql
FROM pg_tables t
WHERE schemaname = 'public'  -- Change schema name here
  AND NOT EXISTS (
      SELECT 1 
      FROM information_schema.columns c
      WHERE c.table_schema = t.schemaname
        AND c.table_name = t.tablename
        AND c.data_type IN ('timestamp', 'timestamp with time zone', 'timestamp without time zone', 'timestamptz', 'date')
  )
ORDER BY tablename;

-- Copy and run these statements to add timestamp tracking to tables that need it


-- ============================================================================
-- USAGE NOTES
-- ============================================================================

/*
HOW TO USE THIS SCRIPT:

1. Connect to your PostgreSQL database
2. Replace 'public' with your actual schema name (everywhere it appears)
3. Run Query #4 (COMPREHENSIVE TABLE ANALYSIS) to get CSV-ready output
4. Copy the results into your table-configuration-template.csv
5. Run Query #6 to identify tables that need special handling
6. Run Query #7 to validate timestamp columns are populated
7. Run Query #10 to generate ALTER TABLE statements for missing timestamp columns

TROUBLESHOOTING:

- If a table shows 'NO_TIMESTAMP_COLUMN':
  * Add a timestamp column (Query #10 generates the SQL)
  * Or configure for full refresh loading
  * Or use a date column if available

- If a table shows 'NO_PRIMARY_KEY':
  * Consider adding a primary key
  * Or use a unique column combination
  * Or configure as append-only

- For composite primary keys:
  * Use the first column in the composite key
  * Or create a surrogate key
  * Or modify the pipeline to support multi-column keys

PERFORMANCE TIPS:

- Run these queries during off-peak hours
- The row count query (#8) may be slow on large databases
- Consider running discovery on a subset of schemas first
*/