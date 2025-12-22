# Matillion Variables - Configuration Guide for Bronze to Silver Project

**Purpose**: Comprehensive guide for using variables to make pipelines flexible, configurable, and environment-aware  
**Project**: Bronze to Silver Layer (Medallion Architecture)  
**Date**: 2025-12-22

---

## 📋 Table of Contents

1. [Variable Types & Basics](#variable-types--basics)
2. [Use Cases for This Project](#use-cases-for-this-project)
3. [Implementation Examples](#implementation-examples)
4. [Best Practices](#best-practices)
5. [Variable Reference Guide](#variable-reference-guide)

---

## 1. Variable Types & Basics

### Variable Types in Matillion

| Type | Description | Example Use Case |
|------|-------------|------------------|
| **TEXT** | String values | Database names, schemas, table names |
| **NUMBER** | Numeric values | Row limits, thresholds, days to retain |
| **GRID** | Table of values | Multiple table configurations, column mappings |

### Variable Scopes

| Scope | Behavior | Use When |
|-------|----------|----------|
| **SHARED** | Same value across all branches | Environment config, database names |
| **COPIED** | Independent per branch, resets on merge | Testing, temporary overrides |

### Variable Visibility

| Visibility | Access | Use When |
|------------|--------|----------|
| **PRIVATE** | Current pipeline only | Internal calculations |
| **PUBLIC** | Accessible from other pipelines | Shared configuration |

---

## 2. Use Cases for This Project

### A. Environment Configuration

**Problem**: Hardcoded database/schema names make pipelines environment-specific  
**Solution**: Use variables for all environment-specific values

```yaml
variables:
  bronze_database: MATILLION_DB
  bronze_schema: BRONZE
  silver_database: MATILLION_DB
  silver_schema: SILVER
  warehouse_name: MATILLION_WH
```

**Benefits**:
- ✅ Easy DEV → QA → PROD promotion
- ✅ Test with different schemas without code changes
- ✅ Environment-specific overrides

### B. Incremental Load Configuration

**Problem**: Watermark date hardcoded, can't reset or override  
**Solution**: Parameterize watermark and default date

```yaml
variables:
  watermark_default_date: '1900-01-01'
  force_full_reload: No
  incremental_days_back: 0
```

**Benefits**:
- ✅ Easy full reload by changing one variable
- ✅ Reprocess specific date ranges
- ✅ Testing flexibility

### C. Data Quality Thresholds

**Problem**: Quality rules embedded in SQL, hard to adjust  
**Solution**: Extract thresholds as variables

```yaml
variables:
  max_discount_percent: 75
  min_order_amount: 0.01
  validation_tolerance: 0.01
```

**Benefits**:
- ✅ Business users can adjust without SQL knowledge
- ✅ Easy A/B testing of thresholds
- ✅ Documented business rules

### D. Dynamic Table Processing

**Problem**: Need to process multiple tables with similar logic  
**Solution**: Use GRID variables for table configurations

```yaml
variables:
  tables_to_process: # GRID variable
    columns: [table_name, row_threshold, enable_validation]
    values:
      - [CAMPAIGNS, 1000, Yes]
      - [CUSTOMERS, 10000, Yes]
      - [SALES, 100000, Yes]
```

**Benefits**:
- ✅ Process multiple tables in loop
- ✅ Table-specific configurations
- ✅ Easy to add/remove tables

### E. Monitoring & Alerting

**Problem**: Alert recipients hardcoded or missing  
**Solution**: Variable-driven notifications

```yaml
variables:
  alert_email: data-team@company.com
  error_threshold: 100
  enable_alerts: Yes
```

### F. Performance Tuning

**Problem**: Query limits and batch sizes hardcoded  
**Solution**: Configurable performance parameters

```yaml
variables:
  batch_size: 10000
  query_timeout_seconds: 300
  max_rows_to_process: 1000000
```

---

## 3. Implementation Examples

### Example 1: Master Orchestration with Shared Variables (RECOMMENDED APPROACH)

The **Master - Orchestrate Silver Layer** pipeline demonstrates the simplest and most practical use of variables.

**Variables Defined at Pipeline Level**:
```yaml
variables:
  bronze_database:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: MATILLION_DB
  
  bronze_schema:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: BRONZE
  
  silver_database:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: MATILLION_DB
  
  silver_schema:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: SILVER
  
  warehouse_name:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: MATILLION_WH
```

**How to Use**:
1. **For DEV environment**: Keep defaults as-is
2. **For PROD environment**: Change defaults to PROD values
3. **All 6 transformation pipelines** inherit these variables
4. **No need to override** in each run-transformation component

**Key Benefits**:
- ✅ Single place to configure all database/schema names
- ✅ Easy to switch between environments
- ✅ All child transformations use same configuration
- ✅ Simple to understand and maintain

---

### Example 2: Environment-Specific Variable Sets

**For Different Environments**, simply change the variable defaults:

#### DEV Environment
```yaml
bronze_database: MATILLION_DEV_DB
bronze_schema: BRONZE
silver_database: MATILLION_DEV_DB
silver_schema: SILVER
warehouse_name: DEV_WH
```

#### QA Environment
```yaml
bronze_database: MATILLION_QA_DB
bronze_schema: BRONZE
silver_database: MATILLION_QA_DB
silver_schema: SILVER
warehouse_name: QA_WH
```

#### PROD Environment
```yaml
bronze_database: MATILLION_PROD_DB
bronze_schema: BRONZE
silver_database: MATILLION_PROD_DB
silver_schema: SILVER
warehouse_name: PROD_WH
```

---

### Example 3: Variables in Transformation Pipelines

Let's add variables to the Sales transformation:

**Variables Definition**:
```yaml
variables:
  bronze_database:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: MATILLION_DB
    description: Bronze layer database name
  
  bronze_schema:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: BRONZE
    description: Bronze layer schema name
  
  silver_database:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: MATILLION_DB
    description: Silver layer database name
  
  silver_schema:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: SILVER
    description: Silver layer schema name
  
  watermark_default:
    type: TEXT
    scope: SHARED
    visibility: PUBLIC
    default: '1900-01-01'
    description: Default watermark date for first load
  
  validation_tolerance:
    type: NUMBER
    scope: SHARED
    visibility: PUBLIC
    default: 0.01
    description: Tolerance for line total validation (dollars)
```

**Updated SQL with Variables**:
```sql
SELECT
    UPPER(TRIM("ORDER_ID")) AS order_id,
    UPPER(TRIM("ORDER_LINE_ID")) AS order_line_id,
    -- ... other columns ...
    CASE 
        WHEN ABS(
            COALESCE("LINE_TOTAL", 0) - 
            ((COALESCE("QUANTITY", 0) * COALESCE("UNIT_PRICE", 0)) - COALESCE("DISCOUNT_AMOUNT", 0))
        ) > ${validation_tolerance}  -- Variable reference!
        THEN (COALESCE("QUANTITY", 0) * COALESCE("UNIT_PRICE", 0)) - COALESCE("DISCOUNT_AMOUNT", 0)
        ELSE COALESCE("LINE_TOTAL", 0)
    END AS line_total_validated,
    -- ... rest of query ...
FROM ${bronze_database}.${bronze_schema}.MTLN_BRONZE_SALES  -- Variable references!
WHERE "LOAD_TIMESTAMP" > (
    SELECT COALESCE(MAX("LOAD_TIMESTAMP"), '${watermark_default}'::TIMESTAMP)  -- Variable reference!
    FROM ${silver_database}.${silver_schema}.MTLN_SILVER_SALES  -- Variable references!
)
```

### Example 2: Configurable Quality Rules

**Variables for Performance Pipeline**:
```yaml
variables:
  max_ctr_percent:
    type: NUMBER
    default: 100
    description: Maximum valid CTR percentage
  
  min_impressions_threshold:
    type: NUMBER
    default: 0
    description: Minimum impressions for CTR calculation
  
  enable_click_validation:
    type: TEXT
    default: Yes
    description: Enable clicks <= impressions validation
```

**SQL with Variables**:
```sql
SELECT
    -- ... other columns ...
    CASE 
        WHEN '${enable_click_validation}' = 'Yes' AND COALESCE("CLICKS", 0) > COALESCE("IMPRESSIONS", 0)
        THEN COALESCE("IMPRESSIONS", 0)  -- Cap clicks at impressions
        ELSE COALESCE("CLICKS", 0)
    END AS clicks_validated,
    CASE 
        WHEN COALESCE("IMPRESSIONS", 0) > ${min_impressions_threshold}
        THEN (COALESCE("CLICKS", 0)::FLOAT / "IMPRESSIONS") * 100
        ELSE 0
    END AS ctr
FROM ...
```

### Example 3: GRID Variable for Multiple Tables

**Master Orchestration with GRID Variable**:
```yaml
variables:
  silver_tables:  # GRID variable
    type: GRID
    scope: SHARED
    visibility: PUBLIC
    columns:
      - name: table_name
        type: TEXT
      - name: expected_rows
        type: NUMBER
      - name: enable_validation
        type: TEXT
    default:
      - [CAMPAIGNS, 1000, Yes]
      - [CUSTOMERS, 10000, Yes]
      - [CHANNELS, 20, No]
      - [PERFORMANCE, 50000, Yes]
      - [PRODUCTS, 1000, Yes]
      - [SALES, 100000, Yes]
```

**Using in Table Iterator**:
```yaml
Table Iterator:
  type: table-iterator
  parameters:
    targetTable: "${silver_tables}"
    columnMapping:
      - [table_name, table_name_var]
      - [expected_rows, expected_rows_var]
      - [enable_validation, enable_validation_var]
```

### Example 4: Override Variables in Orchestration

**Orchestration calling Transformation with overrides**:
```yaml
Run Sales Transform:
  type: run-transformation
  parameters:
    transformationPipelineLink:
      pipelineName: Bronze to Silver - Sales
    setScalarVariables:
      - variableName: validation_tolerance
        value: 0.05  # Override: More lenient for this run
      - variableName: watermark_default
        value: '2024-01-01'  # Override: Reload from specific date
```

---

## 4. Best Practices

### ✅ DO

1. **Use SHARED for Environment Config**
   - Database names, schema names, warehouse names
   - These should be consistent across all branches

2. **Use PUBLIC for Reusable Variables**
   - Values that other pipelines might need
   - Configuration that should be centralized

3. **Provide Meaningful Defaults**
   - Variables should work out-of-the-box
   - Defaults for DEV environment

4. **Document Each Variable**
   - Clear description of purpose
   - Valid values or ranges
   - Impact of changing the value

5. **Use Descriptive Names**
   - `bronze_database` not `db1`
   - `validation_tolerance` not `tol`

6. **Group Related Variables**
   - All environment vars together
   - All quality threshold vars together

### ❌ DON'T

1. **Don't Use Variables for Secrets**
   - Use TEXT_SECRET_REF type instead
   - Never put passwords in TEXT variables

2. **Don't Overuse Variables**
   - Only parameterize what actually needs to vary
   - Don't make everything a variable

3. **Don't Use COPIED for Config**
   - Environment config should be SHARED
   - COPIED is for concurrent execution scenarios

4. **Don't Hardcode in Multiple Places**
   - If same value appears twice, use a variable
   - Single source of truth

---

## 5. Variable Reference Guide

### Referencing Variables in Components

#### In SQL Component
```sql
-- Text substitution: ${variable_name}
SELECT * 
FROM ${database_name}.${schema_name}.${table_name}
WHERE amount > ${min_amount}
```

#### In Table Output Component
```yaml
parameters:
  database: "${silver_database}"
  schema: "${silver_schema}"
  targetTable: "${target_table_name}"
```

#### In Calculator Component
```yaml
parameters:
  calculations:
    - - "${column_name}"
      - "output_name"
```

### Variable Syntax

| Context | Syntax | Example |
|---------|--------|----------|
| SQL | `${variable}` | `WHERE date > '${start_date}'` |
| Component params | `"${variable}"` | `database: "${db_name}"` |
| Concatenation | `${var1}_${var2}` | `${env}_${schema}` |
| In strings | `'${variable}'` | `'Value: ${amount}'` |

### GRID Variable Usage

**Defining GRID Variable**:
```yaml
variables:
  table_config:
    type: GRID
    columns:
      - name: source_table
        type: TEXT
      - name: target_table
        type: TEXT
      - name: row_limit
        type: NUMBER
    default:
      - [bronze_campaigns, silver_campaigns, 1000]
      - [bronze_customers, silver_customers, 10000]
```

**Using GRID in Iterator**:
```yaml
Table Iterator:
  type: table-iterator
  parameters:
    targetTable: "${table_config}"
    columnMapping:
      - [source_table, src_var]
      - [target_table, tgt_var]
```

**Accessing GRID Columns**:
```sql
-- Inside iterator loop
SELECT * FROM ${src_var}
WHERE ...
```

---

## 6. Practical Examples for This Project

### Scenario 1: DEV vs PROD Environments

**Problem**: Same pipeline needs different database names in DEV vs PROD

**Solution**:
```yaml
# DEV Environment Override
variables:
  bronze_database: MATILLION_DEV_DB
  silver_database: MATILLION_DEV_DB
  warehouse_name: DEV_WH

# PROD Environment Override
variables:
  bronze_database: MATILLION_PROD_DB
  silver_database: MATILLION_PROD_DB
  warehouse_name: PROD_WH
```

### Scenario 2: Reprocess Historical Data

**Problem**: Need to reload data from specific date

**Solution**:
```yaml
# Normal run (incremental)
variables:
  watermark_default: '1900-01-01'
  force_date_override: ''

# Reprocess from 2024-01-01
variables:
  watermark_default: '2024-01-01'  # Override in orchestration
```

**SQL**:
```sql
WHERE "LOAD_TIMESTAMP" > 
  CASE 
    WHEN '${force_date_override}' != '' 
    THEN '${force_date_override}'::TIMESTAMP
    ELSE (
      SELECT COALESCE(MAX("LOAD_TIMESTAMP"), '${watermark_default}'::TIMESTAMP)
      FROM ${silver_database}.${silver_schema}.MTLN_SILVER_SALES
    )
  END
```

### Scenario 3: Table-Specific Quality Rules

**Problem**: Different tables need different validation rules

**Solution**:
```yaml
variables:
  quality_rules:  # GRID variable
    type: GRID
    columns:
      - name: table_name
        type: TEXT
      - name: null_tolerance_percent
        type: NUMBER
      - name: duplicate_check
        type: TEXT
    default:
      - [CAMPAIGNS, 5, Yes]
      - [CUSTOMERS, 2, Yes]
      - [SALES, 10, No]  # Higher tolerance for sales
```

### Scenario 4: Testing with Subsets

**Problem**: Want to test with limited data before full load

**Solution**:
```yaml
variables:
  test_mode:
    type: TEXT
    default: No
  test_row_limit:
    type: NUMBER
    default: 1000
```

**SQL**:
```sql
SELECT ...
FROM ${bronze_database}.${bronze_schema}.MTLN_BRONZE_SALES
WHERE "LOAD_TIMESTAMP" > (...)
${
  CASE 
    WHEN test_mode = 'Yes' 
    THEN 'LIMIT ' || test_row_limit 
    ELSE '' 
  END
}
```

---

## 7. Common Variable Patterns

### Pattern 1: Environment Config
```yaml
variables:
  environment:
    type: TEXT
    default: DEV
  bronze_database:
    type: TEXT
    default: "${
      CASE environment
        WHEN 'DEV' THEN 'MATILLION_DEV_DB'
        WHEN 'QA' THEN 'MATILLION_QA_DB'
        WHEN 'PROD' THEN 'MATILLION_PROD_DB'
      END
    }"
```

### Pattern 2: Conditional Processing
```yaml
variables:
  enable_validation: Yes
  enable_derived_metrics: Yes
  enable_archiving: No
```

### Pattern 3: Date Range Filters
```yaml
variables:
  start_date:
    type: TEXT
    default: ''
  end_date:
    type: TEXT
    default: ''
  use_date_filter:
    type: TEXT
    default: No
```

---

## 8. Testing with Variables

### Quick Test Configuration
```yaml
variables:
  # Override for testing
  bronze_database: MATILLION_DB
  bronze_schema: BRONZE_TEST  # Test schema
  silver_database: MATILLION_DB
  silver_schema: SILVER_TEST  # Test schema
  validation_tolerance: 1.00  # More lenient
  test_mode: Yes
  test_row_limit: 100  # Small subset
```

### Full Production Configuration
```yaml
variables:
  bronze_database: MATILLION_DB
  bronze_schema: BRONZE
  silver_database: MATILLION_DB
  silver_schema: SILVER
  validation_tolerance: 0.01
  test_mode: No
  test_row_limit: 0
```

---

## Summary

### Key Takeaways

1. **Variables make pipelines flexible** - Easy environment promotion
2. **Use SHARED for config** - Consistent across branches
3. **Use PUBLIC for reusable values** - Accessible from orchestrations
4. **GRID variables for multiple items** - Loop through configurations
5. **Override in orchestrations** - Runtime flexibility
6. **Document thoroughly** - Future maintainers will thank you

### Quick Reference

| Need | Variable Type | Scope | Visibility |
|------|---------------|-------|------------|
| Database name | TEXT | SHARED | PUBLIC |
| Schema name | TEXT | SHARED | PUBLIC |
| Threshold value | NUMBER | SHARED | PUBLIC |
| Enable/disable flag | TEXT | SHARED | PUBLIC |
| Multiple tables | GRID | SHARED | PUBLIC |
| Test override | TEXT | COPIED | PRIVATE |

---

**Next Steps**:
1. Add variables to existing pipelines
2. Create environment-specific variable sets
3. Test with different configurations
4. Document variable usage in README

---

**Document Control**:  
- **Created**: 2025-12-22  
- **Status**: Production Ready  
- **Next Review**: As needed

*This guide provides comprehensive patterns for using variables effectively in the Bronze to Silver layer project.*